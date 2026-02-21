package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.User

interface UserRepository {
    suspend fun getUser(userId: String): User?
    suspend fun getUserByAuthId(authId: String): User?
    suspend fun createUser(user: User)
    suspend fun updateUser(user: User)
    suspend fun deleteUser(userId: String)
    fun storeFCMToken(token: String)
}
