package dev.rahier.colockitchenrace.ui.planning

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.CKRMyPlanning
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PlanningState(
    val planning: CKRMyPlanning? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class PlanningViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(PlanningState())
    val state: StateFlow<PlanningState> = _state.asStateFlow()

    init {
        loadPlanning()
    }

    private fun loadPlanning() {
        viewModelScope.launch {
            val game = gameRepository.currentGame.value ?: return@launch
            val cohouse = cohouseRepository.currentCohouse.value ?: return@launch

            if (!game.isRevealed || !game.cohouseIDs.contains(cohouse.id)) return@launch

            _state.update { it.copy(isLoading = true) }
            try {
                val planning = gameRepository.getMyPlanning(game.id, cohouse.id)
                _state.update { it.copy(planning = planning, isLoading = false) }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }
}
