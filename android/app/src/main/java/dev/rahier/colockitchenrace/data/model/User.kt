package dev.rahier.colockitchenrace.data.model

import com.google.firebase.firestore.DocumentId
import java.util.UUID

enum class AuthProvider { EMAIL, GOOGLE, APPLE }

enum class Gender { MALE, FEMALE, OTHER }

data class User(
    val id: String = UUID.randomUUID().toString(),
    val authId: String = "",
    val authProvider: AuthProvider? = null,
    val isAdmin: Boolean = false,
    val isSubscribeToNews: Boolean = false,
    val firstName: String = "",
    val lastName: String = "",
    val phoneNumber: String? = null,
    val email: String? = null,
    val dietaryPreferences: Set<DietaryPreference> = emptySet(),
    val gender: Gender? = null,
    val fcmToken: String? = null,
    val cohouseId: String? = null,
) {
    val fullName: String get() = "$firstName $lastName"

    val isEmailEditable: Boolean get() = authProvider == null || authProvider == AuthProvider.EMAIL

    val needsProfileCompletion: Boolean
        get() = firstName.isBlank() || lastName.isBlank() || phoneNumber.isNullOrBlank()

    fun toCohouseUser(cohouseUserId: String = UUID.randomUUID().toString(), isAdmin: Boolean = false) =
        CohouseUser(id = cohouseUserId, isAdmin = isAdmin, surname = fullName, userId = id)

    companion object {
        val EMPTY = User()
    }
}
