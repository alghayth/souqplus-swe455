const admin = require("firebase-admin");
const crypto = require("crypto");
const {getFirestore} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const app = admin.initializeApp();
const sellerOnboardingDb = getFirestore(app, "souqplus");
const projectId = process.env.GCLOUD_PROJECT || "souqplus-1bb34";
const stripeSecretKey =
  process.env.STRIPE_SECRET_KEY ||
  process.env.STRIPE_TEST_SECRET_KEY ||
  "";
const stripeConnectClientId =
  process.env.STRIPE_CONNECT_CLIENT_ID ||
  process.env.STRIPE_STANDARD_CONNECT_CLIENT_ID ||
  "";
const stripeOauthStateCollection = "stripe_oauth_states";
const stripe = stripeSecretKey ? require("stripe")(stripeSecretKey) : null;

function setCorsHeaders(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

async function authenticateRequest(req) {
  const authHeader = req.headers.authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    throw new Error("Missing Authorization header.");
  }

  const idToken = authHeader.substring("Bearer ".length).trim();

  if (!idToken) {
    throw new Error("Missing Firebase ID token.");
  }

  return admin.auth().verifyIdToken(idToken);
}

function getSellerStripeAccountLinkUrl() {
  return `https://us-central1-${projectId}.cloudfunctions.net/createSellerStripeAccountLink`;
}

function getSellerStripeOAuthStartUrl() {
  return `https://us-central1-${projectId}.cloudfunctions.net/createSellerStripeOAuthAuthorizeUrl`;
}

function getSellerStripeOAuthCallbackUrl() {
  return `https://us-central1-${projectId}.cloudfunctions.net/handleSellerStripeOAuthCallback`;
}

function getSellerStripeRefreshUrl(uid, stripeAccountId) {
  const url = new URL(getSellerStripeAccountLinkUrl());
  url.searchParams.set("mode", "refresh");
  url.searchParams.set("uid", uid);
  url.searchParams.set("account", stripeAccountId);
  return url.toString();
}

function getSellerStripeReturnUrl() {
  const url = new URL(getSellerStripeAccountLinkUrl());
  url.searchParams.set("mode", "return");
  return url.toString();
}

function getSellerStripeAppReturnUrl(status) {
  const url = new URL("souqplus://stripe-connect");
  url.searchParams.set("status", status);
  return url.toString();
}

async function createStripeAccountLink({stripeAccountId, uid}) {
  return stripe.accountLinks.create({
    account: stripeAccountId,
    refresh_url: getSellerStripeRefreshUrl(uid, stripeAccountId),
    return_url: getSellerStripeReturnUrl(),
    type: "account_onboarding",
  });
}

async function getStripeAccountStatus(stripeAccountId) {
  const account = await stripe.accounts.retrieve(stripeAccountId);
  const payoutsEnabled = Boolean(account.payouts_enabled);
  const chargesEnabled = Boolean(account.charges_enabled);
  const detailsSubmitted = Boolean(account.details_submitted);
  const isConnected = Boolean(account.id);
  const readyForPayouts =
    payoutsEnabled && chargesEnabled && detailsSubmitted;

  return {
    account,
    payoutsEnabled,
    chargesEnabled,
    detailsSubmitted,
    isConnected,
    readyForPayouts,
  };
}

function readPriceSar(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const normalized = value.replace(/,/g, "").trim();
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  return 0;
}

function toHalalas(amountSar) {
  return Math.round(readPriceSar(amountSar) * 100);
}

function normalizeRequestedItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("At least one cart item is required.");
  }

  return items.map((item) => {
    const productFirestoreId = String(item.productFirestoreId || "").trim();
    const quantity = Number(item.quantity || 0);

    if (!productFirestoreId) {
      throw new Error("Each cart item must include productFirestoreId.");
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("Each cart item must include a valid quantity.");
    }

    return {productFirestoreId, quantity};
  });
}

