package dev.rahier.colockitchenrace.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.News
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import dev.rahier.colockitchenrace.data.repository.NewsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeState(
    val game: CKRGame? = null,
    val cohouse: Cohouse? = null,
    val news: List<News> = emptyList(),
    val isRegistered: Boolean = false,
    val isLoading: Boolean = false,
)

sealed class HomeIntent {
    data object RegisterClicked : HomeIntent()
    data object ProfileClicked : HomeIntent()
    data object Refresh : HomeIntent()
}

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
    private val newsRepository: NewsRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeState())
    val state: StateFlow<HomeState> = _state.asStateFlow()

    init {
        observeData()
    }

    fun onIntent(intent: HomeIntent) {
        when (intent) {
            HomeIntent.RegisterClicked -> {} // TODO: navigate to registration
            HomeIntent.ProfileClicked -> {} // TODO: navigate to profile
            HomeIntent.Refresh -> refresh()
        }
    }

    private fun observeData() {
        viewModelScope.launch {
            combine(
                gameRepository.currentGame,
                cohouseRepository.currentCohouse,
            ) { game, cohouse ->
                val isRegistered = if (game != null && cohouse != null) {
                    game.cohouseIDs.contains(cohouse.id)
                } else false
                _state.update {
                    it.copy(game = game, cohouse = cohouse, isRegistered = isRegistered)
                }
            }.collect {}
        }
        viewModelScope.launch {
            val news = try { newsRepository.getLatest() } catch (_: Exception) { emptyList() }
            _state.update { it.copy(news = news) }
        }
    }

    private fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                gameRepository.getLatest()
                newsRepository.getLatest()
            } catch (_: Exception) {}
            _state.update { it.copy(isLoading = false) }
        }
    }
}
