// functions/index.js
const {initializeApp} = require("firebase-admin/app");
const { GoogleGenAI } = require("@google/genai"); 
const {onCall, HttpsError} = require("firebase-functions/v1/https");
initializeApp();

const GEMINI_API_KEY = "***REMOVED_GEMINI_KEY***";

const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });

const STRICT_PROMPT = `SYSTEM: You are an expert plant pathologist and fruit quality specialist. ALWAYS RETURN ONLY A SINGLE VALID JSON OBJECT matching the schema exactly (no extra keys, no commentary, no markdown, no code fences, no emojis, nothing else). If any value cannot be determined confidently, follow the "UNSURE" rules in the schema. DO NOT produce any natural language outside the JSON.

ROLE: Mango detector + disease & ripeness reporter.

TASK: Analyze the attached photo. Determine:
  1) object_type: one of ["Leaf","Fruit","Other"]
  2) is_mango: true/false
  3) If is_mango and object_type == "Leaf": diagnose disease (one of ["Healthy","Anthracnose","PowderyMildew","BacterialSpot","OtherPestDamage"]) or "UNSURE".
  4) If is_mango and object_type == "Fruit": diagnose fruit disease (same label set) or "UNSURE", and predict ripeness as a percentage and a ripeness_stage.
  5) If not a mango (is_mango == false): provide up to 3 short photo_tips for retaking a mango-identifiable photo.

OUTPUT: Return exactly this JSON object and nothing else. All keys must exist exactly as shown. Use the specified value formats.

JSON SCHEMA:
{
  "object_type": "<string>",            // "Leaf" | "Fruit" | "Other"
  "is_mango": <boolean>,
  "disease_label": "<string>",          // one of allowed disease labels or "UNSURE"
  "disease_confidence": <float>,        // 0.00 - 1.00 (two decimals)
  "fruit_ripeness_pct": <float>,        // 0.00 - 100.00 (two decimals). If not applicable set 0.00
  "ripeness_stage": "<string>",         // "Unripe" | "SlightlyRipe" | "Ripe" | "Overripe" | "UNSURE"
  "recommendations": ["<string>",...],  // array of 0-3 short remediation tips (each <= 20 words)
  "photo_tips": ["<string>",...],       // array of 0-3 short tips for taking photo (each <= 12 words)
  "bounding_boxes": [                   // may be empty array; boxes in image pixels ints
     {"x":<int>,"y":<int>,"w":<int>,"h":<int>,"region_confidence":<float>}
  ],
  "explainers": ["<string>",...],       // 0-2 short factual reasons (<=12 words each)
  "overall_confidence": <float>,        // 0.00 - 1.00 (two decimals)
}

CONFIDENCE_THRESHOLD: 0.85

END: Process the attached image and return the JSON object only.
`;

// safe fallback UN SURE object
function unsureFallback() {
  return {
    "object_type": "Other",
    "is_mango": false,
    "disease_label": "UNSURE",
    "disease_confidence": 0.00,
    "fruit_ripeness_pct": 0.00,
    "ripeness_stage": "UNSURE",
    "recommendations": [],
    "photo_tips": ["Center mango in frame", "Ensure bright daylight", "Include leaf and fruit together"],
    "bounding_boxes": [],
    "explainers": [],
    "overall_confidence": 0.00,
  };
}

// Utility: parse data URL or raw base64 to get pure base64 string and mime
function parseBase64Data(dataString) {
  if (!dataString) return null;
  const match = dataString.match(/^data:(image\/\w+);base64,(.*)$/);
  if (match) {
    return { mime: match[1], base64: match[2] };
  }
  const onlyBase64 = dataString.replace(/\s+/g, '');
  return { mime: "image/jpeg", base64: onlyBase64 };
}

