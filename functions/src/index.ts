// Barrel re-exports — Firebase discovers Cloud Functions via these exports.

export { sendNotificationToCohouse, sendNotificationToEdition, sendNotificationToAll } from "./notifications";
export { checkDuplicateCohouse, validateAddress, getCohousesForMap } from "./cohouse";
export { createPaymentIntent } from "./payment";
export { registerForGame } from "./registration";
export { matchCohouses } from "./match-cohouses";
export { updateEventSettings, confirmMatching, revealPlanning, getMyPlanning } from "./planning";
export { setAdminClaim } from "./admin";
export { onNewsCreated, onChallengeCreated, checkChallengeSchedules } from "./triggers";
