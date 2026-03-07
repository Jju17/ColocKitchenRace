package dev.rahier.colocskitchenrace.ui.profile

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.DietaryPreference
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class UserProfileFormViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
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
                _state.update { it.copy(isSaving = false, error = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }
}
