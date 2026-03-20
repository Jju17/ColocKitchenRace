package dev.rahier.colocskitchenrace.data.model

object UserMapper {
    fun fromFirestore(data: Map<String, Any?>, docId: String): User {
        val prefs = (data["dietaryPreferences"] as? List<*>)
            ?.mapNotNull { DietaryPreference.fromFirestore(it.toString()) }
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
            fcmToken = data["fcmToken"] as? String,
            cohouseId = data["cohouseId"] as? String,
        )
    }

    fun toFirestore(user: User): Map<String, Any?> = mapOf(
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
        "fcmToken" to user.fcmToken,
        "cohouseId" to user.cohouseId,
    )
}
