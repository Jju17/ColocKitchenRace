package dev.rahier.colocskitchenrace.util

import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.firestore.FirebaseFirestoreException
import java.io.IOException

/**
 * Maps exceptions to user-friendly French messages.
 * Prevents leaking implementation details to the UI.
 */
object ErrorMapper {

    fun toUserMessage(e: Exception, fallback: String = "Une erreur s'est produite. Réessayez."): String {
        return when (e) {
            is IOException -> "Erreur de connexion réseau. Vérifiez votre connexion."
            is FirebaseAuthException -> mapAuthError(e)
            is FirebaseFirestoreException -> "Erreur de base de données. Réessayez."
            else -> fallback
        }
    }

    private fun mapAuthError(e: FirebaseAuthException): String {
        return when (e.errorCode) {
            "ERROR_INVALID_EMAIL" -> "Adresse email invalide."
            "ERROR_WRONG_PASSWORD" -> "Mot de passe incorrect."
            "ERROR_USER_NOT_FOUND" -> "Aucun compte trouvé avec cette adresse."
            "ERROR_USER_DISABLED" -> "Ce compte a été désactivé."
            "ERROR_TOO_MANY_REQUESTS" -> "Trop de tentatives. Réessayez plus tard."
            "ERROR_EMAIL_ALREADY_IN_USE" -> "Cette adresse email est déjà utilisée."
            "ERROR_WEAK_PASSWORD" -> "Le mot de passe est trop faible."
            else -> "Erreur d'authentification. Réessayez."
        }
    }
}
