const crypto = require("crypto");

// Tamara sandbox is the default so nothing hits production by accident.
const TAMARA_SANDBOX_URL = "https://api-sandbox.tamara.co";
const TAMARA_CURRENCY = "SAR";
const TAMARA_COUNTRY = "SA";

function getTamaraConfig(env = process.env) {
  return {
    apiUrl: (env.TAMARA_API_URL || TAMARA_SANDBOX_URL).replace(/\/+$/, ""),
    apiToken: env.TAMARA_API_TOKEN || "",
    notificationToken: env.TAMARA_NOTIFICATION_TOKEN || "",
  };
}

function ensureTamaraConfigured(config) {
  if (!config.apiToken) {
    throw new Error(
        "Tamara API token is not configured. Set TAMARA_API_TOKEN in your functions environment.",
    );
  }
}

function money(halalas) {
  return {amount: (halalas / 100).toFixed(2), currency: TAMARA_CURRENCY};
}

function splitName(fullName) {
  const parts = String(fullName || "").trim().split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] || "Customer",
    lastName: parts.slice(1).join(" ") || "-",
  };
}

// Builds the body of POST /checkout from the server-verified cart items.
// Prices always come from Firestore (buildCheckoutItems), never from the app.
function buildTamaraCheckoutPayload({
  orderId,
  checkoutItems,
  buyer,
  deliveryAddress,
  merchantUrls,
}) {
  const totalHalalas = checkoutItems.reduce(
      (sum, item) => sum + item.lineAmountHalalas,
      0,
  );
  const {firstName, lastName} = splitName(buyer.name);
  const phone = String(buyer.phone || "").trim();

  return {
    order_reference_id: orderId,
    total_amount: money(totalHalalas),
    description: `SouqPlus order ${orderId}`,
    country_code: TAMARA_COUNTRY,
    payment_type: "PAY_BY_INSTALMENTS",
    locale: "en_US",
    items: checkoutItems.map((item) => ({
      reference_id: item.productFirestoreId,
      type: "Physical",
      name: item.title || item.productFirestoreId,
      sku: item.productFirestoreId,
      quantity: item.quantity,
      unit_price: money(item.unitAmountHalalas),
      total_amount: money(item.lineAmountHalalas),
      tax_amount: money(0),
      discount_amount: money(0),
    })),
    consumer: {
      first_name: firstName,
      last_name: lastName,
      phone_number: phone,
      email: String(buyer.email || "").trim(),
    },
    shipping_address: {
      first_name: firstName,
      last_name: lastName,
      line1: String(deliveryAddress || "").trim() || "N/A",
      city: "Riyadh",
      country_code: TAMARA_COUNTRY,
      phone_number: phone,
    },
    tax_amount: money(0),
    shipping_amount: money(0),
    discount: {name: "none", amount: money(0)},
    merchant_url: merchantUrls,
  };
}

async function tamaraRequest(config, method, path, body) {
  ensureTamaraConfigured(config);

  const response = await fetch(`${config.apiUrl}${path}`, {
    method,
    headers: {
      "Authorization": `Bearer ${config.apiToken}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let parsed = {};
  try {
    parsed = text ? JSON.parse(text) : {};
  } catch (_) {
    parsed = {raw: text};
  }

  if (!response.ok) {
    const detail = parsed.message ||
      (Array.isArray(parsed.errors) && parsed.errors.length ?
        JSON.stringify(parsed.errors) :
        text);
    const error = new Error(`Tamara ${method} ${path} failed (${response.status}): ${detail}`);
    error.code = `tamara_${response.status}`;
    throw error;
  }

  return parsed;
}

function createTamaraCheckoutSession(config, payload) {
  return tamaraRequest(config, "POST", "/checkout", payload);
}

function authoriseTamaraOrder(config, tamaraOrderId) {
  return tamaraRequest(
      config,
      "POST",
      `/orders/${encodeURIComponent(tamaraOrderId)}/authorise`,
  );
}

function base64UrlDecode(value) {
  return Buffer.from(value.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

// Tamara signs webhook calls with an HS256 JWT made from the merchant's
// notification token. Returns the claims when valid, otherwise throws.
function verifyTamaraWebhookToken(token, notificationToken) {
  if (!notificationToken) {
    throw new Error("Tamara notification token is not configured.");
  }

  const parts = String(token || "").split(".");
  if (parts.length !== 3) {
    throw new Error("Malformed Tamara webhook token.");
  }

  const [header, payload, signature] = parts;
  const expected = crypto
      .createHmac("sha256", notificationToken)
      .update(`${header}.${payload}`)
      .digest();
  const received = base64UrlDecode(signature);

  if (
    expected.length !== received.length ||
    !crypto.timingSafeEqual(expected, received)
  ) {
    throw new Error("Invalid Tamara webhook signature.");
  }

  const claims = JSON.parse(base64UrlDecode(payload).toString("utf8"));
  if (typeof claims.exp === "number" && claims.exp * 1000 < Date.now()) {
    throw new Error("Tamara webhook token expired.");
  }

  return claims;
}

function extractWebhookToken(req) {
  const header = String(req.headers.authorization || "");
  if (header.startsWith("Bearer ")) {
    return header.substring("Bearer ".length).trim();
  }
  return String((req.query && req.query.tamaraToken) || "").trim();
}

// Maps a Tamara webhook event to the paymentStatus stored on the order.
function paymentStatusForTamaraEvent(eventType) {
  switch (String(eventType || "").toLowerCase()) {
    case "order_approved":
      return "approved";
    case "order_authorised":
      return "paid";
    case "order_declined":
      return "failed";
    case "order_canceled":
    case "order_expired":
      return "canceled";
    default:
      return null;
  }
}

module.exports = {
  getTamaraConfig,
  ensureTamaraConfigured,
  buildTamaraCheckoutPayload,
  createTamaraCheckoutSession,
  authoriseTamaraOrder,
  verifyTamaraWebhookToken,
  extractWebhookToken,
  paymentStatusForTamaraEvent,
};
