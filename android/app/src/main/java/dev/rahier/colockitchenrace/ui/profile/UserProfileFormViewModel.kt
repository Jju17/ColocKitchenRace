package dev.rahier.colockitchenrace.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.DietaryPreference
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

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

sealed class UserProfileFormIntent {
    data class FirstNameChanged(val value: String) : UserProfileFormIntent()
    data class LastNameChanged(val value: String) : UserProfileFormIntent()
    data class EmailChanged(val value: String) : UserProfileFormIntent()
    data class PhoneChanged(val value: String) : UserProfileFormIntent()
    data class ToggleDietaryPreference(val preference: DietaryPreference) : UserProfileFormIntent()
    data class SubscribeToNewsChanged(val value: Boolean) : UserProfileFormIntent()
    data object Save : UserProfileFormIntent()
}

sealed class UserProfileFormEffect {
    data object Saved : UserProfileFormEffect()
}

@HiltViewModel
class UserProfileFormViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(UserProfileFormState())
    val state: StateFlow<UserProfileFormState> = _state.asStateFlow()

    private val _effect = Channel<UserProfileFormEffect>()
    val effect = _effect.receiveAsFlow()

    init {
        loadUser()
    }

    private fun loadUser() {
        val user = authRepository.currentUser.value ?: return
        _state.update {
            it.copy(
                firstName = user.firstName,
                lastName = user.lastName,
                email = user.email ?: "",
                phoneNumber = user.phoneNumber ?: "",
                isEmailEditable = user.isEmailEditable,
                dietaryPreferences = user.dietaryPreferences,
                isSubscribeToNews = user.isSubscribeToNews,
            )
        }
    }

    fun onIntent(intent: UserProfileFormIntent) {
        when (intent) {
            is UserProfileFormIntent.FirstNameChanged -> _state.update { it.copy(firstName = intent.value) }
            is UserProfileFormIntent.LastNameChanged -> _state.update { it.copy(lastName = intent.value) }
            is UserProfileFormIntent.EmailChanged -> _state.update { it.copy(email = intent.value) }
            is UserProfileFormIntent.PhoneChanged -> _state.update { it.copy(phoneNumber = intent.value) }
            is UserProfileFormIntent.ToggleDietaryPreference -> togglePreference(intent.preference)
            is UserProfileFormIntent.SubscribeToNewsChanged -> _state.update { it.copy(isSubscribeToNews = intent.value) }
            UserProfileFormIntent.Save -> save()
        }
    }

    private fun togglePreference(pref: DietaryPreference) {
        _state.update {
            val newPrefs = it.dietaryPreferences.toMutableSet()
            if (pref in newPrefs) newPrefs.remove(pref) else newPrefs.add(pref)
            it.copy(dietaryPreferences = newPrefs)
        }
    }

    private fun save() {
        val s = _state.value
        if (!s.canSave) return

        val user = authRepository.currentUser.value ?: return

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, error = null) }
            try {
                val updated = user.copy(
                    firstName = s.firstName,
                    lastName = s.lastName,
                    email = s.email.ifBlank { null },
                    phoneNumber = s.phoneNumber.ifBlank { null },
                    dietaryPreferences = s.dietaryPreferences,
                    isSubscribeToNews = s.isSubscribeToNews,
                )
                authRepository.updateUser(updated)
                _state.update { it.copy(isSaving = false) }
                _effect.send(UserProfileFormEffect.Saved)
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, error = e.message ?: "Erreur lors de la sauvegarde") }
            }
        }
    }
}
