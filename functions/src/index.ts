// Barrel re-exports — Firebase discovers Cloud Functions via these exports.

export { sendNotificationToCohouse, sendNotificationToEdition, sendNotificationToAll } from "./notifications";
export { checkDuplicateCohouse, validateAddress, getCohousesForMap, setCohouseClaim } from "./cohouse";
export { reserveAndCreatePayment } from "./payment";
export { confirmRegistration } from "./registration";
export { releaseExpiredReservation, cancelReservation, deleteCKRGame } from "./cleanup";
export { matchCohouses } from "./match-cohouses";
export { updateEventSettings, confirmMatching, revealPlanning, getMyPlanning } from "./planning";
export { setAdminClaim } from "./admin";
export { deleteAccount } from "./account";
export { migrateToMultiEdition } from "./migration";
export {
  createSpecialEdition,
  saveDraftEdition,
  publishEdition,
  joinEditionByCode,
  leaveEdition,
} from "./edition";
export { onNewsCreated, onChallengeCreated, onEditionChallengeCreated, checkChallengeSchedules } from "./triggers";
export {
  onCKRGameCreated,
  sendGameReminder24h,
  sendGameReminder1h,
  sendAperoReminder,
  sendDinerReminder,
  sendPartyReminder,
} from "./pushNotifications";
