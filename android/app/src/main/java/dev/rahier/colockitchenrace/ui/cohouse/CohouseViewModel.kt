package dev.rahier.colockitchenrace.ui.cohouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CohouseState(
    val cohouse: Cohouse? = null,
    val joinCode: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
)

sealed class CohouseIntent {
    data class JoinCodeChanged(val code: String) : CohouseIntent()
    data object JoinClicked : CohouseIntent()
    data object CreateClicked : CohouseIntent()
    data object QuitClicked : CohouseIntent()
    data object EditClicked : CohouseIntent()
}

@HiltViewModel
class CohouseViewModel @Inject constructor(
    private val cohouseRepository: CohouseRepository,
    private val authRepository: AuthRepository,
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
            CohouseIntent.CreateClicked -> {} // TODO: navigate to create form
            CohouseIntent.QuitClicked -> quitCohouse()
            CohouseIntent.EditClicked -> {} // TODO: navigate to edit form
        }
    }

    private fun observeCohouse() {
        viewModelScope.launch {
            cohouseRepository.currentCohouse.collect { cohouse ->
                _state.update { it.copy(cohouse = cohouse) }
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

                // Update user's cohouseId
                val user = authRepository.currentUser.value
                if (user != null) {
                    authRepository.updateUser(user.copy(cohouseId = cohouse.id))
                }

                _state.update { it.copy(isLoading = false, cohouse = cohouse) }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = "Code invalide ou coloc introuvable") }
            }
        }
    }

    private fun quitCohouse() {
        viewModelScope.launch {
            try {
                cohouseRepository.quitCohouse()
                val user = authRepository.currentUser.value
                if (user != null) {
                    authRepository.updateUser(user.copy(cohouseId = null))
                }
            } catch (_: Exception) {}
        }
    }
}
