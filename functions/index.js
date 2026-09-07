const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {LanguageServiceClient} = require("@google-cloud/language");

const languageClient = new LanguageServiceClient();

// Only safety categories are blocked. Legitimate travel topics such as
// religion, health, politics, finance and legal information remain allowed.
const thresholds = {
  "Toxic": 0.60,
  "Derogatory": 0.60,
  "Insult": 0.65,
  "Profanity": 0.60,
  "Sexual": 0.70,
  "Violent": 0.75,
  "Death, Harm & Tragedy": 0.85,
  "Firearms & Weapons": 0.90,
  "Illicit Drugs": 0.85,
};

exports.moderateText = onCall(
    {region: "us-central1", timeoutSeconds: 30, enforceAppCheck: false},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Please sign in before posting.");
      }

      const text = request.data?.text;
      if (typeof text !== "string" || text.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Text must not be empty.");
      }
      if (text.length > 5000) {
        throw new HttpsError("invalid-argument", "Text is too long.");
      }

      try {
        const [response] = await languageClient.moderateText({
          document: {type: "PLAIN_TEXT", content: text},
        });
        const categories = response.moderationCategories ?? [];
        const blocked = categories
            .filter((category) =>
              thresholds[category.name] !== undefined &&
              Number(category.confidence ?? 0) >= thresholds[category.name])
            .sort((a, b) => Number(b.confidence) - Number(a.confidence));

        return {
          isFlagged: blocked.length > 0,
          reason: blocked[0]?.name ?? null,
        };
      } catch (error) {
        console.error("Google moderation failed", error);
        throw new HttpsError(
            "unavailable",
            "Text moderation is temporarily unavailable. Please try again.",
        );
      }
    },
);