async function buildCheckoutItems(items) {
  const normalizedItems = normalizeRequestedItems(items);
  const productSnapshots = await Promise.all(
      normalizedItems.map((item) =>
        sellerOnboardingDb.collection("products").doc(item.productFirestoreId).get(),
      ),
  );

  return normalizedItems.map((item, index) => {
    const snapshot = productSnapshots[index];

    if (!snapshot.exists) {
      throw new Error(`Product not found: ${item.productFirestoreId}`);
    }

    const data = snapshot.data() || {};
    const status = String(data.status || "Active").trim().toLowerCase();
    const sellerStripeAccountId = String(data.sellerStripeAccountId || "").trim();
    const ownerUid = String(data.ownerUid || "").trim();
    const unitAmountHalalas = toHalalas(data.price);

    if (status === "sold") {
      throw new Error(`Product is already sold: ${item.productFirestoreId}`);
    }

    if (!sellerStripeAccountId) {
      throw new Error(
          `Seller Stripe account is missing for product: ${item.productFirestoreId}`,
      );
    }

    if (!ownerUid) {
      throw new Error(`Seller uid is missing for product: ${item.productFirestoreId}`);
    }

    return {
      productFirestoreId: item.productFirestoreId,
      title: String(data.title || "").trim(),
      quantity: item.quantity,
      ownerUid,
      sellerStripeAccountId,
      unitAmountHalalas,
      lineAmountHalalas: unitAmountHalalas * item.quantity,
    };
  });
}

