package dev.rahier.colocskitchenrace

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dagger.hilt.android.AndroidEntryPoint
import dev.rahier.colocskitchenrace.data.repository.UserRepository
import dev.rahier.colocskitchenrace.util.Constants
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

        val title = message.notification?.title ?: message.data["title"] ?: return
        val body = message.notification?.body ?: message.data["body"] ?: ""
        val type = message.data["type"]

        showNotification(title, body, type)
    }

    private fun showNotification(title: String, body: String, type: String?) {
        val channelId = Constants.NOTIFICATION_CHANNEL_ID
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Tapping the notification opens the app with deep link info
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            type?.let { putExtra(EXTRA_NOTIFICATION_TYPE, it) }
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().rem(Int.MAX_VALUE).toInt(),
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .build()

        notificationManager.notify(System.currentTimeMillis().rem(Int.MAX_VALUE).toInt(), notification)
    }

    companion object {
        const val EXTRA_NOTIFICATION_TYPE = "notification_type"
    }
}
