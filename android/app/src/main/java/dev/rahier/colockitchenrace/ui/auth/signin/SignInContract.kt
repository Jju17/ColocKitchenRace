package dev.rahier.colockitchenrace.ui.auth.signin

data class SignInState(
    val email: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val showCreateAccountDialog: Boolean = false,
)

sealed class SignInIntent {
    data class EmailChanged(val email: String) : SignInIntent()
    data class PasswordChanged(val password: String) : SignInIntent()
    data object SignInClicked : SignInIntent()
    data object GoogleSignInClicked : SignInIntent()
    data object AppleSignInClicked : SignInIntent()
    data object CreateAccountConfirmed : SignInIntent()
    data object CreateAccountDismissed : SignInIntent()
    data object DismissError : SignInIntent()
}

sealed class SignInEffect {
    data object NavigateToEmailVerification : SignInEffect()
    data object NavigateToProfileCompletion : SignInEffect()
    data object NavigateToMain : SignInEffect()
}
