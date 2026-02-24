package dev.rahier.colocskitchenrace.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.News
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.data.repository.NewsRepository
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
    val coverImageData: ByteArray? = null,
    val news: List<News> = emptyList(),
    val isRegistered: Boolean = false,
    val isLoading: Boolean = false,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is HomeState) return false
        return game == other.game &&
            cohouse == other.cohouse &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            news == other.news &&
            isRegistered == other.isRegistered &&
            isLoading == other.isLoading
    }

    override fun hashCode(): Int {
        var result = game?.hashCode() ?: 0
        result = 31 * result + (cohouse?.hashCode() ?: 0)
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + news.hashCode()
        result = 31 * result + isRegistered.hashCode()
        result = 31 * result + isLoading.hashCode()
        return result
    }
}

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
                loadCoverImage(cohouse)
            }.collect {}
        }
        viewModelScope.launch {
            val news = try { newsRepository.getLatest() } catch (_: Exception) { emptyList() }
            _state.update { it.copy(news = news) }
        }
    }

    private fun loadCoverImage(cohouse: Cohouse?) {
        val path = cohouse?.coverImagePath ?: run {
            _state.update { it.copy(coverImageData = null) }
            return
        }
        viewModelScope.launch {
            try {
                val data = cohouseRepository.loadCoverImage(path)
                _state.update { it.copy(coverImageData = data) }
            } catch (_: Exception) {
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
            } catch (_: Exception) {}
            _state.update { it.copy(isLoading = false) }
        }
    }
}
