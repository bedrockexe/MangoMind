const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {GoogleGenAI} = require("@google/genai");

initializeApp();

// The Gemini API key is stored in Cloud Secret Manager, not in source.
// Set it once with:  firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.imageAnalyzer = onCall({secrets: [GEMINI_API_KEY]}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const {prompt, imageBase64} = request.data || {};
  if (!prompt || !imageBase64) {
    throw new HttpsError("invalid-argument", "Missing prompt or imageBase64.");
  }

  try {
    const ai = new GoogleGenAI({apiKey: GEMINI_API_KEY.value()});

    const contents = [
      {inlineData: {mimeType: "image/jpeg", data: imageBase64}},
      {text: prompt},
    ];

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents,
    });

    return {text: response.text};
  } catch (error) {
    logger.error("imageAnalyzer failed", {message: error.message});
    throw new HttpsError("internal", "Image analysis failed.");
  }
});
