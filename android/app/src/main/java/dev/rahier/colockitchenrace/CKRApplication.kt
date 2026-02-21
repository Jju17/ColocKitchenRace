package dev.rahier.colockitchenrace

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class CKRApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        subscribeToTopics()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "ckr_default",
            "Colocs Kitchen Race",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Notifications de Colocs Kitchen Race"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun subscribeToTopics() {
        FirebaseMessaging.getInstance().subscribeToTopic("all_users")
    }
}
