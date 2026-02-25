package dev.rahier.colocskitchenrace.ui.challenges

import android.graphics.BitmapFactory
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.Challenge
import dev.rahier.colocskitchenrace.data.model.ChallengeContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.model.ChallengeState
import dev.rahier.colocskitchenrace.data.repository.ChallengeRepository
import dev.rahier.colocskitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.util.UUID
import javax.inject.Inject

data class ChallengesState(
    val challenges: List<Challenge> = emptyList(),
    val responses: List<ChallengeResponse> = emptyList(),
    val selectedFilter: ChallengeFilter = ChallengeFilter.ALL,
    val hasCohouse: Boolean = false,
    val isLoading: Boolean = false,
    // Participation state
    val participatingChallengeId: String? = null,
    val selectedChoiceIndex: Int? = null,
    val textAnswer: String = "",
    val capturedImageData: ByteArray? = null,
    val isSubmitting: Boolean = false,
    val submitError: String? = null,
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

    fun responseFor(challengeId: String): ChallengeResponse? =
        responses.firstOrNull { it.challengeId == challengeId }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ChallengesState) return false
        return challenges == other.challenges &&
            responses == other.responses &&
            selectedFilter == other.selectedFilter &&
            hasCohouse == other.hasCohouse &&
            isLoading == other.isLoading &&
            participatingChallengeId == other.participatingChallengeId &&
            selectedChoiceIndex == other.selectedChoiceIndex &&
            textAnswer == other.textAnswer &&
            capturedImageData.contentEquals(other.capturedImageData) &&
            isSubmitting == other.isSubmitting &&
            submitError == other.submitError
    }

    override fun hashCode(): Int {
        var result = challenges.hashCode()
        result = 31 * result + responses.hashCode()
        result = 31 * result + selectedFilter.hashCode()
        result = 31 * result + hasCohouse.hashCode()
        result = 31 * result + isLoading.hashCode()
        result = 31 * result + (participatingChallengeId?.hashCode() ?: 0)
        result = 31 * result + (selectedChoiceIndex?.hashCode() ?: 0)
        result = 31 * result + textAnswer.hashCode()
        result = 31 * result + (capturedImageData?.contentHashCode() ?: 0)
        result = 31 * result + isSubmitting.hashCode()
        result = 31 * result + (submitError?.hashCode() ?: 0)
        return result
    }
}

sealed class ChallengesIntent {
    data class FilterSelected(val filter: ChallengeFilter) : ChallengesIntent()
    data class StartChallenge(val challengeId: String) : ChallengesIntent()
    data object CancelParticipation : ChallengesIntent()
    data class SelectChoice(val index: Int) : ChallengesIntent()
    data class TextAnswerChanged(val text: String) : ChallengesIntent()
    data class PhotoCaptured(val imageData: ByteArray) : ChallengesIntent()
    data object SubmitResponse : ChallengesIntent()
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
            is ChallengesIntent.StartChallenge -> startChallenge(intent.challengeId)
            is ChallengesIntent.CancelParticipation -> cancelParticipation()
            is ChallengesIntent.SelectChoice -> _state.update { it.copy(selectedChoiceIndex = intent.index) }
            is ChallengesIntent.TextAnswerChanged -> _state.update { it.copy(textAnswer = intent.text) }
            is ChallengesIntent.PhotoCaptured -> handlePhotoCaptured(intent.imageData)
            is ChallengesIntent.SubmitResponse -> submitResponse()
            ChallengesIntent.LeaderboardClicked -> {} // handled by navigation
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
                            _state.update { it.copy(isSubmitting = false, submitError = "Veuillez entrer une reponse") }
                            return@launch
                        }
                        ChallengeResponseContent.SingleAnswer(answer)
                    }

                    is ChallengeContent.MultipleChoice -> {
                        val index = currentState.selectedChoiceIndex
                        if (index == null) {
                            _state.update { it.copy(isSubmitting = false, submitError = "Veuillez choisir une reponse") }
                            return@launch
                        }
                        ChallengeResponseContent.MultipleChoice(listOf(index))
                    }

                    is ChallengeContent.Picture -> {
                        val imageData = currentState.capturedImageData
                        if (imageData == null) {
                            _state.update { it.copy(isSubmitting = false, submitError = "Veuillez prendre ou choisir une photo") }
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
                _state.update { it.copy(isSubmitting = false, submitError = ErrorMapper.toUserMessage(e, "Erreur lors de l'envoi. Réessayez.")) }
            }
        }
    }

    private fun compressImage(data: ByteArray, maxBytes: Int = 1024 * 1024): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return data
        var quality = 85
        var output: ByteArray
        do {
            val stream = ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality, stream)
            output = stream.toByteArray()
            quality -= 10
        } while (output.size > maxBytes && quality > 10)
        return output
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
            }
        }
    }
}
