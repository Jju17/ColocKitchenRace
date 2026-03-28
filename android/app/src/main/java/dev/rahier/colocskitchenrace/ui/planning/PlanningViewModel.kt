package dev.rahier.colocskitchenrace.ui.planning

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
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
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _state = MutableStateFlow(PlanningState())
    val state: StateFlow<PlanningState> = _state.asStateFlow()
    private var lastActiveEditionId: String? = null

    init {
        observeGameAndLoad()
        observeEditionChanges()
    }

    fun onIntent(intent: PlanningIntent) {
        when (intent) {
            PlanningIntent.Retry -> loadPlanning()
        }
    }

    /** Reactively observe the game and cohouse, load planning when both are available. */
    private fun observeGameAndLoad() {
        viewModelScope.launch {
            gameRepository.currentGame.collect { game ->
                if (game != null) loadPlanning()
            }
        }
    }

    /** Reload planning when the user switches editions. */
    private fun observeEditionChanges() {
        viewModelScope.launch {
            authRepository.currentUser.collect { user ->
                val editionId = user?.activeEditionId
                if (editionId != lastActiveEditionId) {
                    lastActiveEditionId = editionId
                    loadPlanning()
                }
            }
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
