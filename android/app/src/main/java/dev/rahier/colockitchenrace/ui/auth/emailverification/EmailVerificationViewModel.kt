package dev.rahier.colockitchenrace.ui.auth.emailverification

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

data class EmailVerificationState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

sealed class EmailVerificationIntent {
    data object CheckVerification : EmailVerificationIntent()
    data object ResendEmail : EmailVerificationIntent()
    data object SignOut : EmailVerificationIntent()
}

sealed class EmailVerificationEffect {
    data object NavigateToProfileCompletion : EmailVerificationEffect()
    data object NavigateToMain : EmailVerificationEffect()
    data object NavigateToSignIn : EmailVerificationEffect()
}

@HiltViewModel
class EmailVerificationViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(EmailVerificationState())
    val state: StateFlow<EmailVerificationState> = _state.asStateFlow()

    private val _effect = Channel<EmailVerificationEffect>()
    val effect = _effect.receiveAsFlow()

    fun onIntent(intent: EmailVerificationIntent) {
        when (intent) {
            EmailVerificationIntent.CheckVerification -> checkVerification()
            EmailVerificationIntent.ResendEmail -> resendEmail()
            EmailVerificationIntent.SignOut -> signOut()
        }
    }

    private fun checkVerification() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val verified = authRepository.reloadCurrentUser()
                if (verified) {
                    val user = authRepository.currentUser.value
                    if (user?.needsProfileCompletion == true) {
                        _effect.send(EmailVerificationEffect.NavigateToProfileCompletion)
                    } else {
                        _effect.send(EmailVerificationEffect.NavigateToMain)
                    }
                } else {
                    _state.update { it.copy(isLoading = false, errorMessage = "Email pas encore verifie") }
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = e.message) }
            }
        }
    }

    private fun resendEmail() {
        viewModelScope.launch {
            try {
                authRepository.resendVerificationEmail()
            } catch (_: Exception) {}
        }
    }

    private fun signOut() {
        authRepository.signOut()
        viewModelScope.launch { _effect.send(EmailVerificationEffect.NavigateToSignIn) }
    }
}
