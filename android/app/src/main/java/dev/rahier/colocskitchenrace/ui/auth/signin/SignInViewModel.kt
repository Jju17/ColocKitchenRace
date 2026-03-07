package dev.rahier.colocskitchenrace.ui.auth.signin

import android.app.Activity
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.model.NoAccountException
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
class SignInViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _state = MutableStateFlow(SignInState())
    val state: StateFlow<SignInState> = _state.asStateFlow()

    private val _effect = Channel<SignInEffect>()
    val effect = _effect.receiveAsFlow()

    fun onIntent(intent: SignInIntent) {
        when (intent) {
            is SignInIntent.EmailChanged -> _state.update { it.copy(email = intent.email) }
            is SignInIntent.PasswordChanged -> _state.update { it.copy(password = intent.password) }
            is SignInIntent.SignInClicked -> signIn()
            is SignInIntent.GoogleSignInClicked -> {} // handled via Activity
            is SignInIntent.AppleSignInClicked -> {} // handled via Activity
            is SignInIntent.CreateAccountConfirmed -> createAccount()
            is SignInIntent.CreateAccountDismissed -> _state.update { it.copy(showCreateAccountDialog = false) }
            is SignInIntent.DismissError -> _state.update { it.copy(errorMessage = null) }
        }
    }

    private fun signIn() {
        val email = _state.value.email.trim()
        val password = _state.value.password
        if (email.isEmpty() || password.isEmpty()) {
            _state.update { it.copy(errorMessage = context.getString(R.string.error_fields_required)) }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val user = authRepository.signIn(email, password)
                navigateAfterAuth(user)
            } catch (e: NoAccountException) {
                _state.update { it.copy(isLoading = false, showCreateAccountDialog = true) }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    private fun createAccount() {
        val email = _state.value.email.trim()
        val password = _state.value.password
        _state.update { it.copy(showCreateAccountDialog = false) }

        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                authRepository.createAccount(email, password)
                _effect.send(SignInEffect.NavigateToEmailVerification)
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    fun signInWithGoogle(activity: Activity) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val user = authRepository.signInWithGoogle(activity)
                navigateAfterAuth(user)
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    fun signInWithApple(activity: Activity) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val user = authRepository.signInWithApple(activity)
                navigateAfterAuth(user)
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    private suspend fun navigateAfterAuth(user: dev.rahier.colocskitchenrace.data.model.User) {
        _state.update { it.copy(isLoading = false) }
        when {
            !authRepository.isEmailVerified() -> _effect.send(SignInEffect.NavigateToEmailVerification)
            user.needsProfileCompletion -> _effect.send(SignInEffect.NavigateToProfileCompletion)
            else -> _effect.send(SignInEffect.NavigateToMain)
        }
    }
}
