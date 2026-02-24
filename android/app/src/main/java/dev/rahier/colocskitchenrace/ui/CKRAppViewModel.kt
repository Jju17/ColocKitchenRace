package dev.rahier.colocskitchenrace.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class AuthState {
    LOADING,
    UNAUTHENTICATED,
    NEEDS_EMAIL_VERIFICATION,
    NEEDS_PROFILE_COMPLETION,
    AUTHENTICATED,
}

@HiltViewModel
class CKRAppViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val firebaseAuth: FirebaseAuth,
) : ViewModel() {

    private val _authState = MutableStateFlow(AuthState.LOADING)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    init {
        checkAuthState()
        observeAuthState()
    }

    private fun checkAuthState() {
        viewModelScope.launch {
            val firebaseUser = firebaseAuth.currentUser
            if (firebaseUser == null) {
                _authState.value = AuthState.UNAUTHENTICATED
                return@launch
            }

            // Reload to get fresh email verification status
            try {
                firebaseUser.reload()
            } catch (_: Exception) {}

            if (!firebaseUser.isEmailVerified) {
                _authState.value = AuthState.NEEDS_EMAIL_VERIFICATION
                return@launch
            }

            // Load user profile from Firestore using persisted Firebase auth
            try {
                val user = authRepository.currentUser.value
                    ?: authRepository.restoreSession()

                if (user == null) {
                    _authState.value = AuthState.UNAUTHENTICATED
                } else if (user.needsProfileCompletion) {
                    _authState.value = AuthState.NEEDS_PROFILE_COMPLETION
                } else {
                    _authState.value = AuthState.AUTHENTICATED
                }
            } catch (_: Exception) {
                _authState.value = AuthState.UNAUTHENTICATED
            }
        }
    }

    private fun observeAuthState() {
        viewModelScope.launch {
            authRepository.listenAuthState().collect { isLoggedIn ->
                if (!isLoggedIn) {
                    _authState.value = AuthState.UNAUTHENTICATED
                }
            }
        }
    }
}
