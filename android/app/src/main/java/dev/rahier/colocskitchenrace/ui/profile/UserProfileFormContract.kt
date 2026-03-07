package dev.rahier.colocskitchenrace.ui.profile

import dev.rahier.colocskitchenrace.data.model.DietaryPreference

data class UserProfileFormState(
    val firstName: String = "",
    val lastName: String = "",
    val email: String = "",
    val phoneNumber: String = "",
    val isEmailEditable: Boolean = true,
    val dietaryPreferences: Set<DietaryPreference> = emptySet(),
    val isSubscribeToNews: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null,
) {
    val canSave: Boolean
        get() = firstName.isNotBlank() && lastName.isNotBlank()
}

sealed interface UserProfileFormIntent {
    data class FirstNameChanged(val value: String) : UserProfileFormIntent
    data class LastNameChanged(val value: String) : UserProfileFormIntent
    data class EmailChanged(val value: String) : UserProfileFormIntent
    data class PhoneChanged(val value: String) : UserProfileFormIntent
    data class ToggleDietaryPreference(val preference: DietaryPreference) : UserProfileFormIntent
    data class SubscribeToNewsChanged(val value: Boolean) : UserProfileFormIntent
    data object Save : UserProfileFormIntent
}

sealed interface UserProfileFormEffect {
    data object Saved : UserProfileFormEffect
}
