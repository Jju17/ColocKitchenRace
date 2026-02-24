// Barrel re-exports — Firebase discovers Cloud Functions via these exports.

export { sendNotificationToCohouse, sendNotificationToEdition, sendNotificationToAll } from "./notifications";
export { checkDuplicateCohouse, validateAddress, getCohousesForMap } from "./cohouse";
export { reserveAndCreatePayment } from "./payment";
export { confirmRegistration } from "./registration";
export { releaseExpiredReservation } from "./cleanup";
export { matchCohouses } from "./match-cohouses";
export { updateEventSettings, confirmMatching, revealPlanning, getMyPlanning } from "./planning";
export { setAdminClaim } from "./admin";
export { deleteAccount } from "./account";
export { onNewsCreated, onChallengeCreated, checkChallengeSchedules } from "./triggers";
