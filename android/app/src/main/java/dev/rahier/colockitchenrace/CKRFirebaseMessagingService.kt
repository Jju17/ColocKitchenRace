package dev.rahier.colockitchenrace

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dagger.hilt.android.AndroidEntryPoint
import dev.rahier.colockitchenrace.data.repository.UserRepository
import javax.inject.Inject

@AndroidEntryPoint
class CKRFirebaseMessagingService : FirebaseMessagingService() {

    @Inject
    lateinit var userRepository: UserRepository

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        userRepository.storeFCMToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        // Default notification handling is done by the system
    }
}
