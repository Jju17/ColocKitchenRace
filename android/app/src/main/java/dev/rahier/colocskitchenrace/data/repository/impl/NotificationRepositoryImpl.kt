package dev.rahier.colocskitchenrace.data.repository.impl

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import dev.rahier.colocskitchenrace.BuildConfig
import dev.rahier.colocskitchenrace.data.repository.NotificationRepository
import dev.rahier.colocskitchenrace.util.Constants
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NotificationRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val messaging: FirebaseMessaging,
    private val auth: FirebaseAuth,
) : NotificationRepository {

    override suspend fun storeFCMToken(token: String) {
        val userId = auth.currentUser?.uid ?: return
        val snapshot = firestore.collection(Constants.USERS_COLLECTION)
            .whereEqualTo("authId", userId)
            .limit(1)
            .get()
            .await()
        val userDoc = snapshot.documents.firstOrNull() ?: return
        userDoc.reference.update("fcmToken", token).await()
    }

    override suspend fun subscribeToAllUsers() {
        messaging.subscribeToTopic(BuildConfig.FCM_TOPIC_ALL_USERS).await()
    }

    override suspend fun unsubscribeFromAllUsers() {
        messaging.unsubscribeFromTopic(BuildConfig.FCM_TOPIC_ALL_USERS).await()
    }
}
