package dev.rahier.colocskitchenrace.ui.cohouse

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CohouseViewModel @Inject constructor(
    private val cohouseRepository: CohouseRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _state = MutableStateFlow(CohouseState())
    val state: StateFlow<CohouseState> = _state.asStateFlow()

    init {
        observeCohouse()
    }

    fun onIntent(intent: CohouseIntent) {
        when (intent) {
            is CohouseIntent.JoinCodeChanged -> _state.update { it.copy(joinCode = intent.code) }
            CohouseIntent.JoinClicked -> joinByCode()
            CohouseIntent.QuitClicked -> quitCohouse()
            CohouseIntent.Refresh -> refresh()
        }
    }

    private fun observeCohouse() {
        viewModelScope.launch {
            cohouseRepository.currentCohouse.collect { cohouse ->
                _state.update { it.copy(cohouse = cohouse) }
                loadCoverImage(cohouse)
            }
        }
    }

    private fun loadCoverImage(cohouse: Cohouse?) {
        val path = cohouse?.coverImagePath ?: run {
            _state.update { it.copy(coverImageData = null) }
            return
        }
        viewModelScope.launch {
            try {
                val data = cohouseRepository.loadCoverImage(path)
                _state.update { it.copy(coverImageData = data) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Cohouse", "Failed to load cover image", e)
                _state.update { it.copy(coverImageData = null) }
            }
        }
    }

    private fun refresh() {
        val cohouse = _state.value.cohouse ?: return
        viewModelScope.launch {
            try {
                val refreshed = cohouseRepository.get(cohouse.id)
                cohouseRepository.setCurrentCohouse(refreshed)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Cohouse", "Failed to refresh cohouse", e)
            }
        }
    }

    private fun joinByCode() {
        val code = _state.value.joinCode.trim()
        if (code.isBlank()) return

        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val cohouse = cohouseRepository.getByCode(code)
                cohouseRepository.setCurrentCohouse(cohouse)

                val user = authRepository.currentUser.value
                if (user != null) {
                    authRepository.updateUser(user.copy(cohouseId = cohouse.id))
                    // Add the user to the cohouse's users subcollection
                    val cohouseUser = user.toCohouseUser()
                    cohouseRepository.setUser(cohouseUser, cohouse.id)
                }

                _state.update { it.copy(isLoading = false, cohouse = cohouse) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    private fun quitCohouse() {
        viewModelScope.launch {
            try {
                val user = authRepository.currentUser.value
                val cohouse = _state.value.cohouse
                cohouseRepository.quitCohouse()
                if (user != null) {
                    // Remove CohouseUser from cohouse subcollection (like iOS)
                    if (cohouse != null) {
                        val cohouseUser = cohouse.users.find { it.userId == user.id }
                        if (cohouseUser != null) {
                            cohouseRepository.removeUser(cohouseUser.id, cohouse.id)
                        }
                    }
                    // Clear cohouseId on user doc
                    authRepository.updateUser(user.copy(cohouseId = null))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e("Cohouse", "Failed to quit cohouse", e)
                _state.update { it.copy(error = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }
}
