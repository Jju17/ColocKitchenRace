package dev.rahier.colocskitchenrace.ui.home

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.data.repository.NewsRepository
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
    private val newsRepository: NewsRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeState())
    val state: StateFlow<HomeState> = _state.asStateFlow()
    private var currentCoverImagePath: String? = null

    init {
        // Start real-time game listener — updates currentGame StateFlow automatically
        viewModelScope.launch {
            gameRepository.listenToGame().collect {}
        }
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
                loadCoverImage(cohouse)
            }.collect {}
        }
        viewModelScope.launch {
            val news = try {
                newsRepository.getLatest()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to load news", e)
                emptyList()
            }
            _state.update { it.copy(news = news) }
        }
    }

    private fun loadCoverImage(cohouse: Cohouse?) {
        val path = cohouse?.coverImagePath ?: run {
            currentCoverImagePath = null
            _state.update { it.copy(coverImageData = null) }
            return
        }
        if (path == currentCoverImagePath) return
        currentCoverImagePath = path
        viewModelScope.launch {
            try {
                val data = cohouseRepository.loadCoverImage(path)
                _state.update { it.copy(coverImageData = data) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to load cover image", e)
                _state.update { it.copy(coverImageData = null) }
            }
        }
    }

    private fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                gameRepository.getLatest()
                newsRepository.getLatest()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to refresh data", e)
            }
            _state.update { it.copy(isLoading = false) }
        }
    }
}
