package dev.rahier.colocskitchenrace.ui.challenges

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.ChallengeContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.ChallengeRepository
import dev.rahier.colocskitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.util.ErrorMapper
import dev.rahier.colocskitchenrace.util.ImageUtils
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class ChallengesViewModel @Inject constructor(
    private val challengeRepository: ChallengeRepository,
    private val responseRepository: ChallengeResponseRepository,
    private val cohouseRepository: CohouseRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _state = MutableStateFlow(ChallengesState())
    val state: StateFlow<ChallengesState> = _state.asStateFlow()
    private var responsesListenerJob: Job? = null
    private var lastActiveEditionId: String? = null

    init {
        // observeEditionChanges will trigger loadChallenges() reactively once the
        // user session is restored, avoiding a premature load with stale activeEditionId
        observeCohouse()
        observeEditionChanges()
    }

    fun onIntent(intent: ChallengesIntent) {
        when (intent) {
            is ChallengesIntent.FilterSelected -> _state.update { it.copy(selectedFilter = intent.filter) }
            is ChallengesIntent.StartChallenge -> startChallenge(intent.challengeId)
            is ChallengesIntent.CancelParticipation -> cancelParticipation()
            is ChallengesIntent.SelectChoice -> _state.update { it.copy(selectedChoiceIndex = intent.index) }
            is ChallengesIntent.TextAnswerChanged -> _state.update { it.copy(textAnswer = intent.text) }
            is ChallengesIntent.PhotoCaptured -> handlePhotoCaptured(intent.imageData)
            is ChallengesIntent.SubmitResponse -> submitResponse()
            ChallengesIntent.LeaderboardClicked -> {} // No-op: handled directly by MainScreen navigation (onShowLeaderboard callback)
        }
    }

    private fun startChallenge(challengeId: String) {
        // Don't start if already responded
        val existingResponse = _state.value.responseFor(challengeId)
        if (existingResponse != null) return

        _state.update {
            it.copy(
                participatingChallengeId = challengeId,
                selectedChoiceIndex = null,
                textAnswer = "",
                capturedImageData = null,
                submitError = null,
            )
        }
    }

    private fun cancelParticipation() {
        _state.update {
            it.copy(
                participatingChallengeId = null,
                selectedChoiceIndex = null,
                textAnswer = "",
                capturedImageData = null,
                submitError = null,
            )
        }
    }

    private fun handlePhotoCaptured(imageData: ByteArray) {
        val compressed = compressImage(imageData)
        _state.update { it.copy(capturedImageData = compressed) }
    }

    private fun submitResponse() {
        val currentState = _state.value
        val challengeId = currentState.participatingChallengeId ?: return
        val challenge = currentState.challenges.firstOrNull { it.id == challengeId } ?: return
        val cohouse = cohouseRepository.currentCohouse.value ?: return

        viewModelScope.launch {
            _state.update { it.copy(isSubmitting = true, submitError = null) }
            try {
                val responseContent: ChallengeResponseContent = when (challenge.content) {
                    is ChallengeContent.NoChoice -> ChallengeResponseContent.NoChoice

                    is ChallengeContent.SingleAnswer -> {
                        val answer = currentState.textAnswer.trim()
                        if (answer.isEmpty()) {
                            _state.update { it.copy(isSubmitting = false, submitError = context.getString(R.string.error_enter_answer)) }
                            return@launch
                        }
                        ChallengeResponseContent.SingleAnswer(answer)
                    }

                    is ChallengeContent.MultipleChoice -> {
                        val index = currentState.selectedChoiceIndex
                        if (index == null) {
                            _state.update { it.copy(isSubmitting = false, submitError = context.getString(R.string.error_select_answer)) }
                            return@launch
                        }
                        ChallengeResponseContent.MultipleChoice(listOf(index))
                    }

                    is ChallengeContent.Picture -> {
                        val imageData = currentState.capturedImageData
                        if (imageData == null) {
                            _state.update { it.copy(isSubmitting = false, submitError = context.getString(R.string.error_take_photo)) }
                            return@launch
                        }
                        val path = responseRepository.uploadImage(challengeId, cohouse.id, imageData)
                        ChallengeResponseContent.Picture(path)
                    }
                }

                val response = ChallengeResponse(
                    id = UUID.randomUUID().toString(),
                    challengeId = challengeId,
                    cohouseId = cohouse.id,
                    challengeTitle = challenge.title,
                    cohouseName = cohouse.name,
                    content = responseContent,
                    status = ChallengeResponseStatus.WAITING,
                )

                val savedResponse = responseRepository.submit(response)

                _state.update {
                    it.copy(
                        responses = it.responses + savedResponse,
                        participatingChallengeId = null,
                        selectedChoiceIndex = null,
                        textAnswer = "",
                        capturedImageData = null,
                        isSubmitting = false,
                        submitError = null,
                    )
                }
            } catch (e: Exception) {
                Log.e("ChallengesVM", "Failed to submit response", e)
                _state.update { it.copy(isSubmitting = false, submitError = ErrorMapper.toUserMessage(e, context)) }
            }
        }
    }

    private fun compressImage(data: ByteArray, maxBytes: Int = 1024 * 1024): ByteArray =
        ImageUtils.compressToJpeg(data, maxBytes)

    private fun loadChallenges() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val allChallenges = challengeRepository.getAll()
                // Filter by active edition
                val activeEditionId = authRepository.currentUser.value?.activeEditionId
                val filtered = allChallenges.filter { challenge ->
                    if (activeEditionId != null) {
                        // In a special edition: show only that edition's challenges
                        challenge.editionId == activeEditionId
                    } else {
                        // Global mode: show challenges without an editionId
                        challenge.editionId == null
                    }
                }
                _state.update { it.copy(challenges = filtered) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("ChallengesVM", "Failed to load challenges", e)
            }
            _state.update { it.copy(isLoading = false) }
        }
    }

    private fun observeCohouse() {
        viewModelScope.launch {
            cohouseRepository.currentCohouse.collect { cohouse ->
                _state.update { it.copy(hasCohouse = cohouse != null) }
                // Start real-time listener for responses when cohouse is available
                startResponsesListener(cohouse?.id)
            }
        }
    }

    private fun observeEditionChanges() {
        viewModelScope.launch {
            authRepository.currentUser.collect { user ->
                val editionId = user?.activeEditionId
                if (editionId != lastActiveEditionId) {
                    lastActiveEditionId = editionId
                    loadChallenges()
                }
            }
        }
    }

    private fun startResponsesListener(cohouseId: String?) {
        responsesListenerJob?.cancel()
        if (cohouseId == null) {
            _state.update { it.copy(responses = emptyList()) }
            return
        }
        responsesListenerJob = viewModelScope.launch {
            try {
                // Initial one-shot load for immediate data
                val responses = responseRepository.getAllForCohouse(cohouseId)
                _state.update { it.copy(responses = responses) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("ChallengesVM", "Failed to load initial responses", e)
            }
            // Real-time listener for status updates (admin validation/invalidation)
            try {
                responseRepository.watchAllResponses().collect { responses ->
                    // Filter to only this cohouse's responses
                    val cohouseResponses = responses.filter { it.cohouseId == cohouseId }
                    _state.update { it.copy(responses = cohouseResponses) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w("ChallengesVM", "Responses listener failed", e)
            }
        }
    }
}
