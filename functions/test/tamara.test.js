const test = require("node:test");
const assert = require("node:assert");
const crypto = require("crypto");
const {
  buildTamaraCheckoutPayload,
  verifyTamaraWebhookToken,
  paymentStatusForTamaraEvent,
  getTamaraConfig,
} = require("../tamara");

function b64url(value) {
  return Buffer.from(value).toString("base64url");
}

function signToken(claims, secret) {
  const header = b64url(JSON.stringify({alg: "HS256", typ: "JWT"}));
  const payload = b64url(JSON.stringify(claims));
  const sig = crypto.createHmac("sha256", secret)
      .update(`${header}.${payload}`).digest("base64url");
  return `${header}.${payload}.${sig}`;
}

test("checkout payload uses server prices and converts halalas to SAR", () => {
  const payload = buildTamaraCheckoutPayload({
    orderId: "o1",
    checkoutItems: [
      {productFirestoreId: "p1", title: "Shoes", quantity: 2,
        unitAmountHalalas: 15050, lineAmountHalalas: 30100},
      {productFirestoreId: "p2", title: "Hat", quantity: 1,
        unitAmountHalalas: 2000, lineAmountHalalas: 2000},
    ],
    buyer: {name: "Tojan Alnajjar", email: "a@b.com", phone: "+966500000000"},
    deliveryAddress: "Riyadh",
    merchantUrls: {success: "s", failure: "f", cancel: "c", notification: "n"},
  });

  assert.strictEqual(payload.order_reference_id, "o1");
  assert.deepStrictEqual(payload.total_amount, {amount: "321.00", currency: "SAR"});
  assert.strictEqual(payload.items[0].unit_price.amount, "150.50");
  assert.strictEqual(payload.payment_type, "PAY_BY_INSTALMENTS");
  assert.strictEqual(payload.consumer.first_name, "Tojan");
  assert.strictEqual(payload.consumer.last_name, "Alnajjar");
});

test("webhook token: valid signature is accepted", () => {
  const token = signToken({exp: Math.floor(Date.now() / 1000) + 60}, "secret");
  assert.ok(verifyTamaraWebhookToken(token, "secret"));
});

test("webhook token: wrong secret, tampering and expiry are rejected", () => {
  const good = signToken({exp: Math.floor(Date.now() / 1000) + 60}, "secret");
  assert.throws(() => verifyTamaraWebhookToken(good, "other"), /signature/);
  assert.throws(() => verifyTamaraWebhookToken("a.b", "secret"), /Malformed/);
  const expired = signToken({exp: 1}, "secret");
  assert.throws(() => verifyTamaraWebhookToken(expired, "secret"), /expired/);
  assert.throws(() => verifyTamaraWebhookToken(good, ""), /not configured/);
});

test("event types map to payment statuses", () => {
  assert.strictEqual(paymentStatusForTamaraEvent("order_approved"), "approved");
  assert.strictEqual(paymentStatusForTamaraEvent("order_authorised"), "paid");
  assert.strictEqual(paymentStatusForTamaraEvent("order_declined"), "failed");
  assert.strictEqual(paymentStatusForTamaraEvent("order_expired"), "canceled");
  assert.strictEqual(paymentStatusForTamaraEvent("something_else"), null);
});

test("config defaults to the sandbox", () => {
  assert.strictEqual(getTamaraConfig({}).apiUrl, "https://api-sandbox.tamara.co");
});
