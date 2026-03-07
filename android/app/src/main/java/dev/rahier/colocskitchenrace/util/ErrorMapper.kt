package dev.rahier.colocskitchenrace.util

import android.content.Context
import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.storage.StorageException
import dev.rahier.colocskitchenrace.R
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException

/**
 * Maps exceptions to user-friendly localized messages.
 * Prevents leaking implementation details to the UI.
 */
object ErrorMapper {

    @Throws(CancellationException::class)
    fun toUserMessage(e: Exception, context: Context): String {
        if (e is CancellationException) throw e
        return when (e) {
            is IOException -> context.getString(R.string.error_network)
            is FirebaseAuthException -> mapAuthError(e, context)
            is FirebaseFirestoreException -> context.getString(R.string.error_database)
            is FirebaseFunctionsException -> mapFunctionsError(e, context)
            is StorageException -> mapStorageError(e, context)
            else -> context.getString(R.string.error_generic_retry)
        }
    }

    private fun mapAuthError(e: FirebaseAuthException, context: Context): String {
        return when (e.errorCode) {
            "ERROR_INVALID_EMAIL" -> context.getString(R.string.error_auth_invalid_email)
            "ERROR_WRONG_PASSWORD" -> context.getString(R.string.error_auth_wrong_password)
            "ERROR_USER_NOT_FOUND" -> context.getString(R.string.error_auth_user_not_found)
            "ERROR_USER_DISABLED" -> context.getString(R.string.error_auth_user_disabled)
            "ERROR_TOO_MANY_REQUESTS" -> context.getString(R.string.error_auth_too_many_requests)
            "ERROR_EMAIL_ALREADY_IN_USE" -> context.getString(R.string.error_auth_email_in_use)
            "ERROR_WEAK_PASSWORD" -> context.getString(R.string.error_auth_weak_password)
            else -> context.getString(R.string.error_auth_generic)
        }
    }

    private fun mapFunctionsError(e: FirebaseFunctionsException, context: Context): String {
        return when (e.code) {
            FirebaseFunctionsException.Code.UNAUTHENTICATED -> context.getString(R.string.error_functions_unauthenticated)
            FirebaseFunctionsException.Code.PERMISSION_DENIED -> context.getString(R.string.error_functions_permission_denied)
            FirebaseFunctionsException.Code.NOT_FOUND -> context.getString(R.string.error_functions_not_found)
            FirebaseFunctionsException.Code.ALREADY_EXISTS -> context.getString(R.string.error_functions_already_exists)
            FirebaseFunctionsException.Code.RESOURCE_EXHAUSTED -> context.getString(R.string.error_functions_resource_exhausted)
            FirebaseFunctionsException.Code.FAILED_PRECONDITION -> e.message ?: context.getString(R.string.error_functions_failed_precondition)
            FirebaseFunctionsException.Code.UNAVAILABLE -> context.getString(R.string.error_functions_unavailable)
            FirebaseFunctionsException.Code.DEADLINE_EXCEEDED -> context.getString(R.string.error_functions_deadline_exceeded)
            FirebaseFunctionsException.Code.INVALID_ARGUMENT -> context.getString(R.string.error_functions_invalid_argument)
            else -> context.getString(R.string.error_functions_generic)
        }
    }

    private fun mapStorageError(e: StorageException, context: Context): String {
        return when (e.errorCode) {
            StorageException.ERROR_OBJECT_NOT_FOUND -> context.getString(R.string.error_storage_not_found)
            StorageException.ERROR_QUOTA_EXCEEDED -> context.getString(R.string.error_storage_quota_exceeded)
            StorageException.ERROR_NOT_AUTHENTICATED -> context.getString(R.string.error_storage_not_authenticated)
            StorageException.ERROR_NOT_AUTHORIZED -> context.getString(R.string.error_storage_not_authorized)
            StorageException.ERROR_RETRY_LIMIT_EXCEEDED -> context.getString(R.string.error_storage_retry_limit)
            StorageException.ERROR_CANCELED -> context.getString(R.string.error_storage_canceled)
            else -> context.getString(R.string.error_storage_generic)
        }
    }
}
