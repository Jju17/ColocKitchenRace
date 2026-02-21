package dev.rahier.colockitchenrace.ui.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.ChallengeRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import dev.rahier.colockitchenrace.data.repository.NewsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
    private val challengeRepository: ChallengeRepository,
    private val newsRepository: NewsRepository,
) : ViewModel() {

    private val _showPlanningTab = MutableStateFlow(false)
    val showPlanningTab: StateFlow<Boolean> = _showPlanningTab.asStateFlow()

    init {
        loadData()
        observePlanningVisibility()
    }

    private fun loadData() {
        viewModelScope.launch {
            try {
                gameRepository.getLatest()
                challengeRepository.getAll()
                newsRepository.getLatest()
            } catch (_: Exception) {}
        }
    }

    private fun observePlanningVisibility() {
        viewModelScope.launch {
            combine(
                gameRepository.currentGame,
                cohouseRepository.currentCohouse,
            ) { game, cohouse ->
                if (game == null || cohouse == null) return@combine false
                game.isRevealed && game.cohouseIDs.contains(cohouse.id)
            }.collect { _showPlanningTab.value = it }
        }
    }
}
