package dev.rahier.colocskitchenrace.ui.profile

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
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
class UserProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
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
        viewModelScope.launch {
            authRepository.signOut()
            _effect.send(UserProfileEffect.SignedOut)
        }
    }

    private fun deleteAccount() {
        val user = _state.value.user ?: return
        viewModelScope.launch {
            _state.update { it.copy(showDeleteConfirmation = false, isLoading = true) }
            try {
                authRepository.deleteAccount(user.id)
                _effect.send(UserProfileEffect.SignedOut)
            } catch (e: Exception) {
                Log.e("UserProfile", "Failed to delete account", e)
                _state.update { it.copy(isLoading = false, error = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }
}