async function markProductsSold(checkoutItems) {
  if (!checkoutItems.length) {
    return;
  }

  const batch = sellerOnboardingDb.batch();
  for (const item of checkoutItems) {
    const productRef = sellerOnboardingDb
        .collection("products")
        .doc(item.productFirestoreId);
    batch.set(productRef, {
      status: "Sold",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  await batch.commit();
}

function sendStatusPage(res, title, message) {
  res.status(200).send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        background: #f7f7f7;
        color: #1f2937;
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        margin: 0;
        padding: 24px;
      }
      .card {
        background: #ffffff;
        border-radius: 16px;
        box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
        max-width: 520px;
        padding: 32px;
      }
      h1 {
        margin-top: 0;
        margin-bottom: 12px;
      }
      p {
        margin: 0;
        line-height: 1.6;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>${title}</h1>
      <p>${message}</p>
    </div>
  </body>
</html>`);
}

function sendReturnPage(res) {
  res.status(200).send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Stripe onboarding complete</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        background: #f7f7f7;
        color: #1f2937;
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        margin: 0;
        padding: 24px;
      }
      .card {
        background: #ffffff;
        border-radius: 16px;
        box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
        max-width: 520px;
        padding: 32px;
      }
      h1 {
        margin-top: 0;
        margin-bottom: 12px;
      }
      p {
        margin: 0 0 14px 0;
        line-height: 1.6;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Stripe setup complete</h1>
      <p>Your seller account setup was submitted successfully.</p>
      <p>You can return to the app and continue posting your product.</p>
    </div>
  </body>
</html>`);
}

function sendAppRedirectPage(res, {title, message, deepLinkUrl}) {
  res.status(200).send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        background: #f7f7f7;
        color: #1f2937;
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        margin: 0;
        padding: 24px;
      }
      .card {
        background: #ffffff;
        border-radius: 16px;
        box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
        max-width: 520px;
        padding: 32px;
      }
      h1 {
        margin-top: 0;
        margin-bottom: 12px;
      }
      p {
        line-height: 1.6;
      }
      a.button {
        display: inline-block;
        margin-top: 18px;
        padding: 12px 18px;
        border-radius: 10px;
        background: #635bff;
        color: #ffffff;
        text-decoration: none;
        font-weight: 700;
      }
    </style>
    <script>
      window.addEventListener('load', () => {
        setTimeout(() => {
          window.location.href = ${JSON.stringify(deepLinkUrl)};
        }, 200);
      });
    </script>
  </head>
  <body>
    <div class="card">
      <h1>${title}</h1>
      <p>${message}</p>
      <a class="button" href="${deepLinkUrl}">Return to the app</a>
    </div>
  </body>
</html>`);
}

function logFunctionError(context, error) {
  const message = error instanceof Error ? error.message : String(error);
  const type = error && typeof error === "object" ? error.type || null : null;
  const code = error && typeof error === "object" ? error.code || null : null;
  const raw = error && typeof error === "object" ? error.raw || null : null;

  console.error(`${context} failed`, {
    error,
    message,
    type,
    code,
    raw,
  });

  return {message, type, code, raw};
}

function hasAdminRole(data) {
  const role = String(
      data.role || data.userRole || data.accountType || "",
  ).trim().toLowerCase();
  return role === "admin" ||
    role === "administrator" ||
    role === "super_admin" ||
    role === "superadmin" ||
    data.isAdmin === true ||
    data.isAdmin === "true" ||
    data.admin === true ||
    data.admin === "true";
}

async function assertAdminCallable(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const token = auth.token || {};
  const email = String(token.email || "").trim().toLowerCase();
  if (
    token.admin === true ||
    token.isAdmin === true ||
    email === "norahsulialaqeel@gmail.com"
  ) {
    return;
  }

  const userSnapshot = await sellerOnboardingDb
      .collection("users")
      .doc(auth.uid)
      .get();
  const userData = userSnapshot.data() || {};
  if (!hasAdminRole(userData)) {
    throw new HttpsError(
        "permission-denied",
        "Only admins can remove product posts.",
    );
  }
}

function isStripeAccountInvalidError(error) {
  if (!error || typeof error !== "object") {
    return false;
  }

  return error.code === "account_invalid" ||
    error.type === "StripeInvalidRequestError" &&
      String(error.message || "").includes("does not have access to account");
}

function ensureStripeConnectClientId() {
  if (!stripeConnectClientId) {
    throw new Error(
        "Stripe Connect OAuth client_id is not configured. Set STRIPE_CONNECT_CLIENT_ID in your functions environment.",
    );
  }
}

function ensureStripeSecretKey() {
  if (!stripe || !stripeSecretKey) {
    throw new Error(
        "Stripe secret key is not configured. Set STRIPE_SECRET_KEY in your functions environment.",
    );
  }
}

async function saveStripeAccountStatus({userRef, stripeAccountId}) {
  const status = await getStripeAccountStatus(stripeAccountId);
  await userRef.set({
    stripeAccountId,
    stripeOnboardingComplete: status.isConnected,
    stripeReadyForPayouts: status.readyForPayouts,
    stripeChargesEnabled: status.chargesEnabled,
    stripePayoutsEnabled: status.payoutsEnabled,
    stripeDetailsSubmitted: status.detailsSubmitted,
    stripeStatusCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return status;
}

setGlobalOptions({maxInstances: 10});

exports.createPaymentIntent = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  try {
    ensureStripeSecretKey();
    const {amount} = req.body;

    if (!amount || typeof amount !== "number" || amount <= 0) {
      res.status(400).send({error: "Invalid amount"});
      return;
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: "sar",
      payment_method_types: ["card"],
    });

    res.status(200).send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    res.status(500).send({
      error: error.message,
    });
  }
});

exports.createMarketplacePaymentIntent = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  try {
    ensureStripeSecretKey();
    const decodedToken = await authenticateRequest(req);
    const checkoutItems = await buildCheckoutItems(req.body.items || []);
    const amount = checkoutItems.reduce(
        (sum, item) => sum + item.lineAmountHalalas,
        0,
    );

    if (amount <= 0) {
      res.status(400).send({error: "Cart total must be greater than zero."});
      return;
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: "sar",
      automatic_payment_methods: {enabled: true},
      metadata: {
        buyerUid: decodedToken.uid,
        itemCount: String(checkoutItems.length),
      },
    });

    res.status(200).send({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      amount,
    });
  } catch (error) {
    const logged = logFunctionError("createMarketplacePaymentIntent POST", error);
    const statusCode = logged.message.includes("Authorization") ||
      logged.message.includes("token") ?
      401 :
      500;

    res.status(statusCode).send({
      error: logged.message,
      details: logged.code || null,
    });
  }
});

exports.createSellerStripeOAuthAuthorizeUrl = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  try {
    ensureStripeConnectClientId();
    const decodedToken = await authenticateRequest(req);
    const state = crypto.randomBytes(24).toString("hex");
    const expiresAt = Date.now() + (10 * 60 * 1000);
    const stateRef =
      sellerOnboardingDb.collection(stripeOauthStateCollection).doc(state);

    await stateRef.set({
      uid: decodedToken.uid,
      email: decodedToken.email || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAtMs: expiresAt,
      used: false,
    });

    const authorizeUrl = new URL("https://connect.stripe.com/oauth/authorize");
    authorizeUrl.searchParams.set("response_type", "code");
    authorizeUrl.searchParams.set("client_id", stripeConnectClientId);
    authorizeUrl.searchParams.set("scope", "read_write");
    authorizeUrl.searchParams.set("state", state);
    authorizeUrl.searchParams.set(
        "redirect_uri",
        getSellerStripeOAuthCallbackUrl(),
    );
    if (decodedToken.email) {
      authorizeUrl.searchParams.set("stripe_user[email]", decodedToken.email);
    }

    res.status(200).send({
      authorizeUrl: authorizeUrl.toString(),
      state,
      expiresAtMs: expiresAt,
    });
  } catch (error) {
    const logged = logFunctionError(
        "createSellerStripeOAuthAuthorizeUrl POST",
        error,
    );
    const statusCode = logged.message.includes("Authorization") ||
      logged.message.includes("token") ?
      401 :
      500;

    res.status(statusCode).send({
      error: logged.message,
      details: logged.code || null,
    });
  }
});

exports.handleSellerStripeOAuthCallback = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "GET") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  const deepLinkSuccess = getSellerStripeAppReturnUrl("success");
  const deepLinkError = getSellerStripeAppReturnUrl("error");

  try {
    ensureStripeConnectClientId();
    ensureStripeSecretKey();
    const state = String(req.query.state || "").trim();
    const code = String(req.query.code || "").trim();
    const errorCode = String(req.query.error || "").trim();
    const errorDescription = String(req.query.error_description || "").trim();

    if (errorCode) {
      sendAppRedirectPage(res, {
        title: "Stripe connection cancelled",
        message: errorDescription || "Stripe connection was cancelled.",
        deepLinkUrl: deepLinkError,
      });
      return;
    }

    if (!state || !code) {
      sendAppRedirectPage(res, {
        title: "Stripe connection failed",
        message: "Missing OAuth state or authorization code.",
        deepLinkUrl: deepLinkError,
      });
      return;
    }

    const stateRef =
      sellerOnboardingDb.collection(stripeOauthStateCollection).doc(state);
    const stateSnapshot = await stateRef.get();
    if (!stateSnapshot.exists) {
      sendAppRedirectPage(res, {
        title: "Stripe connection expired",
        message: "This Stripe connection link is invalid or expired.",
        deepLinkUrl: deepLinkError,
      });
      return;
    }

    const stateData = stateSnapshot.data() || {};
    const uid = String(stateData.uid || "").trim();
    const used = stateData.used === true;
    const expiresAtMs = Number(stateData.expiresAtMs || 0);
    if (!uid || used || !Number.isFinite(expiresAtMs) || Date.now() > expiresAtMs) {
      sendAppRedirectPage(res, {
        title: "Stripe connection expired",
        message: "This Stripe connection link is invalid or expired.",
        deepLinkUrl: deepLinkError,
      });
      return;
    }

    const tokenResponse = await stripe.oauth.token({
      grant_type: "authorization_code",
      code,
    });
    const stripeAccountId = String(tokenResponse.stripe_user_id || "").trim();
    if (!stripeAccountId) {
      throw new Error("Stripe OAuth response did not include stripe_user_id.");
    }

    const userRef = sellerOnboardingDb.collection("users").doc(uid);
    await saveStripeAccountStatus({userRef, stripeAccountId});
    await userRef.set({
      stripeOAuthConnectedAt: admin.firestore.FieldValue.serverTimestamp(),
      stripeConnectMode: "standard_oauth",
      stripeOauthScope: String(tokenResponse.scope || ""),
    }, {merge: true});
    await stateRef.set({
      used: true,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      stripeAccountId,
    }, {merge: true});

    sendAppRedirectPage(res, {
      title: "Stripe account connected",
      message: "Your Stripe account is now connected to Souqplus. Return to the app to continue.",
      deepLinkUrl: deepLinkSuccess,
    });
  } catch (error) {
    const logged = logFunctionError(
        "handleSellerStripeOAuthCallback GET",
        error,
    );
    sendAppRedirectPage(res, {
      title: "Stripe connection failed",
      message: logged.message,
      deepLinkUrl: deepLinkError,
    });
  }
});

exports.finalizeMarketplaceOrder = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  try {
    ensureStripeSecretKey();
    const decodedToken = await authenticateRequest(req);
    const orderId = String(req.body.orderId || "").trim();
    const paymentIntentId = String(req.body.paymentIntentId || "").trim();

    if (!orderId || !paymentIntentId) {
      res.status(400).send({error: "orderId and paymentIntentId are required."});
      return;
    }

    const orderRef = sellerOnboardingDb.collection("orders").doc(orderId);
    const orderSnapshot = await orderRef.get();

    if (!orderSnapshot.exists) {
      res.status(404).send({error: "Order not found."});
      return;
    }

    const orderData = orderSnapshot.data() || {};
    if (String(orderData.userId || "").trim() !== decodedToken.uid) {
      res.status(403).send({error: "You are not allowed to finalize this order."});
      return;
    }

    if (String(orderData.sellerTransferStatus || "").trim().toLowerCase() === "complete") {
      res.status(200).send({
        orderId,
        transferStatus: "complete",
        transfers: orderData.sellerTransfers || [],
      });
      return;
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    if (paymentIntent.status !== "succeeded") {
      res.status(400).send({
        error: `PaymentIntent ${paymentIntentId} is not succeeded.`,
        status: paymentIntent.status,
      });
      return;
    }

    const latestChargeId = typeof paymentIntent.latest_charge === "string" ?
      paymentIntent.latest_charge :
      paymentIntent.latest_charge && paymentIntent.latest_charge.id ?
        paymentIntent.latest_charge.id :
        "";

    if (!latestChargeId) {
      throw new Error("PaymentIntent is missing latest_charge.");
    }

    const latestCharge = await stripe.charges.retrieve(latestChargeId, {
      expand: ["balance_transaction"],
    });
    const balanceTransaction = latestCharge.balance_transaction;
    const transferCurrency =
      balanceTransaction &&
      typeof balanceTransaction === "object" &&
      balanceTransaction.currency ?
        String(balanceTransaction.currency).toLowerCase() :
        String(paymentIntent.currency || "sar").toLowerCase();
    const sourceAmount =
      balanceTransaction &&
      typeof balanceTransaction === "object" &&
      typeof balanceTransaction.amount === "number" ?
        balanceTransaction.amount :
        paymentIntent.amount;
    const distributableAmount =
      balanceTransaction &&
      typeof balanceTransaction === "object" &&
      typeof balanceTransaction.net === "number" &&
      balanceTransaction.net > 0 ?
        balanceTransaction.net :
        sourceAmount;

    const checkoutItems = await buildCheckoutItems(req.body.items || []);
    const requestedTotal = checkoutItems.reduce(
        (sum, item) => sum + item.lineAmountHalalas,
        0,
    );
    if (requestedTotal <= 0 || distributableAmount <= 0) {
      throw new Error("Invalid transfer amount calculation.");
    }

    const transfersBySeller = new Map();

    for (const item of checkoutItems) {
      const key = item.sellerStripeAccountId;
      const existing = transfersBySeller.get(key) || {
        destination: item.sellerStripeAccountId,
        sellerUid: item.ownerUid,
        requestedAmount: 0,
        productFirestoreIds: [],
      };
      existing.requestedAmount += item.lineAmountHalalas;
      existing.productFirestoreIds.push(item.productFirestoreId);
      transfersBySeller.set(key, existing);
    }

    const transferEntries = Array.from(transfersBySeller.values());
    let allocatedAmount = 0;
    for (let i = 0; i < transferEntries.length; i++) {
      const transfer = transferEntries[i];
      const isLast = i == transferEntries.length - 1;
      if (isLast) {
        transfer.amount = distributableAmount - allocatedAmount;
      } else {
        transfer.amount = Math.floor(
            (distributableAmount * transfer.requestedAmount) / requestedTotal,
        );
        allocatedAmount += transfer.amount;
      }
    }

    const transferResults = [];
    for (const [destination, transfer] of transfersBySeller.entries()) {
      if (!transfer.amount || transfer.amount <= 0) {
        continue;
      }

      const stripeTransfer = await stripe.transfers.create({
        amount: transfer.amount,
        currency: transferCurrency,
        destination,
        metadata: {
          orderId,
          buyerUid: decodedToken.uid,
          sellerUid: transfer.sellerUid,
          sourceChargeId: latestChargeId,
          transferBasis: "platform_balance_net",
        },
      }, {
        idempotencyKey: `order_${orderId}_${destination}`,
      });

      transferResults.push({
        id: stripeTransfer.id,
        amountHalalas: transfer.amount,
        currency: transferCurrency,
        destination,
        sellerUid: transfer.sellerUid,
        productFirestoreIds: transfer.productFirestoreIds,
      });
    }

    await orderRef.set({
      paymentIntentId,
      sellerTransferStatus: "complete",
      sellerTransfers: transferResults,
      sellerTransferCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
      sellerTransferCurrency: transferCurrency,
      sellerTransferSourceAmount: sourceAmount,
      sellerTransferDistributableAmount: distributableAmount,
      status: "complete",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    await markProductsSold(checkoutItems);

    res.status(200).send({
      orderId,
      transferStatus: "complete",
      transfers: transferResults,
    });
  } catch (error) {
    const logged = logFunctionError("finalizeMarketplaceOrder POST", error);
    const statusCode = logged.message.includes("Authorization") ||
      logged.message.includes("token") ?
      401 :
      500;

    res.status(statusCode).send({
      error: logged.message,
      details: logged.code || null,
    });
  }
});

exports.createSellerStripeAccountLink = onRequest(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method === "GET") {
    if (req.query.mode === "refresh") {
      const uid = String(req.query.uid || "").trim();
      const stripeAccountId = String(req.query.account || "").trim();

      if (!uid || !stripeAccountId) {
        sendStatusPage(
            res,
            "Stripe link expired",
            "The Stripe onboarding link expired. Return to the app and try connecting Stripe again.",
        );
        return;
      }

      try {
        const userRef = sellerOnboardingDb.collection("users").doc(uid);
        const userSnapshot = await userRef.get();
        const userData = userSnapshot.data() || {};
        const savedStripeAccountId = String(userData.stripeAccountId || "").trim();

        if (savedStripeAccountId !== stripeAccountId) {
          res.status(403).send({error: "Stripe account mismatch"});
          return;
        }

        const accountLink = await createStripeAccountLink({stripeAccountId, uid});
        res.redirect(303, accountLink.url);
        return;
      } catch (error) {
        const logged = logFunctionError(
            "createSellerStripeAccountLink GET refresh",
            error,
        );
        res.status(500).send({
          error: logged.message,
          details: logged.code || null,
        });
        return;
      }
    }

    if (req.query.mode === "return") {
      sendReturnPage(res);
      return;
    }

    sendStatusPage(
        res,
        "Seller Stripe onboarding",
        "This endpoint is available. Start seller Stripe onboarding from the app to generate a new onboarding link.",
    );
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({error: "Method Not Allowed"});
    return;
  }

  try {
    ensureStripeSecretKey();
    const decodedToken = await authenticateRequest(req);
    const userRef = sellerOnboardingDb.collection("users").doc(decodedToken.uid);

    console.error("createSellerStripeAccountLink POST Firestore read start", {
      databaseId: "souqplus",
      path: userRef.path,
      uid: decodedToken.uid,
    });
    const userSnapshot = await userRef.get();
    console.error("createSellerStripeAccountLink POST Firestore read success", {
      databaseId: "souqplus",
      path: userRef.path,
      exists: userSnapshot.exists,
      uid: decodedToken.uid,
    });
    const userData = userSnapshot.data() || {};

    let stripeAccountId = (userData.stripeAccountId || "").trim();

    if (req.body && req.body.mode === "status") {
      if (!stripeAccountId) {
        res.status(200).send({
          stripeAccountId: "",
          isConnected: false,
          chargesEnabled: false,
          payoutsEnabled: false,
          detailsSubmitted: false,
        });
        return;
      }

      let status;
      try {
        status = await getStripeAccountStatus(stripeAccountId);
      } catch (error) {
        if (isStripeAccountInvalidError(error)) {
          await userRef.set({
            stripeAccountId: admin.firestore.FieldValue.delete(),
            stripeOnboardingComplete: false,
            stripeReadyForPayouts: false,
            stripeChargesEnabled: false,
            stripePayoutsEnabled: false,
            stripeDetailsSubmitted: false,
            stripeStatusCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
            stripeConnectMode: admin.firestore.FieldValue.delete(),
            stripeOauthScope: admin.firestore.FieldValue.delete(),
            stripeOAuthConnectedAt: admin.firestore.FieldValue.delete(),
          }, {merge: true});

          res.status(200).send({
            stripeAccountId: "",
            isConnected: false,
            readyForPayouts: false,
            chargesEnabled: false,
            payoutsEnabled: false,
            detailsSubmitted: false,
          });
          return;
        }

        throw error;
      }

      await userRef.set({
        stripeOnboardingComplete: status.isConnected,
        stripeReadyForPayouts: status.readyForPayouts,
        stripeChargesEnabled: status.chargesEnabled,
        stripePayoutsEnabled: status.payoutsEnabled,
        stripeDetailsSubmitted: status.detailsSubmitted,
        stripeStatusCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      res.status(200).send({
        stripeAccountId,
        isConnected: status.isConnected,
        readyForPayouts: status.readyForPayouts,
        chargesEnabled: status.chargesEnabled,
        payoutsEnabled: status.payoutsEnabled,
        detailsSubmitted: status.detailsSubmitted,
      });
      return;
    }

    res.status(400).send({
      error: "Stripe onboarding now uses Standard OAuth. Call createSellerStripeOAuthAuthorizeUrl instead.",
    });
  } catch (error) {
    const logged = logFunctionError(
        "createSellerStripeAccountLink POST",
        error,
    );
    const statusCode = logged.message.includes("Authorization") ||
      logged.message.includes("token") ?
      401 :
      500;

    res.status(statusCode).send({
      error: logged.message,
      details: logged.code || null,
    });
  }
});

exports.sendnotificationtousers = onCall(async (request) => {
  const auth = request.auth;

  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const data = request.data || {};
  const title = String(data.title || "").trim();
  const message = String(data.message || "").trim();
  const type = String(data.type || "system_update").trim();

  if (!title || !message) {
    throw new HttpsError(
      "invalid-argument",
      "title and message are required."
    );
  }

  const usersSnapshot = await sellerOnboardingDb.collection("users").get();
  const writes = [];

  for (const userDoc of usersSnapshot.docs) {
    const notifRef = sellerOnboardingDb
      .collection("users")
      .doc(userDoc.id)
      .collection("notifications")
      .doc();

    writes.push(
      notifRef.set({
        type,
        title,
        message,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      })
    );
  }

  await Promise.all(writes);

  return {success: true};
});

exports.removeProductPostAsAdmin = onCall(async (request) => {
  await assertAdminCallable(request);

  const productId = String(
      request.data && request.data.productId || "",
  ).trim();
  if (!productId) {
    throw new HttpsError(
        "invalid-argument",
        "productId is required.",
    );
  }

  const productRef = sellerOnboardingDb.collection("products").doc(productId);
  const productSnapshot = await productRef.get();
  if (!productSnapshot.exists) {
    throw new HttpsError("not-found", "Product post was not found.");
  }

  await productRef.delete();
  return {success: true, productId};
});

exports.sendPushOnNotificationCreated = onDocumentCreated(
    {
      document: "users/{uid}/notifications/{notificationId}",
      database: "souqplus",
    },
    async (event) => {
      const notificationSnapshot = event.data;
      if (!notificationSnapshot) {
        return;
      }

      const uid = event.params.uid;
      const notificationId = event.params.notificationId;
      const notificationData = notificationSnapshot.data() || {};
      const title = String(notificationData.title || "Souqplus").trim();
      const message = String(
          notificationData.message || "You have a new notification.",
      ).trim();
      const type = String(notificationData.type || "general").trim();

      const userSnapshot = await sellerOnboardingDb
          .collection("users")
          .doc(uid)
          .get();
      const userData = userSnapshot.data() || {};
      const tokenSet = new Set();

      if (Array.isArray(userData.fcmTokens)) {
        for (const token of userData.fcmTokens) {
          const normalized = String(token || "").trim();
          if (normalized) {
            tokenSet.add(normalized);
          }
        }
      }

      const latestToken = String(userData.latestFcmToken || "").trim();
      if (latestToken) {
        tokenSet.add(latestToken);
      }

      const tokens = Array.from(tokenSet);
      if (!tokens.length) {
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title,
          body: message,
        },
        data: {
          notificationId,
          type,
          title,
          message,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "souqplus_notifications",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (result.success) {
          return;
        }

        const code = result.error && result.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          invalidTokens.push(tokens[index]);
        }
      });

      if (invalidTokens.length) {
        await userSnapshot.ref.set({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        }, {merge: true});
      }
    },
);
