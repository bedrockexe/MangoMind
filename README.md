# Sweet Insights / MangoFarming

A mango-farming management platform with two Flutter apps backed by a shared
Firebase project (`sweet-insights-1e5f1`).

## Repository layout

```
.
├── client/   # Farmer-facing app (farms, records, assessments, AI disease detection)
│   ├── lib/
│   └── functions/        # Cloud Functions (imageAnalyzer)
└── admin/    # Admin app (user/farm management, trainings)
    ├── lib/
    ├── functions/        # Cloud Functions (user/farm management)
    ├── firestore.rules   # Firestore security rules (single source of truth)
    └── storage.rules     # Cloud Storage security rules
```

Both apps target the same Firebase project. Security rules live in `admin/`.

## Getting started

Each app is a standalone Flutter project. From either `client/` or `admin/`:

```bash
flutter pub get
flutter run
```

Cloud Functions (inside each app's `functions/` folder):

```bash
npm install
firebase deploy --only functions
```

## Configuration & secrets

- The Gemini API key is stored in Secret Manager, not in source:
  `firebase functions:secrets:set GEMINI_API_KEY`
- Never commit `serviceAccountKey.json` or the admin operational scripts
  (`change-admin.js`, etc.) — they are git-ignored.

## Deploying security rules

From `admin/`:

```bash
firebase deploy --only firestore:rules,storage
```
