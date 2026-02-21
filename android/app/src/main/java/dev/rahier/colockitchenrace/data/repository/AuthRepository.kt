package dev.rahier.colockitchenrace.data.repository

import android.app.Activity
import dev.rahier.colockitchenrace.data.model.User
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface AuthRepository {
    val currentUser: StateFlow<User?>
    val isLoggedIn: Flow<Boolean>

    suspend fun signIn(email: String, password: String): User
    suspend fun createAccount(email: String, password: String): User
    suspend fun signInWithGoogle(activity: Activity): User
    suspend fun signInWithApple(activity: Activity): User
    fun signOut()
    suspend fun deleteAccount(userId: String)
    suspend fun updateUser(user: User)
    suspend fun resendVerificationEmail()
    suspend fun reloadCurrentUser(): Boolean
    fun isEmailVerified(): Boolean
    fun listenAuthState(): Flow<Boolean>
    fun storeFCMToken(token: String)
}
