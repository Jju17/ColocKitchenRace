package dev.rahier.colocskitchenrace.util

import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.storage.StorageException
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException

/**
 * Maps exceptions to user-friendly French messages.
 * Prevents leaking implementation details to the UI.
 */
object ErrorMapper {

    @Throws(CancellationException::class)
    fun toUserMessage(e: Exception, fallback: String = "Une erreur s'est produite. Réessayez."): String {
        if (e is CancellationException) throw e
        return when (e) {
            is IOException -> "Erreur de connexion réseau. Vérifiez votre connexion."
            is FirebaseAuthException -> mapAuthError(e)
            is FirebaseFirestoreException -> "Erreur de base de données. Réessayez."
            is FirebaseFunctionsException -> mapFunctionsError(e)
            is StorageException -> mapStorageError(e)
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

    private fun mapFunctionsError(e: FirebaseFunctionsException): String {
        return when (e.code) {
            FirebaseFunctionsException.Code.UNAUTHENTICATED -> "Session expirée. Reconnectez-vous."
            FirebaseFunctionsException.Code.PERMISSION_DENIED -> "Vous n'avez pas les droits nécessaires."
            FirebaseFunctionsException.Code.NOT_FOUND -> "Donnée introuvable."
            FirebaseFunctionsException.Code.ALREADY_EXISTS -> "Cette inscription existe déjà."
            FirebaseFunctionsException.Code.RESOURCE_EXHAUSTED -> "Trop de requêtes. Réessayez plus tard."
            FirebaseFunctionsException.Code.FAILED_PRECONDITION -> e.message ?: "Opération impossible dans l'état actuel."
            FirebaseFunctionsException.Code.UNAVAILABLE -> "Service temporairement indisponible. Réessayez."
            FirebaseFunctionsException.Code.DEADLINE_EXCEEDED -> "Le serveur met trop de temps à répondre. Réessayez."
            FirebaseFunctionsException.Code.INVALID_ARGUMENT -> "Données invalides. Vérifiez votre saisie."
            else -> "Erreur du serveur. Réessayez."
        }
    }

    private fun mapStorageError(e: StorageException): String {
        return when (e.errorCode) {
            StorageException.ERROR_OBJECT_NOT_FOUND -> "Fichier introuvable."
            StorageException.ERROR_QUOTA_EXCEEDED -> "Espace de stockage insuffisant."
            StorageException.ERROR_NOT_AUTHENTICATED -> "Session expirée. Reconnectez-vous."
            StorageException.ERROR_NOT_AUTHORIZED -> "Vous n'avez pas accès à ce fichier."
            StorageException.ERROR_RETRY_LIMIT_EXCEEDED -> "Erreur réseau. Réessayez."
            StorageException.ERROR_CANCELED -> "Opération annulée."
            else -> "Erreur lors du transfert de fichier. Réessayez."
        }
    }
}
