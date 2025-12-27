/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");

// Secret v2
const GOOGLE_PLACES_API_KEY = defineSecret("GOOGLE_PLACES_API_KEY");

function getKey() {
  const key = GOOGLE_PLACES_API_KEY.value();
  if (!key) {
    throw new HttpsError(
      "failed-precondition",
      "Missing GOOGLE_PLACES_API_KEY secret in functions."
    );
  }
  return key;
}

function safeGet(obj, path, fallback) {
  // path = ["a","b","c"]
  let cur = obj;
  for (let i = 0; i < path.length; i++) {
    if (!cur || typeof cur !== "object" || !(path[i] in cur)) return fallback;
    cur = cur[path[i]];
  }
  return cur === undefined || cur === null ? fallback : cur;
}

// --------------------
// placesAutocomplete
// --------------------
exports.placesAutocomplete = onCall(
  { region: "us-central1", secrets: [GOOGLE_PLACES_API_KEY] },
  async (req) => {
    const key = getKey();
    const data = req.data || {};
    const input = data.input;
    const sessionToken = data.sessionToken;

    if (!input || typeof input !== "string") {
      throw new HttpsError("invalid-argument", "input is required");
    }

    const url =
      "https://maps.googleapis.com/maps/api/place/autocomplete/json" +
      "?input=" + encodeURIComponent(input) +
      "&key=" + encodeURIComponent(key) +
      (sessionToken ? "&sessiontoken=" + encodeURIComponent(sessionToken) : "") +
      "&language=es";

    const r = await fetch(url);
    const j = await r.json();

    if (j.status !== "OK" && j.status !== "ZERO_RESULTS") {
      logger.error("placesAutocomplete error", j);
      throw new HttpsError("internal", "Places autocomplete failed: " + j.status);
    }

    const preds = Array.isArray(j.predictions) ? j.predictions : [];
    const predictions = preds.map((p) => ({
      placeId: p && p.place_id ? String(p.place_id) : "",
      description: p && p.description ? String(p.description) : "",
    })).filter((p) => p.placeId && p.description);

    return { predictions };
  }
);

// --------------------
// placesDetails
// --------------------
exports.placesDetails = onCall(
  { region: "us-central1", secrets: [GOOGLE_PLACES_API_KEY] },
  async (req) => {
    const key = getKey();
    const data = req.data || {};
    const placeId = data.placeId;
    const sessionToken = data.sessionToken;

    if (!placeId || typeof placeId !== "string") {
      throw new HttpsError("invalid-argument", "placeId is required");
    }

    const url =
      "https://maps.googleapis.com/maps/api/place/details/json" +
      "?place_id=" + encodeURIComponent(placeId) +
      "&fields=formatted_address,geometry,address_component" +
      "&key=" + encodeURIComponent(key) +
      (sessionToken ? "&sessiontoken=" + encodeURIComponent(sessionToken) : "") +
      "&language=es";

    const r = await fetch(url);
    const j = await r.json();

    if (j.status !== "OK") {
      logger.error("placesDetails error", j);
      throw new HttpsError("internal", "Places details failed: " + j.status);
    }

    const result = j.result || {};
    const formattedAddress = result.formatted_address ? String(result.formatted_address) : null;

    const loc = safeGet(result, ["geometry", "location"], {});
    const lat = typeof loc.lat === "number" ? loc.lat : null;
    const lng = typeof loc.lng === "number" ? loc.lng : null;

    const comps = Array.isArray(result.address_components) ? result.address_components : [];
    let city = null;
    for (let i = 0; i < comps.length; i++) {
      const c = comps[i];
      const types = c && Array.isArray(c.types) ? c.types : [];
      if (types.indexOf("locality") !== -1) {
        city = c.long_name ? String(c.long_name) : null;
        break;
      }
    }

    return {
      formattedAddress,
      lat,
      lng,
      city,
    };
  }
);

// --------------------
// geocodeAddress
// --------------------
exports.geocodeAddress = onCall(
  { region: "us-central1", secrets: [GOOGLE_PLACES_API_KEY] },
  async (req) => {
    const key = getKey();
    const data = req.data || {};
    const address = data.address;

    if (!address || typeof address !== "string") {
      throw new HttpsError("invalid-argument", "address is required");
    }

    const url =
      "https://maps.googleapis.com/maps/api/geocode/json" +
      "?address=" + encodeURIComponent(address) +
      "&key=" + encodeURIComponent(key) +
      "&language=es";

    const r = await fetch(url);
    const j = await r.json();

    if (j.status !== "OK") {
      logger.error("geocodeAddress error", j);
      throw new HttpsError("internal", "Geocoding failed: " + j.status);
    }

    const results = Array.isArray(j.results) ? j.results : [];
    const first = results.length ? results[0] : null;

    const formattedAddress = first && first.formatted_address ? String(first.formatted_address) : null;
    const loc = safeGet(first, ["geometry", "location"], {});
    const lat = loc.lat;
    const lng = loc.lng;

    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new HttpsError("internal", "Geocoding returned no coordinates");
    }

    return {
      formattedAddress,
      lat,
      lng,
    };
  }
);
