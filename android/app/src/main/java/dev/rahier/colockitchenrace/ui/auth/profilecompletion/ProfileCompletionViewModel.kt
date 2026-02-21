package dev.rahier.colockitchenrace.ui.auth.profilecompletion

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileCompletionState(
    val firstName: String = "",
    val lastName: String = "",
    val phoneNumber: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

sealed class ProfileCompletionIntent {
    data class FirstNameChanged(val value: String) : ProfileCompletionIntent()
    data class LastNameChanged(val value: String) : ProfileCompletionIntent()
    data class PhoneChanged(val value: String) : ProfileCompletionIntent()
    data object SaveClicked : ProfileCompletionIntent()
}

sealed class ProfileCompletionEffect {
    data object NavigateToMain : ProfileCompletionEffect()
}

@HiltViewModel
class ProfileCompletionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileCompletionState())
    val state: StateFlow<ProfileCompletionState> = _state.asStateFlow()

    private val _effect = Channel<ProfileCompletionEffect>()
    val effect = _effect.receiveAsFlow()

    init {
        val user = authRepository.currentUser.value
        if (user != null) {
            _state.update {
                it.copy(
                    firstName = user.firstName,
                    lastName = user.lastName,
                    phoneNumber = user.phoneNumber ?: "",
                )
            }
        }
    }

    fun onIntent(intent: ProfileCompletionIntent) {
        when (intent) {
            is ProfileCompletionIntent.FirstNameChanged -> _state.update { it.copy(firstName = intent.value) }
            is ProfileCompletionIntent.LastNameChanged -> _state.update { it.copy(lastName = intent.value) }
            is ProfileCompletionIntent.PhoneChanged -> _state.update { it.copy(phoneNumber = intent.value) }
            ProfileCompletionIntent.SaveClicked -> save()
        }
    }

    private fun save() {
        val user = authRepository.currentUser.value ?: return
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val updatedUser = user.copy(
                    firstName = _state.value.firstName.trim(),
                    lastName = _state.value.lastName.trim(),
                    phoneNumber = _state.value.phoneNumber.trim(),
                )
                authRepository.updateUser(updatedUser)
                _effect.send(ProfileCompletionEffect.NavigateToMain)
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = e.message) }
            }
        }
    }
}
