/**
 * IAP Receipt Validation Cloud Function.
 *
 * Akış:
 *   1. Client purchase yapar → flutter `in_app_purchase` plugin
 *      `purchase.verificationData.serverVerificationData` döner.
 *   2. Client Cloud Function'a callable çağrı yapar:
 *        await FirebaseFunctions.instance.httpsCallable('validateReceipt')({
 *          platform: 'ios' | 'android',
 *          receipt: base64ReceiptOrToken,
 *          productId: 'ciftlikpro_pro_yearly',
 *          targetPath: 'farms/{farmId}/subscription/current'  // veya users/{uid}/subscription/current
 *        })
 *   3. Function Apple/Google'a sorar, geçerliyse Firestore'a yazar.
 *
 * Production'da gerekli setup:
 *   - Apple App Store Server API:
 *     * https://appstoreconnect.apple.com → Users and Access → Keys → In-App Purchase
 *     * .p8 private key indir, ortam değişkenlerine koy:
 *       firebase functions:secrets:set APPLE_KEY_ID
 *       firebase functions:secrets:set APPLE_ISSUER_ID
 *       firebase functions:secrets:set APPLE_PRIVATE_KEY  (p8 içeriği)
 *       firebase functions:secrets:set APPLE_BUNDLE_ID  (com.ciftlikpro.app)
 *
 *   - Google Play Developer API:
 *     * Cloud Console → Service Accounts → yeni hesap, key indir (json)
 *     * Play Console'da Service Account'a "Financial Data" izni ver
 *     * firebase functions:secrets:set GOOGLE_PLAY_SERVICE_ACCOUNT  (json içeriği)
 *     * firebase functions:secrets:set GOOGLE_PLAY_PACKAGE_NAME  (com.ciftlikpro.app)
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { google } from "googleapis";
import * as jwt from "jsonwebtoken";
import fetch from "node-fetch";

// Secrets — `firebase functions:secrets:set` ile yüklenir.
const APPLE_KEY_ID = defineSecret("APPLE_KEY_ID");
const APPLE_ISSUER_ID = defineSecret("APPLE_ISSUER_ID");
const APPLE_PRIVATE_KEY = defineSecret("APPLE_PRIVATE_KEY");
const APPLE_BUNDLE_ID = defineSecret("APPLE_BUNDLE_ID");
const GOOGLE_PLAY_SERVICE_ACCOUNT = defineSecret("GOOGLE_PLAY_SERVICE_ACCOUNT");
const GOOGLE_PLAY_PACKAGE_NAME = defineSecret("GOOGLE_PLAY_PACKAGE_NAME");

const ALLOWED_PRODUCT_IDS = new Set([
  "ciftlikpro_starter_monthly",
  "ciftlikpro_starter_yearly",
  "ciftlikpro_family_monthly",
  "ciftlikpro_family_yearly",
  "ciftlikpro_pro_monthly",
  "ciftlikpro_pro_yearly",
  "ciftlikpro_vet_yearly",
]);

interface ValidateReceiptInput {
  platform: "ios" | "android";
  receipt: string;
  productId: string;
  /**
   * Hedef Firestore yolu — `farms/{farmId}/subscription/current` veya
   * `users/{uid}/subscription/current`. Function caller'ın yetkili olduğunu
   * doğrular (vet → kendi user-level, farm subscription → owner).
   */
  targetPath: string;
}

