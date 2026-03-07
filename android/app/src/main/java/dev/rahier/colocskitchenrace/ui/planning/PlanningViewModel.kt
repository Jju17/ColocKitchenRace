package dev.rahier.colocskitchenrace.ui.planning

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import dev.rahier.colocskitchenrace.util.ErrorMapper
import javax.inject.Inject

@HiltViewModel
class PlanningViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _state = MutableStateFlow(PlanningState())
    val state: StateFlow<PlanningState> = _state.asStateFlow()

    init {
        loadPlanning()
    }

    fun onIntent(intent: PlanningIntent) {
        when (intent) {
            PlanningIntent.Retry -> loadPlanning()
        }
    }

    private fun loadPlanning() {
        viewModelScope.launch {
            val game = gameRepository.currentGame.value ?: return@launch
            val cohouse = cohouseRepository.currentCohouse.value ?: return@launch

            if (!game.isRevealed || !game.cohouseIDs.contains(cohouse.id)) return@launch

            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val planning = gameRepository.getMyPlanning(game.id, cohouse.id)
                _state.update { it.copy(planning = planning, isLoading = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }
}
