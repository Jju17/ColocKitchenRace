package dev.rahier.colockitchenrace.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.repository.AuthRepository
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

            // Load user profile
            try {
                val user = authRepository.currentUser.value
                    ?: run {
                        // Try to load from Firestore
                        authRepository.signIn(firebaseUser.email ?: "", "")
                        authRepository.currentUser.value
                    }

                if (user?.needsProfileCompletion == true) {
                    _authState.value = AuthState.NEEDS_PROFILE_COMPLETION
                } else {
                    _authState.value = AuthState.AUTHENTICATED
                }
            } catch (_: Exception) {
                _authState.value = AuthState.AUTHENTICATED
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
