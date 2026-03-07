package dev.rahier.colocskitchenrace.util

import dev.rahier.colocskitchenrace.BuildConfig

object Constants {
    const val FIREBASE_REGION = "europe-west1"
    val STRIPE_PUBLISHABLE_KEY: String = BuildConfig.STRIPE_PUBLISHABLE_KEY

    // Firestore collection names
    const val USERS_COLLECTION = "users"
    const val COHOUSES_COLLECTION = "cohouses"
    const val CKR_GAMES_COLLECTION = "ckrGames"
    const val CHALLENGES_COLLECTION = "challenges"
    const val NEWS_COLLECTION = "news"
    const val REGISTRATIONS_SUBCOLLECTION = "registrations"
    const val RESPONSES_SUBCOLLECTION = "responses"

    // Notification
    const val NOTIFICATION_CHANNEL_ID = "ckr_notifications"
}
