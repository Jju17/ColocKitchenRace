package dev.rahier.colockitchenrace.ui.challenges

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.Challenge
import dev.rahier.colockitchenrace.data.model.ChallengeResponse
import dev.rahier.colockitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colockitchenrace.data.model.ChallengeState
import dev.rahier.colockitchenrace.data.repository.ChallengeRepository
import dev.rahier.colockitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ChallengesState(
    val challenges: List<Challenge> = emptyList(),
    val responses: List<ChallengeResponse> = emptyList(),
    val selectedFilter: ChallengeFilter = ChallengeFilter.ALL,
    val hasCohouse: Boolean = false,
    val isLoading: Boolean = false,
) {
    val filteredChallenges: List<Challenge>
        get() {
            val respondedIds = responses.map { it.challengeId }.toSet()
            return when (selectedFilter) {
                ChallengeFilter.ALL -> challenges
                ChallengeFilter.TODO -> challenges.filter {
                    it.state == ChallengeState.ONGOING && it.id !in respondedIds
                }
                ChallengeFilter.WAITING -> challenges.filter {
                    it.id in respondedIds && responses.any { r ->
                        r.challengeId == it.id && r.status == ChallengeResponseStatus.WAITING
                    }
                }
                ChallengeFilter.REVIEWED -> challenges.filter {
                    it.id in respondedIds && responses.any { r ->
                        r.challengeId == it.id && r.status != ChallengeResponseStatus.WAITING
                    }
                }
            }
        }
}

sealed class ChallengesIntent {
    data class FilterSelected(val filter: ChallengeFilter) : ChallengesIntent()
    data class StartChallenge(val challengeId: String) : ChallengesIntent()
    data object LeaderboardClicked : ChallengesIntent()
}

@HiltViewModel
class ChallengesViewModel @Inject constructor(
    private val challengeRepository: ChallengeRepository,
    private val responseRepository: ChallengeResponseRepository,
    private val cohouseRepository: CohouseRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(ChallengesState())
    val state: StateFlow<ChallengesState> = _state.asStateFlow()

    init {
        loadChallenges()
        observeCohouse()
    }

    fun onIntent(intent: ChallengesIntent) {
        when (intent) {
            is ChallengesIntent.FilterSelected -> _state.update { it.copy(selectedFilter = intent.filter) }
            is ChallengesIntent.StartChallenge -> {} // TODO: navigate to challenge detail
            ChallengesIntent.LeaderboardClicked -> {} // TODO: show leaderboard
        }
    }

    private fun loadChallenges() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val challenges = challengeRepository.getAll()
                _state.update { it.copy(challenges = challenges) }

                val cohouse = cohouseRepository.currentCohouse.value
                if (cohouse != null) {
                    val responses = responseRepository.getAllForCohouse(cohouse.id)
                    _state.update { it.copy(responses = responses) }
                }
            } catch (_: Exception) {}
            _state.update { it.copy(isLoading = false) }
        }
    }

    private fun observeCohouse() {
        viewModelScope.launch {
            cohouseRepository.currentCohouse.collect { cohouse ->
                _state.update { it.copy(hasCohouse = cohouse != null) }
            }
        }
    }
}
