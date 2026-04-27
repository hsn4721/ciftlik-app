/**
 * ÇiftlikPRO Cloud Functions — entry point.
 *
 * Functions:
 *   - validateReceipt: HTTPS callable, IAP receipt'i Apple/Google'a doğrulatır
 *     ve subscription state'i Firestore'a yazar.
 *   - onUserDelete: Firestore users/{uid} silindiğinde Firebase Auth'tan da
 *     siler ve orphan invitation/vet_request docs'larını temizler.
 *
 * Deploy:
 *   cd functions
 *   npm install
 *   npm run build
 *   firebase deploy --only functions
 */
import { initializeApp } from "firebase-admin/app";

initializeApp();

export { validateReceipt } from "./receipt-validate";
export { onUserDelete } from "./user-cleanup";
