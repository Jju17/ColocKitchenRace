package dev.rahier.colocskitchenrace.data.repository.impl

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.OAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.data.model.AuthProvider
import dev.rahier.colocskitchenrace.data.model.User
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.util.Constants
import dev.rahier.colocskitchenrace.util.DemoMode
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val auth: FirebaseAuth,
    private val firestore: FirebaseFirestore,
    private val messaging: FirebaseMessaging,
    private val functions: FirebaseFunctions,
    private val cohouseRepository: CohouseRepository,
) : AuthRepository {

    private val _currentUser = MutableStateFlow<User?>(null)
    override val currentUser: StateFlow<User?> = _currentUser.asStateFlow()

    override val isLoggedIn: Flow<Boolean> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser != null)
        }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    override suspend fun signIn(email: String, password: String): User {
        try {
            val result = auth.signInWithEmailAndPassword(email, password).await()
            val firebaseUser = result.user ?: throw Exception("Sign in failed")
            return loadOrCreateProfile(firebaseUser.uid, email, AuthProvider.EMAIL)
        } catch (e: Exception) {
            // Check if user doesn't exist (error codes 17011 or 17004)
            val errorCode = e.message ?: ""
            if (errorCode.contains("no user record") || errorCode.contains("INVALID_LOGIN_CREDENTIALS")) {
                throw NoAccountException(email)
            }
            throw e
        }
    }

    override suspend fun createAccount(email: String, password: String): User {
        val result = auth.createUserWithEmailAndPassword(email, password).await()
        val firebaseUser = result.user ?: throw Exception("Account creation failed")
        firebaseUser.sendEmailVerification().await()

        val user = User(
            id = UUID.randomUUID().toString(),
            authId = firebaseUser.uid,
            authProvider = AuthProvider.EMAIL,
            email = email,
        )
        firestore.collection(Constants.USERS_COLLECTION)
            .document(user.id)
            .set(userToMap(user))
            .await()
        _currentUser.value = user
        return user
    }

    override suspend fun signInWithGoogle(activity: Activity): User {
        val credentialManager = androidx.credentials.CredentialManager.create(activity)
        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(getWebClientId())
            .build()
        val request = androidx.credentials.GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val credentialResponse = credentialManager.getCredential(activity, request)
        val credential = credentialResponse.credential
        val googleIdToken = com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
            .createFrom(credential.data)
        val firebaseCredential = GoogleAuthProvider.getCredential(googleIdToken.idToken, null)
        val result = auth.signInWithCredential(firebaseCredential).await()
        val firebaseUser = result.user ?: throw Exception("Google sign in failed")

        val displayName = firebaseUser.displayName ?: ""
        val parts = displayName.split(" ", limit = 2)
        val firstName = parts.getOrElse(0) { "" }
        val lastName = parts.getOrElse(1) { "" }

        return loadOrCreateProfile(
            authId = firebaseUser.uid,
            email = firebaseUser.email ?: "",
            provider = AuthProvider.GOOGLE,
            firstName = firstName,
            lastName = lastName,
        )
    }

    override suspend fun signInWithApple(activity: Activity): User {
        val provider = OAuthProvider.newBuilder("apple.com")
        provider.setScopes(listOf("email", "name"))
        val result = auth.startActivityForSignInWithProvider(activity, provider.build()).await()
        val firebaseUser = result.user ?: throw Exception("Apple sign in failed")

        val displayName = firebaseUser.displayName ?: ""
        val parts = displayName.split(" ", limit = 2)

        return loadOrCreateProfile(
            authId = firebaseUser.uid,
            email = firebaseUser.email ?: "",
            provider = AuthProvider.APPLE,
            firstName = parts.getOrElse(0) { "" },
            lastName = parts.getOrElse(1) { "" },
        )
    }

    override fun signOut() {
        messaging.unsubscribeFromTopic("all_users")
        auth.signOut()
        _currentUser.value = null
        cohouseRepository.setCurrentCohouse(null)
        DemoMode.deactivate()
    }

    override suspend fun deleteAccount(userId: String) {
        functions.getHttpsCallable("deleteAccount")
            .call(hashMapOf("userId" to userId))
            .await()
        signOut()
    }

    override suspend fun updateUser(user: User) {
        firestore.collection(Constants.USERS_COLLECTION)
            .document(user.id)
            .set(userToMap(user))
            .await()
        _currentUser.value = user
    }

    override suspend fun resendVerificationEmail() {
        auth.currentUser?.sendEmailVerification()?.await()
    }

    override suspend fun reloadCurrentUser(): Boolean {
        auth.currentUser?.reload()?.await()
        return auth.currentUser?.isEmailVerified == true
    }

    override fun isEmailVerified(): Boolean {
        return auth.currentUser?.isEmailVerified == true
    }

    override fun listenAuthState(): Flow<Boolean> = isLoggedIn

    override fun storeFCMToken(token: String) {
        val user = _currentUser.value ?: return
        firestore.collection(Constants.USERS_COLLECTION)
            .document(user.id)
            .update("fcmToken", token)
            .addOnFailureListener { Log.e("AuthRepo", "Failed to store FCM token", it) }
    }

    override suspend fun restoreSession(): User? {
        val firebaseUser = auth.currentUser ?: return null
        val authId = firebaseUser.uid

        // Check demo mode
        val email = firebaseUser.email ?: ""
        if (email == DemoMode.DEMO_EMAIL) {
            DemoMode.activate()
            val demoUser = User(
                id = DemoMode.DEMO_USER_ID,
                authId = authId,
                authProvider = AuthProvider.EMAIL,
                email = email,
                firstName = "Apple",
                lastName = "Reviewer",
                cohouseId = DemoMode.DEMO_COHOUSE_ID,
            )
            _currentUser.value = demoUser
            cohouseRepository.setCurrentCohouse(DemoMode.demoCohouse)
            return demoUser
        }

        // Query Firestore for user profile by authId
        val snapshot = firestore.collection(Constants.USERS_COLLECTION)
            .whereEqualTo("authId", authId)
            .limit(1)
            .get()
            .await()

        if (snapshot.documents.isEmpty()) return null

        val docData = snapshot.documents[0].data ?: return null
        val user = mapToUser(docData, snapshot.documents[0].id)
        _currentUser.value = user

        // Load cohouse if user has one
        if (user.cohouseId != null) {
            try {
                val cohouse = cohouseRepository.get(user.cohouseId)
                cohouseRepository.setCurrentCohouse(cohouse)
            } catch (e: Exception) {
                Log.e("AuthRepo", "Failed to load cohouse during session restore", e)
            }
        }

        // Refresh FCM token
        messaging.token.addOnSuccessListener { token ->
            storeFCMToken(token)
        }

        return user
    }

    // --- Private helpers ---

    private suspend fun loadOrCreateProfile(
        authId: String,
        email: String,
        provider: AuthProvider,
        firstName: String = "",
        lastName: String = "",
    ): User {
        // Activate or deactivate demo mode based on email
        if (email == DemoMode.DEMO_EMAIL) {
            DemoMode.activate()
        } else {
            DemoMode.deactivate()
        }

        // Demo mode: return mock user + cohouse
        if (DemoMode.isActive) {
            val demoUser = User(
                id = DemoMode.DEMO_USER_ID,
                authId = authId,
                authProvider = provider,
                email = email,
                firstName = "Apple",
                lastName = "Reviewer",
                cohouseId = DemoMode.DEMO_COHOUSE_ID,
            )
            _currentUser.value = demoUser
            cohouseRepository.setCurrentCohouse(DemoMode.demoCohouse)
            return demoUser
        }

        // Try to find existing user by authId
        val snapshot = firestore.collection(Constants.USERS_COLLECTION)
            .whereEqualTo("authId", authId)
            .limit(1)
            .get()
            .await()

        val user = if (snapshot.documents.isNotEmpty() && snapshot.documents[0].data != null) {
            mapToUser(snapshot.documents[0].data!!, snapshot.documents[0].id)
        } else {
            val newUser = User(
                id = UUID.randomUUID().toString(),
                authId = authId,
                authProvider = provider,
                email = email,
                firstName = firstName,
                lastName = lastName,
            )
            firestore.collection(Constants.USERS_COLLECTION)
                .document(newUser.id)
                .set(userToMap(newUser))
                .await()
            newUser
        }

        _currentUser.value = user

        // Load cohouse if user has one
        if (user.cohouseId != null) {
            try {
                val cohouse = cohouseRepository.get(user.cohouseId)
                cohouseRepository.setCurrentCohouse(cohouse)
            } catch (e: Exception) {
                Log.e("AuthRepo", "Failed to load cohouse", e)
            }
        }

        // Store FCM token
        messaging.token.addOnSuccessListener { token ->
            storeFCMToken(token)
        }

        return user
    }

    private fun getWebClientId(): String {
        // Read default_web_client_id from strings resource (auto-generated from google-services.json)
        val resId = context.resources.getIdentifier("default_web_client_id", "string", context.packageName)
        if (resId != 0) return context.getString(resId)
        throw IllegalStateException(
            "default_web_client_id not found. Ensure google-services.json is properly configured."
        )
    }

    companion object {
        fun userToMap(user: User): Map<String, Any?> = mapOf(
            "id" to user.id,
            "authId" to user.authId,
            "authProvider" to user.authProvider?.name?.lowercase(),
            "isAdmin" to user.isAdmin,
            "isSubscribeToNews" to user.isSubscribeToNews,
            "firstName" to user.firstName,
            "lastName" to user.lastName,
            "phoneNumber" to user.phoneNumber,
            "email" to user.email,
            "dietaryPreferences" to user.dietaryPreferences.map { it.toFirestore() },
            "gender" to user.gender?.name?.lowercase(),
            "fcmToken" to user.fcmToken,
            "cohouseId" to user.cohouseId,
        )

        fun mapToUser(data: Map<String, Any?>, docId: String): User {
            val prefs = (data["dietaryPreferences"] as? List<*>)
                ?.mapNotNull { dev.rahier.colocskitchenrace.data.model.DietaryPreference.fromFirestore(it.toString()) }
                ?.toSet() ?: emptySet()

            return User(
                id = data["id"] as? String ?: docId,
                authId = data["authId"] as? String ?: "",
                authProvider = (data["authProvider"] as? String)?.let {
                    when (it) {
                        "email" -> AuthProvider.EMAIL
                        "google" -> AuthProvider.GOOGLE
                        "apple" -> AuthProvider.APPLE
                        else -> null
                    }
                },
                isAdmin = data["isAdmin"] as? Boolean ?: false,
                isSubscribeToNews = data["isSubscribeToNews"] as? Boolean ?: false,
                firstName = data["firstName"] as? String ?: "",
                lastName = data["lastName"] as? String ?: "",
                phoneNumber = data["phoneNumber"] as? String,
                email = data["email"] as? String,
                dietaryPreferences = prefs,
                gender = (data["gender"] as? String)?.let {
                    when (it) {
                        "male" -> dev.rahier.colocskitchenrace.data.model.Gender.MALE
                        "female" -> dev.rahier.colocskitchenrace.data.model.Gender.FEMALE
                        "other" -> dev.rahier.colocskitchenrace.data.model.Gender.OTHER
                        else -> null
                    }
                },
                fcmToken = data["fcmToken"] as? String,
                cohouseId = data["cohouseId"] as? String,
            )
        }
    }
}

class NoAccountException(val email: String) : Exception("No account found for $email")
