package dev.rahier.colocskitchenrace.ui.auth.emailverification

data class EmailVerificationState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

sealed interface EmailVerificationIntent {
    data object CheckVerification : EmailVerificationIntent
    data object ResendEmail : EmailVerificationIntent
    data object SignOut : EmailVerificationIntent
}

sealed interface EmailVerificationEffect {
    data object NavigateToProfileCompletion : EmailVerificationEffect
    data object NavigateToMain : EmailVerificationEffect
    data object NavigateToSignIn : EmailVerificationEffect
}
