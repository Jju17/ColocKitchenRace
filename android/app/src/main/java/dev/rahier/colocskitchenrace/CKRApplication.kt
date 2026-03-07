package dev.rahier.colocskitchenrace

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.util.Log
import dagger.hilt.android.HiltAndroidApp
import dev.rahier.colocskitchenrace.util.Constants

@HiltAndroidApp
class CKRApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        setupUncaughtExceptionHandler()
        createNotificationChannel()
        // Topic subscription should happen after user authentication, not at app startup
    }

    private fun setupUncaughtExceptionHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            Log.e("CKR", "Uncaught exception", throwable)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            Constants.NOTIFICATION_CHANNEL_ID,
            "Colocs Kitchen Race",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications de Colocs Kitchen Race"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
