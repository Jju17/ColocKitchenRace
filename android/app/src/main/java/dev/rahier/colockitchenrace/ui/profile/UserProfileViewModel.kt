package dev.rahier.colockitchenrace.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class UserProfileState(
    val user: User? = null,
    val showDeleteConfirmation: Boolean = false,
    val isLoading: Boolean = false,
)

sealed class UserProfileIntent {
    data object SignOutClicked : UserProfileIntent()
    data object DeleteAccountClicked : UserProfileIntent()
    data object ConfirmDelete : UserProfileIntent()
    data object DismissDeleteDialog : UserProfileIntent()
}

sealed class UserProfileEffect {
    data object SignedOut : UserProfileEffect()
}

@HiltViewModel
class UserProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(UserProfileState())
    val state: StateFlow<UserProfileState> = _state.asStateFlow()

    private val _effect = Channel<UserProfileEffect>()
    val effect = _effect.receiveAsFlow()

    init {
        viewModelScope.launch {
            authRepository.currentUser.collect { user ->
                _state.update { it.copy(user = user) }
            }
        }
    }

    fun onIntent(intent: UserProfileIntent) {
        when (intent) {
            UserProfileIntent.SignOutClicked -> signOut()
            UserProfileIntent.DeleteAccountClicked -> _state.update { it.copy(showDeleteConfirmation = true) }
            UserProfileIntent.ConfirmDelete -> deleteAccount()
            UserProfileIntent.DismissDeleteDialog -> _state.update { it.copy(showDeleteConfirmation = false) }
        }
    }

    private fun signOut() {
        authRepository.signOut()
        viewModelScope.launch { _effect.send(UserProfileEffect.SignedOut) }
    }

    private fun deleteAccount() {
        val user = _state.value.user ?: return
        viewModelScope.launch {
            _state.update { it.copy(showDeleteConfirmation = false, isLoading = true) }
            try {
                authRepository.deleteAccount(user.id)
                _effect.send(UserProfileEffect.SignedOut)
            } catch (_: Exception) {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }
}
