package dev.rahier.colockitchenrace.ui.challenges

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colockitchenrace.data.repository.ChallengeRepository
import dev.rahier.colockitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LeaderboardEntry(
    val cohouseId: String,
    val cohouseName: String,
    val score: Int,
    val validatedCount: Int,
    val rank: Int,
)

data class LeaderboardState(
    val entries: List<LeaderboardEntry> = emptyList(),
    val myCohouseId: String? = null,
    val isLoading: Boolean = false,
)

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
            val challenges = try { challengeRepository.getAll() } catch (_: Exception) { emptyList() }
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
