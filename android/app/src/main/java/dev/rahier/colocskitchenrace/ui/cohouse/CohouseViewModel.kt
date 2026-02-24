package dev.rahier.colocskitchenrace.ui.cohouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CohouseState(
    val cohouse: Cohouse? = null,
    val coverImageData: ByteArray? = null,
    val joinCode: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is CohouseState) return false
        return cohouse == other.cohouse &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            joinCode == other.joinCode &&
            isLoading == other.isLoading &&
            error == other.error
    }

    override fun hashCode(): Int {
        var result = cohouse?.hashCode() ?: 0
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + joinCode.hashCode()
        result = 31 * result + isLoading.hashCode()
        result = 31 * result + (error?.hashCode() ?: 0)
        return result
    }
}

sealed class CohouseIntent {
    data class JoinCodeChanged(val code: String) : CohouseIntent()
    data object JoinClicked : CohouseIntent()
    data object CreateClicked : CohouseIntent()
    data object QuitClicked : CohouseIntent()
    data object EditClicked : CohouseIntent()
    data object Refresh : CohouseIntent()
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
            CohouseIntent.CreateClicked -> {}
            CohouseIntent.QuitClicked -> quitCohouse()
            CohouseIntent.EditClicked -> {}
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
            } catch (_: Exception) {
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
            } catch (_: Exception) {}
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
