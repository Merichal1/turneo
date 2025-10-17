const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const OWNER_EMAIL = "antonio@gmail.com";

exports.grantSelfAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Login requerido",
    );
  }

  const email = context.auth.token.email;
  if (email !== OWNER_EMAIL) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Solo el propietario puede auto-asignarse admin.",
    );
  }

  const uid = context.auth.uid;
  await admin.auth().setCustomUserClaims(uid, {role: "admin"});
  return {ok: true};
});
