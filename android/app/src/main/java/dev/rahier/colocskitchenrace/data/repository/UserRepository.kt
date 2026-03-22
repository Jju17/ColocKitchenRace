package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.User

interface UserRepository {
    suspend fun getUser(userId: String): User?
    suspend fun getUserByAuthId(authId: String): User?
    suspend fun createUser(user: User)
    suspend fun updateUser(user: User)
    suspend fun deleteUser(userId: String)
    fun storeFCMToken(token: String)
    /** Update the user's activeEditionId in Firestore. Pass null to clear. */
    suspend fun updateActiveEditionId(editionId: String?)
}
