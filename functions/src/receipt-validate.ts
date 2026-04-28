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
// SK1 (legacy) verifyReceipt için zorunlu — App Store Connect → My Apps →
// ÇiftlikPRO → App Information → App-Specific Shared Secret. SK2 modunda
// kullanılmaz (placeholder TODO_SHARED_SECRET ile geçici doldurulabilir).
const APPLE_SHARED_SECRET = defineSecret("APPLE_SHARED_SECRET");
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
      APPLE_SHARED_SECRET,
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

    // expiresAt validation'dan gelmek zorunda — fallback (now+1yıl) sahte
    // expired subscription'ı aktif yazardı (gelir kaybı / refund handling fail).
    if (!validation.expiresAt) {
      logger.error("Validation succeeded but no expiresAt — rejecting", {
        uid: auth.uid,
        productId: data.productId,
      });
      throw new HttpsError(
        "internal",
        "Abonelik bitiş tarihi alınamadı, lütfen destek ile iletişime geçin"
      );
    }

    // Firestore'a doğrulanmış subscription state yaz.
    const db = getFirestore();
    const planFromProduct = mapProductIdToPlan(data.productId);
    const now = Timestamp.now();
    const expiresAt = Timestamp.fromDate(validation.expiresAt);

    // ─── Family Sharing güvenliği: transactionId uniqueness check ────────
    // Apple Family Sharing açık olduğu için bir Apple satın alması 5 family
    // member'ın hesabında valid sayılır. Bu kontrol olmadan, 5 farklı
    // Firebase Auth hesabı 5 farklı farm'a aynı transactionId ile Pro yazardı
    // (gelir kaybı). Firestore transaction ile atomic kontrol:
    //   - transactionId daha önce farklı bir targetPath'a yazılmışsa REJECT
    //   - aynı targetPath ise idempotent (örn. restore retry) — geçerli
    //   - hiç görülmemişse yeni iap_transactions/ doc'u + subscription write
    if (validation.transactionId) {
      const txRef = db.collection("iap_transactions").doc(validation.transactionId);
      const subRef = db.doc(data.targetPath);

      await db.runTransaction(async (t) => {
        const txDoc = await t.get(txRef);
        if (txDoc.exists) {
          const existingPath = txDoc.data()?.targetPath;
          if (existingPath && existingPath !== data.targetPath) {
            logger.warn("TransactionId reuse blocked (Family Sharing abuse)", {
              transactionId: validation.transactionId,
              existingPath,
              attemptedPath: data.targetPath,
              uid: auth.uid,
            });
            throw new HttpsError(
              "permission-denied",
              "Bu satın alma zaten farklı bir hesaba kayıtlı. " +
                "Aile üyeleri aynı abonelikten ayrı çiftlikler için yararlanamaz."
            );
          }
        } else {
          t.set(txRef, {
            transactionId: validation.transactionId,
            targetPath: data.targetPath,
            productId: data.productId,
            paidByUid: auth.uid,
            platform: data.platform,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        t.set(
          subRef,
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
      });
    } else {
      // transactionId yok — uniqueness check atlanır, eskimiş davranışa düş
      logger.warn("Validation returned no transactionId; uniqueness check skipped", {
        uid: auth.uid,
        productId: data.productId,
      });
      await db.doc(data.targetPath).set(
        {
          plan: planFromProduct,
          status: "active",
          startedAt: now,
          expiresAt,
          autoRenew: validation.autoRenew ?? true,
          productId: data.productId,
          platform: data.platform,
          paidByUid: auth.uid,
          serverValidated: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

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
  // users/{uid}/subscription/current — caller kendi uid'i olmalı + vet rolü
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
    // Vet rolü doğrulaması — çiftlik kullanıcı kendi user-level path'ine vet plan
    // satın alıp DB'de "plan: vet" göstermesini engeller.
    const userDoc = await getFirestore().doc(`users/${uid}`).get();
    const regRole = userDoc.data()?.registrationRole;
    if (regRole !== "vet") {
      throw new HttpsError(
        "permission-denied",
        "Veteriner planı yalnızca veteriner hesapları içindir"
      );
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

// ─── Apple validation: SK1 (legacy verifyReceipt) + SK2 (Server API) ─────
//
// Flutter `in_app_purchase` v3.2.0 SK1 default modunda
// `serverVerificationData` = base64 encoded receipt blob (tüm transaction
// history). SK2 modunda ise JWS string (3 dot-separated parts).
//
// Detection: string'de '.' karakteri 2'den fazla varsa JWS, yoksa SK1 receipt.
//
// Sandbox/production: SK1 → status 21007 ile sandbox fallback. SK2 →
// production endpoint 404 dönerse sandbox endpoint dene (TestFlight tüm
// satın almaları sandbox'ta üretir).
async function validateAppleReceipt(receiptOrJws: string, productId: string): Promise<ValidationResult> {
  const bundleId = APPLE_BUNDLE_ID.value().trim();
  if (!bundleId || bundleId === "TODO_IOS") {
    throw new HttpsError("failed-precondition", "Apple bundle ID secret eksik");
  }

  const isJws = receiptOrJws.split(".").length === 3;
  if (isJws) {
    return validateAppleSK2(receiptOrJws, productId, bundleId);
  } else {
    return validateAppleSK1(receiptOrJws, productId, bundleId);
  }
}

// SK1 — legacy verifyReceipt endpoint. Apple deprecated etti ama hâlâ
// çalışıyor; `in_app_purchase` plugin default modu bunu üretiyor.
async function validateAppleSK1(
  receiptBase64: string,
  productId: string,
  bundleId: string
): Promise<ValidationResult> {
  const sharedSecret = APPLE_SHARED_SECRET.value().trim();
  if (!sharedSecret || sharedSecret === "TODO_SHARED_SECRET") {
    throw new HttpsError(
      "failed-precondition",
      "Apple shared secret tanımlı değil — App Store Connect'ten alıp APPLE_SHARED_SECRET secret'ına yükleyin"
    );
  }

  const body = JSON.stringify({
    "receipt-data": receiptBase64,
    "password": sharedSecret,
    "exclude-old-transactions": true,
  });

  // Önce production, 21007 → sandbox
  let res = await fetch("https://buy.itunes.apple.com/verifyReceipt", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });
  let json = (await res.json()) as AppleSK1Response;
  if (json.status === 21007) {
    res = await fetch("https://sandbox.itunes.apple.com/verifyReceipt", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    json = (await res.json()) as AppleSK1Response;
  }

  if (json.status !== 0) {
    return { valid: false, reason: `Apple verifyReceipt status ${json.status}` };
  }
  if (json.receipt?.bundle_id !== bundleId) {
    return { valid: false, reason: "Bundle ID uyuşmuyor" };
  }

  // En güncel transaction'ı bul (latest_receipt_info → expires_date_ms en büyük olan).
  const items = (json.latest_receipt_info ?? json.receipt?.in_app ?? []).filter(
    (t) => t.product_id === productId
  );
  if (items.length === 0) {
    return { valid: false, reason: "Product ID uyuşan transaction yok" };
  }
  items.sort((a, b) => Number(b.expires_date_ms ?? 0) - Number(a.expires_date_ms ?? 0));
  const latest = items[0];
  const expiresMs = Number(latest.expires_date_ms ?? 0);
  if (!expiresMs) {
    return { valid: false, reason: "expires_date eksik" };
  }
  if (expiresMs < Date.now()) {
    return { valid: false, reason: "Abonelik süresi dolmuş" };
  }
  if (latest.cancellation_date_ms) {
    return { valid: false, reason: "Abonelik iptal edilmiş" };
  }

  return {
    valid: true,
    transactionId: latest.original_transaction_id ?? latest.transaction_id,
    expiresAt: new Date(expiresMs),
    autoRenew: true,
  };
}

// SK2 — modern App Store Server API. JWS payload'undan transactionId çıkarıp
// transactions/{id} endpoint'ine sorgu atılır.
async function validateAppleSK2(
  jwsRepresentation: string,
  productId: string,
  bundleId: string
): Promise<ValidationResult> {
  const keyId = APPLE_KEY_ID.value().trim();
  const issuerId = APPLE_ISSUER_ID.value().trim();
  const privateKey = APPLE_PRIVATE_KEY.value();
  if (!keyId || !issuerId || !privateKey ||
      keyId === "TODO_IOS" || issuerId === "TODO_IOS") {
    throw new HttpsError("failed-precondition", "Apple SK2 secrets eksik");
  }

  // JWS payload → transactionId
  const initialPayload = decodeJwsPayload(jwsRepresentation) as {
    transactionId?: string;
    bundleId?: string;
  };
  if (!initialPayload.transactionId) {
    return { valid: false, reason: "JWS'de transactionId yok" };
  }
  if (initialPayload.bundleId && initialPayload.bundleId !== bundleId) {
    return { valid: false, reason: "JWS bundle ID uyuşmuyor" };
  }
  const transactionId = encodeURIComponent(initialPayload.transactionId);

  const token = jwt.sign(
    {
      iss: issuerId,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      aud: "appstoreconnect-v1",
      bid: bundleId,
    },
    privateKey,
    { algorithm: "ES256", keyid: keyId }
  );

  // Önce production endpoint, 404 ise sandbox (TestFlight için kritik)
  const tryEndpoint = async (host: string) => {
    const url = `${host}/inApps/v1/transactions/${transactionId}`;
    return fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  };
  let res = await tryEndpoint("https://api.storekit.itunes.apple.com");
  if (res.status === 404) {
    res = await tryEndpoint("https://api.storekit-sandbox.itunes.apple.com");
  }
  if (!res.ok) {
    return { valid: false, reason: `Apple API ${res.status}` };
  }

  const json = (await res.json()) as { signedTransactionInfo?: string };
  if (!json.signedTransactionInfo) {
    return { valid: false, reason: "Apple Server API boş yanıt" };
  }

  const payload = decodeJwsPayload(json.signedTransactionInfo) as {
    productId: string;
    transactionId: string;
    originalTransactionId: string;
    expiresDate: number;
    bundleId: string;
    revocationDate?: number;
    revocationReason?: number;
  };

  if (payload.bundleId !== bundleId) {
    return { valid: false, reason: "Bundle ID uyuşmuyor" };
  }
  if (payload.productId !== productId) {
    return { valid: false, reason: "Product ID uyuşmuyor" };
  }
  if (payload.revocationDate) {
    return {
      valid: false,
      reason: `Apple satın almayı iptal etti (reason ${payload.revocationReason ?? "unknown"})`,
    };
  }
  if (payload.expiresDate < Date.now()) {
    return { valid: false, reason: "Abonelik süresi dolmuş" };
  }

  return {
    valid: true,
    transactionId: payload.originalTransactionId ?? payload.transactionId,
    expiresAt: new Date(payload.expiresDate),
    autoRenew: true,
  };
}

interface AppleSK1Transaction {
  product_id: string;
  transaction_id?: string;
  original_transaction_id?: string;
  expires_date_ms?: string;
  cancellation_date_ms?: string;
}

interface AppleSK1Response {
  status: number;
  receipt?: {
    bundle_id?: string;
    in_app?: AppleSK1Transaction[];
  };
  latest_receipt_info?: AppleSK1Transaction[];
}

function decodeJwsPayload(jws: string): unknown {
  const [, payloadB64] = jws.split(".");
  const json = Buffer.from(payloadB64, "base64url").toString("utf8");
  return JSON.parse(json);
}

// ─── Google Play Developer API validation ───────────────────────────────

async function validateGoogleReceipt(purchaseToken: string, productId: string): Promise<ValidationResult> {
  const serviceAccountJson = GOOGLE_PLAY_SERVICE_ACCOUNT.value().trim();
  const packageName = GOOGLE_PLAY_PACKAGE_NAME.value().trim();

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
