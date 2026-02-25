package dev.rahier.colocskitchenrace.ui.main

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.ChallengeRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.data.repository.NewsRepository
import kotlin.coroutines.cancellation.CancellationException
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
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Main", "Failed to load initial data", e)
            }
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
