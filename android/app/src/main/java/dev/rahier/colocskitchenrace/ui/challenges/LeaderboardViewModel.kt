package dev.rahier.colocskitchenrace.ui.challenges

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.repository.ChallengeRepository
import dev.rahier.colocskitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LeaderboardViewModel @Inject constructor(
    private val challengeRepository: ChallengeRepository,
    private val responseRepository: ChallengeResponseRepository,
    private val cohouseRepository: CohouseRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(LeaderboardState())
    val state: StateFlow<LeaderboardState> = _state.asStateFlow()

    init {
        _state.update { it.copy(myCohouseId = cohouseRepository.currentCohouse.value?.id) }
        observeLeaderboard()
    }

    private fun observeLeaderboard() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }

            // Build challengeId -> points map
            val challenges = try {
                challengeRepository.getAll()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Leaderboard", "Failed to load challenges", e)
                emptyList()
            }
            val pointsMap = challenges.associate { it.id to (it.points ?: 0) }

            responseRepository.watchAllValidatedResponses().collect { responses ->
                val validatedResponses = responses.filter { it.status == ChallengeResponseStatus.VALIDATED }

                val grouped = validatedResponses.groupBy { it.cohouseId }
                val entries = grouped.map { (cohouseId, cohouseResponses) ->
                    LeaderboardEntry(
                        cohouseId = cohouseId,
                        cohouseName = cohouseResponses.firstOrNull()?.cohouseName ?: cohouseId,
                        score = cohouseResponses.sumOf { pointsMap[it.challengeId] ?: 0 },
                        validatedCount = cohouseResponses.size,
                        rank = 0,
                    )
                }
                    .sortedByDescending { it.score }
                    .mapIndexed { index, entry -> entry.copy(rank = index + 1) }

                _state.update { it.copy(entries = entries, isLoading = false) }
            }
        }
    }
}