export const validateReceipt = onCall(
  {
    secrets: [
      APPLE_KEY_ID,
      APPLE_ISSUER_ID,
      APPLE_PRIVATE_KEY,
      APPLE_BUNDLE_ID,
      GOOGLE_PLAY_SERVICE_ACCOUNT,
      GOOGLE_PLAY_PACKAGE_NAME,
    ],
    region: "europe-west1",
    enforceAppCheck: false, // Faz 13c'de App Check eklenince true yapılacak
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Login zorunlu");
    }
    const data = request.data as ValidateReceiptInput;
    if (!data || !data.platform || !data.receipt || !data.productId || !data.targetPath) {
      throw new HttpsError("invalid-argument", "Eksik alan");
    }
    if (!ALLOWED_PRODUCT_IDS.has(data.productId)) {
      throw new HttpsError("invalid-argument", `Bilinmeyen productId: ${data.productId}`);
    }

    // Yetki kontrolü — caller hedef path'e yazma yetkisine sahip mi?
    await assertCallerCanWriteTarget(auth.uid, data.targetPath, data.productId);

    let validation: ValidationResult;
    try {
      if (data.platform === "ios") {
        validation = await validateAppleReceipt(data.receipt, data.productId);
      } else {
        validation = await validateGoogleReceipt(data.receipt, data.productId);
      }
    } catch (e: unknown) {
      logger.error("Receipt validation failed", e);
      throw new HttpsError("internal", "Receipt doğrulanamadı");
    }

    if (!validation.valid) {
      logger.warn("Invalid receipt rejected", {
        uid: auth.uid,
        productId: data.productId,
        reason: validation.reason,
      });
      throw new HttpsError("permission-denied", `Geçersiz satın alma: ${validation.reason}`);
    }

    // Firestore'a doğrulanmış subscription state yaz.
    const db = getFirestore();
    const planFromProduct = mapProductIdToPlan(data.productId);
    const isYearly = data.productId.endsWith("_yearly");
    const now = Timestamp.now();
    const expiresAt = validation.expiresAt
      ? Timestamp.fromDate(validation.expiresAt)
      : Timestamp.fromMillis(now.toMillis() + (isYearly ? 365 : 30) * 86400_000);

    await db.doc(data.targetPath).set(
      {
        plan: planFromProduct,
        status: "active",
        startedAt: now,
        expiresAt,
        autoRenew: validation.autoRenew ?? true,
        productId: data.productId,
        platform: data.platform,
        transactionId: validation.transactionId,
        // receipt SAKLANMAZ — sadece transactionId ile track ediyoruz, KVKK
        paidByUid: auth.uid,
        serverValidated: true, // Cloud Function tarafından doğrulandı
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info("Receipt validated and subscription updated", {
      uid: auth.uid,
      productId: data.productId,
      transactionId: validation.transactionId,
    });

    return {
      success: true,
      plan: planFromProduct,
      expiresAt: expiresAt.toMillis(),
    };
  }
);

// ─── Helpers ────────────────────────────────────────────────────────────

interface ValidationResult {
  valid: boolean;
  reason?: string;
  transactionId?: string;
  expiresAt?: Date;
  autoRenew?: boolean;
}

async function assertCallerCanWriteTarget(uid: string, targetPath: string, productId: string): Promise<void> {
  // farms/{farmId}/subscription/current — caller owner/assistant olmalı
  // users/{uid}/subscription/current — caller kendi uid'i olmalı + vet plan
  const farmMatch = targetPath.match(/^farms\/([^/]+)\/subscription\/[^/]+$/);
  const userMatch = targetPath.match(/^users\/([^/]+)\/subscription\/[^/]+$/);

  if (farmMatch) {
    if (productId === "ciftlikpro_vet_yearly") {
      throw new HttpsError("permission-denied", "Vet planı çiftlik subscription'ına yazılamaz");
    }
    const farmId = farmMatch[1];
    const memDoc = await getFirestore().doc(`users/${uid}/memberships/${farmId}`).get();
    const role = memDoc.data()?.role;
    if (memDoc.data()?.isActive !== true || (role !== "owner" && role !== "assistant")) {
      throw new HttpsError("permission-denied", "Yalnızca Ana Sahip / Yardımcı abonelik alabilir");
    }
  } else if (userMatch) {
    if (productId !== "ciftlikpro_vet_yearly") {
      throw new HttpsError("permission-denied", "User-level subscription sadece vet planı içindir");
    }
    if (userMatch[1] !== uid) {
      throw new HttpsError("permission-denied", "Sadece kendi user subscription'ınızı yazabilirsiniz");
    }
  } else {
    throw new HttpsError("invalid-argument", `Geçersiz targetPath: ${targetPath}`);
  }
}

function mapProductIdToPlan(productId: string): string {
  if (productId.startsWith("ciftlikpro_starter_")) return "starter";
  if (productId.startsWith("ciftlikpro_family_")) return "family";
  if (productId.startsWith("ciftlikpro_pro_")) return "pro";
  if (productId.startsWith("ciftlikpro_vet_")) return "vet";
  return "none";
}

// ─── Apple App Store Server API validation ──────────────────────────────

async function validateAppleReceipt(transactionId: string, productId: string): Promise<ValidationResult> {
  const keyId = APPLE_KEY_ID.value();
  const issuerId = APPLE_ISSUER_ID.value();
  const privateKey = APPLE_PRIVATE_KEY.value();
  const bundleId = APPLE_BUNDLE_ID.value();

  if (!keyId || !issuerId || !privateKey || !bundleId) {
    throw new HttpsError("failed-precondition", "Apple secrets henüz yapılandırılmamış");
  }

  // JWT token oluştur (Apple Developer documentation)
  const token = jwt.sign(
    {
      iss: issuerId,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      aud: "appstoreconnect-v1",
      bid: bundleId,
    },
    privateKey,
    {
      algorithm: "ES256",
      keyid: keyId,
    }
  );

  // Apple App Store Server API — production endpoint
  const baseUrl = "https://api.storekit.itunes.apple.com";
  const url = `${baseUrl}/inApps/v1/transactions/${transactionId}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    return { valid: false, reason: `Apple API ${res.status}` };
  }

  const json = (await res.json()) as { signedTransactionInfo?: string };
  if (!json.signedTransactionInfo) {
    return { valid: false, reason: "Empty Apple response" };
  }

  // signedTransactionInfo bir JWS — payload'u decode et (signature verification opt.)
  const payload = decodeJwsPayload(json.signedTransactionInfo) as {
    productId: string;
    transactionId: string;
    expiresDate: number;
    bundleId: string;
  };

  if (payload.bundleId !== bundleId) {
    return { valid: false, reason: "Bundle ID uyuşmuyor" };
  }
  if (payload.productId !== productId) {
    return { valid: false, reason: "Product ID uyuşmuyor" };
  }
  if (payload.expiresDate < Date.now()) {
    return { valid: false, reason: "Abonelik süresi dolmuş" };
  }

  return {
    valid: true,
    transactionId: payload.transactionId,
    expiresAt: new Date(payload.expiresDate),
    autoRenew: true,
  };
}

function decodeJwsPayload(jws: string): unknown {
  const [, payloadB64] = jws.split(".");
  const json = Buffer.from(payloadB64, "base64url").toString("utf8");
  return JSON.parse(json);
}

// ─── Google Play Developer API validation ───────────────────────────────

async function validateGoogleReceipt(purchaseToken: string, productId: string): Promise<ValidationResult> {
  const serviceAccountJson = GOOGLE_PLAY_SERVICE_ACCOUNT.value();
  const packageName = GOOGLE_PLAY_PACKAGE_NAME.value();

  if (!serviceAccountJson || !packageName) {
    throw new HttpsError("failed-precondition", "Google Play secrets henüz yapılandırılmamış");
  }

  const credentials = JSON.parse(serviceAccountJson);
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });

  const androidpublisher = google.androidpublisher({ version: "v3", auth });

  try {
    const resp = await androidpublisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
    });

    const data = resp.data;
    if (!data.lineItems || data.lineItems.length === 0) {
      return { valid: false, reason: "Boş subscription response" };
    }

    const item = data.lineItems[0];
    if (item.productId !== productId) {
      return { valid: false, reason: "Product ID uyuşmuyor" };
    }

    const expiryStr = item.expiryTime;
    const expiresAt = expiryStr ? new Date(expiryStr) : undefined;
    if (expiresAt && expiresAt < new Date()) {
      return { valid: false, reason: "Abonelik süresi dolmuş" };
    }

    return {
      valid: true,
      transactionId: data.latestOrderId ?? undefined,
      expiresAt,
      autoRenew: data.subscriptionState === "SUBSCRIPTION_STATE_ACTIVE",
    };
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return { valid: false, reason: `Google Play API: ${msg}` };
  }
}
