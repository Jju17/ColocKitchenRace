package dev.rahier.colocskitchenrace.ui.home

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.data.repository.EditionRepository
import dev.rahier.colocskitchenrace.data.repository.NewsRepository
import dev.rahier.colocskitchenrace.data.repository.UserRepository
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
    private val editionRepository: EditionRepository,
    private val userRepository: UserRepository,
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
            HomeIntent.Refresh -> refresh()
            is HomeIntent.JoinCodeChanged -> _state.update {
                it.copy(joinCode = intent.code, joinEditionError = null, joinEditionSuccess = null)
            }
            HomeIntent.JoinEditionTapped -> joinEdition()
            HomeIntent.LeaveEditionTapped -> leaveEdition()
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
        // Observe user's activeEditionId and load edition info (deduplicate)
        viewModelScope.launch {
            var lastEditionId: String? = null
            authRepository.currentUser.collect { user ->
                val editionId = user?.activeEditionId
                if (editionId != lastEditionId) {
                    lastEditionId = editionId
                    _state.update { it.copy(activeEditionId = editionId) }
                    if (editionId != null) {
                        loadActiveEdition(editionId)
                    } else {
                        _state.update { it.copy(activeEdition = null) }
                    }
                }
            }
        }
    }

    private fun loadActiveEdition(editionId: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoadingEdition = true) }
            try {
                val edition = editionRepository.getEdition(editionId)
                _state.update { it.copy(activeEdition = edition, isLoadingEdition = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to load active edition", e)
                _state.update { it.copy(isLoadingEdition = false) }
            }
        }
    }

    private fun joinEdition() {
        val code = _state.value.joinCode.trim().uppercase()
        if (code.isEmpty()) {
            _state.update { it.copy(joinEditionError = "Enter a code to join") }
            return
        }
        viewModelScope.launch {
            _state.update { it.copy(isJoiningEdition = true, joinEditionError = null, joinEditionSuccess = null) }
            try {
                val result = editionRepository.joinByCode(code)
                // Cloud Function already wrote activeEditionId to Firestore — only update local state
                authRepository.updateLocalActiveEditionId(result.gameId)
                _state.update {
                    it.copy(
                        isJoiningEdition = false,
                        joinCode = "",
                        joinEditionSuccess = "Joined \"${result.title}\"!",
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to join edition", e)
                _state.update {
                    it.copy(isJoiningEdition = false, joinEditionError = e.message ?: "Failed to join")
                }
            }
        }
    }

    private fun leaveEdition() {
        val editionId = _state.value.activeEditionId ?: return
        viewModelScope.launch {
            _state.update { it.copy(isLeavingEdition = true, joinEditionError = null) }
            try {
                editionRepository.leave(editionId)
                // Cloud Function already cleared activeEditionId in Firestore — only update local state
                authRepository.updateLocalActiveEditionId(null)
                _state.update {
                    it.copy(
                        isLeavingEdition = false,
                        joinEditionSuccess = null,
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("Home", "Failed to leave edition", e)
                _state.update {
                    it.copy(isLeavingEdition = false, joinEditionError = e.message ?: "Failed to leave")
                }
            }
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
