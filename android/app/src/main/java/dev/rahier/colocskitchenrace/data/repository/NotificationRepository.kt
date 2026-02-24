package dev.rahier.colocskitchenrace.data.repository

interface NotificationRepository {
    suspend fun storeFCMToken(token: String)
    suspend fun subscribeToAllUsers()
    suspend fun unsubscribeFromAllUsers()
}
