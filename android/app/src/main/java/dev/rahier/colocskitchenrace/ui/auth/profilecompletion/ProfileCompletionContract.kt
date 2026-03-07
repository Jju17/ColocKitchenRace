package dev.rahier.colocskitchenrace.ui.auth.profilecompletion

data class ProfileCompletionState(
    val firstName: String = "",
    val lastName: String = "",
    val phoneNumber: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

sealed interface ProfileCompletionIntent {
    data class FirstNameChanged(val value: String) : ProfileCompletionIntent
    data class LastNameChanged(val value: String) : ProfileCompletionIntent
    data class PhoneChanged(val value: String) : ProfileCompletionIntent
    data object SaveClicked : ProfileCompletionIntent
}

sealed interface ProfileCompletionEffect {
    data object NavigateToMain : ProfileCompletionEffect
}
