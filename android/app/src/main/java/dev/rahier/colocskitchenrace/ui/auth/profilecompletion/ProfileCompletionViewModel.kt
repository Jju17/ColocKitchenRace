package dev.rahier.colocskitchenrace.ui.auth.profilecompletion

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import dev.rahier.colocskitchenrace.util.ErrorMapper
import javax.inject.Inject

@HiltViewModel
class ProfileCompletionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
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
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }
}