exports.analyzeMango = onCall(async (request) => {
    console.log(`Request: ${request}`);
    console.log(`Request Data: ${request.data}`);
//   try {
//     const imageBase64String = data?.imageBase64;
//     if (!imageBase64String) {
//       throw new functions.https.HttpsError('invalid-argument', 'imageBase64 is required');
//     }

//     const parsed = parseBase64Data(imageBase64String);
//     if (!parsed) {
//       return unsureFallback();
//     }

//     const contents = [
//       { type: "text", text: STRICT_PROMPT },
//       { type: "image", image: { mime_type: parsed.mime, b64: parsed.base64 } }
//     ];

//     const resp = await ai.models.generateContent({
//       model: "gemini-2.5-flash",
//       contents: contents,
//     });

//     let rawText = "";
//     if (resp?.outputText) rawText = resp.outputText;
//     else if (resp?.text) rawText = resp.text;
//     else if (typeof resp === "string") rawText = resp;
//     else {
//       // try to find a textual field in resp
//       try {
//         // some SDK returns resp.output[0].content[0].text
//         const out = resp?.output || resp?.results;
//         if (Array.isArray(out) && out.length > 0) {
//           // flatten to find first text chunk
//           for (const item of out) {
//             if (item?.content) {
//               for (const c of item.content) {
//                 if (c?.text) { rawText = c.text; break; }
//                 if (c?.type === "text" && c?.text) { rawText = c.text; break; }
//               }
//             }
//             if (rawText) break;
//           }
//         }
//       } catch (ex) {
//         // ignored
//       }
//     }

//     if (!rawText || rawText.trim().length === 0) {
//       return unsureFallback();
//     }

//     // Try parse JSON — models may return JSON-only string per our prompt.
//     let decoded;
//     try {
//       decoded = JSON.parse(rawText);
//     } catch (err) {
//       // try to extract substring between first { and last }
//       const start = rawText.indexOf("{");
//       const end = rawText.lastIndexOf("}");
//       if (start !== -1 && end !== -1 && end > start) {
//         try {
//           decoded = JSON.parse(rawText.substring(start, end + 1));
//         } catch (err2) {
//           return unsureFallback();
//         }
//       } else {
//         return unsureFallback();
//       }
//     }

//     if (!decoded || typeof decoded !== "object") return unsureFallback();

//     // Validate keys (same validation rules as client-side)
//     const requiredKeys = [
//       "object_type",
//       "is_mango",
//       "disease_label",
//       "disease_confidence",
//       "fruit_ripeness_pct",
//       "ripeness_stage",
//       "recommendations",
//       "photo_tips",
//       "bounding_boxes",
//       "explainers",
//       "overall_confidence",
//       "timestamp_utc"
//     ];
//     for (const k of requiredKeys) {
//       if (!(k in decoded)) return unsureFallback();
//     }

//     // Sanitize & coerce values, clamp floats and rounding
//     const objectType = decoded.object_type;
//     if (!["Leaf","Fruit","Other"].includes(objectType)) return unsureFallback();

//     const isMango = !!decoded.is_mango;

//     const allowedDiseases = ["Healthy","Anthracnose","PowderyMildew","BacterialSpot","OtherPestDamage","UNSURE"];
//     const diseaseLabel = decoded.disease_label;
//     if (!allowedDiseases.includes(diseaseLabel)) return unsureFallback();

//     function toNumberInRange(v, min, max) {
//       const n = Number(v);
//       if (Number.isNaN(n) || n < min || n > max) throw new Error("out-of-range");
//       return Math.round(n * 100) / 100;
//     }

//     let diseaseConfidence, fruitRipeness, overallConfidence;
//     try {
//       diseaseConfidence = toNumberInRange(decoded.disease_confidence, 0.0, 1.0);
//       fruitRipeness = toNumberInRange(decoded.fruit_ripeness_pct, 0.0, 100.0);
//       overallConfidence = toNumberInRange(decoded.overall_confidence, 0.0, 1.0);
//     } catch (err) {
//       return unsureFallback();
//     }

//     const allowedRipeness = ["Unripe","SlightlyRipe","Ripe","Overripe","UNSURE"];
//     const ripenessStage = decoded.ripeness_stage;
//     if (!allowedRipeness.includes(ripenessStage)) return unsureFallback();

//     const recommendations = Array.isArray(decoded.recommendations) ? decoded.recommendations.map(String).slice(0,3) : [];
//     const photoTips = Array.isArray(decoded.photo_tips) ? decoded.photo_tips.map(String).slice(0,3) : [];
//     const explainers = Array.isArray(decoded.explainers) ? decoded.explainers.map(String).slice(0,2) : [];

//     // bounding boxes normalization
//     const boxes = Array.isArray(decoded.bounding_boxes) ? decoded.bounding_boxes.map(b => {
//       try {
//         const x = parseInt(b.x);
//         const y = parseInt(b.y);
//         const w = parseInt(b.w);
//         const h = parseInt(b.h);
//         const rc = Math.round((Number(b.region_confidence) || 0) * 100) / 100;
//         if ([x,y,w,h].some(n => Number.isNaN(n))) throw new Error("bad box");
//         return { x, y, w, h, region_confidence: rc };
//       } catch (e) {
//         return null;
//       }
//     }).filter(Boolean) : [];

//     // enforce CONFIDENCE_THRESHOLD rule: we use 0.85
//     const CONF_THRESH = 0.85;
//     const finalDiseaseLabel = diseaseConfidence < CONF_THRESH ? "UNSURE" : diseaseLabel;
//     const finalDiseaseConfidence = diseaseConfidence < CONF_THRESH ? 0.00 : diseaseConfidence;
//     const finalRecommendations = finalDiseaseLabel === "UNSURE" ? [] : recommendations;
//     const finalFruitRipeness = (isMango && objectType === "Fruit" && diseaseConfidence >= CONF_THRESH) ? fruitRipeness : 0.00;
//     const finalRipenessStage = (isMango && objectType === "Fruit" && diseaseConfidence >= CONF_THRESH) ? ripenessStage : "UNSURE";

//     // Assemble final object (always includes the same fields)
//     const out = {
//       object_type: objectType,
//       is_mango: isMango,
//       disease_label: finalDiseaseLabel,
//       disease_confidence: Math.round(finalDiseaseConfidence * 100) / 100,
//       fruit_ripeness_pct: Math.round(finalFruitRipeness * 100) / 100,
//       ripeness_stage: finalRipenessStage,
//       recommendations: finalRecommendations,
//       photo_tips: photoTips,
//       bounding_boxes: boxes,
//       explainers: explainers,
//       overall_confidence: Math.round(overallConfidence * 100) / 100,
//       timestamp_utc: decoded.timestamp_utc || DateTime.utc().toISO({ suppressMilliseconds: true })
//     };

//     return out;
//   } catch (err) {
//     console.error("analyzeMango error:", err);
//     return unsureFallback();
//   }
});
