package dev.rahier.colocskitchenrace.ui.profile

import dev.rahier.colocskitchenrace.data.model.User

data class UserProfileState(
    val user: User? = null,
    val showDeleteConfirmation: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null,
)

sealed interface UserProfileIntent {
    data object SignOutClicked : UserProfileIntent
    data object DeleteAccountClicked : UserProfileIntent
    data object ConfirmDelete : UserProfileIntent
    data object DismissDeleteDialog : UserProfileIntent
}

sealed interface UserProfileEffect {
    data object SignedOut : UserProfileEffect
}
