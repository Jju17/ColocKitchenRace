package dev.rahier.colocskitchenrace.ui.auth.emailverification

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import android.util.Log
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlin.coroutines.cancellation.CancellationException
import javax.inject.Inject

@HiltViewModel
class EmailVerificationViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
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
                    _state.update { it.copy(isLoading = false, errorMessage = context.getString(R.string.error_email_not_verified)) }
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    private fun resendEmail() {
        viewModelScope.launch {
            try {
                authRepository.resendVerificationEmail()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("EmailVerification", "Failed to resend verification email", e)
            }
        }
    }

    private fun signOut() {
        viewModelScope.launch {
            authRepository.signOut()
            _effect.send(EmailVerificationEffect.NavigateToSignIn)
        }
    }
}
