/* eslint-disable max-len */

const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// Simple obvious-profanity layer.
// OpenAI Moderation is the second broader safety layer.
const BAD_WORD_PATTERNS = [
  /\bf+u+c+k+\b/i,
  /\bs+h+i+t+\b/i,
  /\bb+i+t+c+h+\b/i,
  /\ba+s+s+h+o+l+e+\b/i,
  /\bc+u+n+t+\b/i,
  /\bn+i+g+g+[ae]+r?\b/i,
];

exports.moderateReview = onRequest(
    {
      region: "us-central1",
      secrets: [OPENAI_API_KEY],
      timeoutSeconds: 30,
      memory: "256MiB",
      cors: true,
    },
    async (req, res) => {
      try {
        if (req.method !== "POST") {
          res.status(405).json({
            allowed: false,
            message: "Method not allowed.",
            source: "function",
            debugCode: "method_not_allowed",
          });
          return;
        }

        const authorization =
          req.headers.authorization || "";

        if (!authorization.startsWith("Bearer ")) {
          res.status(401).json({
            allowed: false,
            message:
              "Please login before submitting a review.",
            source: "authentication",
            debugCode: "missing_firebase_token",
          });
          return;
        }

        const idToken =
          authorization.substring("Bearer ".length);

        try {
          await admin.auth().verifyIdToken(idToken);
        } catch (error) {
          console.error(
              "Firebase token verification failed:",
              error,
          );

          res.status(401).json({
            allowed: false,
            message:
              "Your session has expired. Please login again.",
            source: "authentication",
            debugCode: "invalid_firebase_token",
          });
          return;
        }

        const text = String(
            req.body && req.body.text ?
              req.body.text :
              "",
        ).trim();

        if (text.length < 5) {
          res.status(400).json({
            allowed: false,
            message:
              "Please write a little more about your experience.",
            source: "validation",
            debugCode: "text_too_short",
          });
          return;
        }

        if (text.length > 800) {
          res.status(400).json({
            allowed: false,
            message:
              "Review must be 800 characters or fewer.",
            source: "validation",
            debugCode: "text_too_long",
          });
          return;
        }

        const containsBadWord =
          BAD_WORD_PATTERNS.some(
              (pattern) => pattern.test(text),
          );

        if (containsBadWord) {
          res.status(200).json({
            allowed: false,
            message:
              "Your review contains inappropriate language. Please revise it before submitting.",
            source: "local-filter",
            debugCode: "local_bad_word",
          });
          return;
        }

        const moderationResponse = await fetch(
            "https://api.openai.com/v1/moderations",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization":
                  `Bearer ${OPENAI_API_KEY.value()}`,
              },
              body: JSON.stringify({
                model: "omni-moderation-latest",
                input: text,
              }),
            },
        );

        const rawBody =
          await moderationResponse.text();

        if (!moderationResponse.ok) {
          let errorType = "";

          try {
            const parsed = JSON.parse(rawBody);
            errorType =
              parsed &&
              parsed.error &&
              parsed.error.type ?
                String(parsed.error.type) :
                "";
          } catch (_) {
            // Keep errorType empty.
          }

          console.error(
              "OpenAI moderation request failed.",
              {
                status: moderationResponse.status,
                errorType,
                body: rawBody,
              },
          );

          const status =
            moderationResponse.status;

          let userMessage =
            "Unable to check review content right now. Please try again.";

          if (status === 401) {
            userMessage =
              "The review checker could not authenticate with the moderation service.";
          } else if (status === 403) {
            userMessage =
              "The review checker does not currently have permission to use moderation.";
          } else if (status === 429) {
            userMessage =
              "The moderation service is temporarily rate-limited. Please try again shortly.";
          }

          res.status(502).json({
            allowed: false,
            message: userMessage,
            source: "openai-moderation",
            debugCode: `openai_${status}`,
          });
          return;
        }

        let moderation;

        try {
          moderation =
            JSON.parse(rawBody);
        } catch (error) {
          console.error(
              "OpenAI moderation returned invalid JSON.",
              rawBody,
          );

          res.status(502).json({
            allowed: false,
            message:
              "The moderation service returned an invalid response. Please try again.",
            source: "openai-moderation",
            debugCode: "openai_invalid_json",
          });
          return;
        }

        const result =
          moderation.results &&
          moderation.results.length > 0 ?
            moderation.results[0] :
            null;

        if (!result) {
          res.status(502).json({
            allowed: false,
            message:
              "The moderation service returned no result. Please try again.",
            source: "openai-moderation",
            debugCode: "openai_no_result",
          });
          return;
        }

        if (result.flagged === true) {
          const flaggedCategories =
            Object.entries(
                result.categories || {},
            )
                .filter(
                    ([, flagged]) =>
                      flagged === true,
                )
                .map(([name]) => name);

          console.log(
              "Review rejected by moderation:",
              flaggedCategories,
          );

          res.status(200).json({
            allowed: false,
            message:
              "Your review may contain harmful or inappropriate content. Please revise it and try again.",
            source: "openai-moderation",
            debugCode: "openai_flagged",
          });
          return;
        }

        res.status(200).json({
          allowed: true,
          message:
            "Review passed content checks.",
          source: "openai-moderation",
          debugCode: "passed",
        });
      } catch (error) {
        console.error(
            "moderateReview unexpected error:",
            error,
        );

        res.status(500).json({
          allowed: false,
          message:
            "Unable to check review content. Please try again.",
          source: "server",
          debugCode: "function_exception",
        });
      }
    },
);
