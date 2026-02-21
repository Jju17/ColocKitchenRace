package dev.rahier.colockitchenrace.data.repository.impl

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.UserRepository
import dev.rahier.colockitchenrace.util.Constants
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UserRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth,
) : UserRepository {

    override suspend fun getUser(userId: String): User? {
        val doc = firestore.collection(Constants.USERS_COLLECTION)
            .document(userId)
            .get()
            .await()
        return doc.data?.let { AuthRepositoryImpl.mapToUser(it, doc.id) }
    }

    override suspend fun getUserByAuthId(authId: String): User? {
        val snapshot = firestore.collection(Constants.USERS_COLLECTION)
            .whereEqualTo("authId", authId)
            .limit(1)
            .get()
            .await()
        if (snapshot.documents.isEmpty()) return null
        val doc = snapshot.documents[0]
        return AuthRepositoryImpl.mapToUser(doc.data!!, doc.id)
    }

    override suspend fun createUser(user: User) {
        firestore.collection(Constants.USERS_COLLECTION)
            .document(user.id)
            .set(AuthRepositoryImpl.userToMap(user))
            .await()
    }

    override suspend fun updateUser(user: User) {
        firestore.collection(Constants.USERS_COLLECTION)
            .document(user.id)
            .set(AuthRepositoryImpl.userToMap(user))
            .await()
    }

    override suspend fun deleteUser(userId: String) {
        firestore.collection(Constants.USERS_COLLECTION)
            .document(userId)
            .delete()
            .await()
    }

    override fun storeFCMToken(token: String) {
        val uid = auth.currentUser?.uid ?: return
        firestore.collection(Constants.USERS_COLLECTION)
            .whereEqualTo("authId", uid)
            .limit(1)
            .get()
            .addOnSuccessListener { snapshot ->
                snapshot.documents.firstOrNull()?.reference?.update("fcmToken", token)
            }
            .addOnFailureListener { Log.e("UserRepo", "Failed to store FCM token", it) }
    }
}
