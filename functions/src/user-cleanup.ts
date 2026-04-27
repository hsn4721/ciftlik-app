/**
 * User Cleanup Cloud Function — Firestore users/{uid} silindiğinde:
 *   1. Firebase Auth'tan kullanıcıyı sil (admin SDK gerekir)
 *   2. users/{uid} email ile eşleşen pending invitations'ı sil
 *   3. users/{uid}/memberships/* alt koleksiyonunu temizle
 *   4. Vet ise — collectionGroup vet_requests'lerinde vetId=uid olanları
 *      arşivle (silmek yerine soft-delete: archived: true)
 *
 * Trigger: Firestore document onDelete users/{uid}
 *
 * Bu function senin daha önce raporladığın bug'u çözer:
 *   "Uygulamadan kullanıcı sildim ama Firebase Auth'ta hâlâ var"
 */
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

export const onUserDelete = onDocumentDeleted(
  {
    document: "users/{uid}",
    region: "europe-west1",
  },
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.data();

    if (!before) {
      logger.warn("User deleted but no data snapshot", { uid });
      return;
    }

    const email = (before.email as string | undefined)?.toLowerCase().trim();
    const role = before.role as string | undefined;

    logger.info("User cleanup started", { uid, email, role });

    // 1) Firebase Auth user'ı sil
    try {
      await getAuth().deleteUser(uid);
      logger.info("Firebase Auth user deleted", { uid });
    } catch (e: unknown) {
      const code = (e as { code?: string }).code;
      if (code === "auth/user-not-found") {
        logger.info("Auth user already gone", { uid });
      } else {
        logger.error("Failed to delete Auth user", { uid, error: e });
        // Auth silme başarısız olsa da Firestore cleanup'ı yapmaya devam et
      }
    }

    const db = getFirestore();

    // 2) Pending invitations temizle (kullanıcı email'ine yönlendirilmiş olanlar)
    if (email && email.length > 0) {
      try {
        const invites = await db
          .collection("invitations")
          .where("email", "==", email)
          .where("status", "==", "pending")
          .get();

        const batch = db.batch();
        invites.docs.forEach((d) => batch.delete(d.ref));
        if (invites.size > 0) {
          await batch.commit();
          logger.info(`Deleted ${invites.size} pending invitation(s)`, { email });
        }
      } catch (e) {
        logger.error("Invitation cleanup failed", { email, error: e });
      }
    }

    // 3) memberships subcollection'ı zaten Firestore'da silinmiş olabilir
    //    (cascade delete) — yine de kontrol edip orphan temizle
    try {
      const memberships = await db
        .collection("users")
        .doc(uid)
        .collection("memberships")
        .get();

      if (memberships.size > 0) {
        const batch = db.batch();
        memberships.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        logger.info(`Cleaned ${memberships.size} membership(s)`, { uid });
      }
    } catch (e) {
      logger.error("Memberships cleanup failed", { uid, error: e });
    }

    // 4) Farm members ayna doc'larını temizle (collectionGroup query)
    try {
      const memberDocs = await db
        .collectionGroup("members")
        .where("uid", "==", uid)
        .get();

      if (memberDocs.size > 0) {
        const batch = db.batch();
        memberDocs.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        logger.info(`Cleaned ${memberDocs.size} farm member ayna doc(s)`, { uid });
      }
    } catch (e) {
      logger.error("Farm members cleanup failed", { uid, error: e });
    }

    // 5) Vet ise — vet_requests'leri arşivle (silmek yerine, owner'lar history için)
    if (role === "vet") {
      try {
        const vetReqs = await db
          .collectionGroup("vet_requests")
          .where("vetId", "==", uid)
          .get();

        const batch = db.batch();
        vetReqs.docs.forEach((d) => {
          batch.update(d.ref, {
            archived: true,
            archivedReason: "vet_account_deleted",
            archivedAt: FieldValue.serverTimestamp(),
          });
        });
        if (vetReqs.size > 0) {
          await batch.commit();
          logger.info(`Archived ${vetReqs.size} vet request(s)`, { uid });
        }
      } catch (e) {
        logger.error("Vet requests archive failed", { uid, error: e });
      }
    }

    // 6) Subscription doc temizle (vet için user-level)
    try {
      const subDocs = await db
        .collection("users")
        .doc(uid)
        .collection("subscription")
        .get();

      if (subDocs.size > 0) {
        const batch = db.batch();
        subDocs.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        logger.info(`Cleaned subscription docs`, { uid });
      }
    } catch (e) {
      logger.error("Subscription cleanup failed", { uid, error: e });
    }

    logger.info("User cleanup completed", { uid });
  }
);
