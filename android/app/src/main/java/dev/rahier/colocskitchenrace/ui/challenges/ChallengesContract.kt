package dev.rahier.colocskitchenrace.ui.challenges

import androidx.annotation.StringRes
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.Challenge
import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.model.ChallengeState

enum class ChallengeFilter(@StringRes val labelResId: Int) {
    ALL(R.string.filter_all),
    TODO(R.string.filter_todo),
    WAITING(R.string.filter_waiting),
    REVIEWED(R.string.filter_reviewed),
}

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
            val sorted: List<Challenge> = when (selectedFilter) {
                ChallengeFilter.ALL -> {
                    // Active challenges first, ended last
                    challenges.sortedWith(compareBy<Challenge> {
                        when (it.state) {
                            ChallengeState.ONGOING -> 0
                            ChallengeState.NOT_STARTED -> 1
                            ChallengeState.DONE -> 2
                        }
                    }.thenBy { it.endDate })
                }
                ChallengeFilter.TODO -> challenges.filter {
                    it.id !in respondedIds
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
            return sorted
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
            (capturedImageData?.contentEquals(other.capturedImageData) ?: (other.capturedImageData == null)) &&
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

sealed interface ChallengesIntent {
    data class FilterSelected(val filter: ChallengeFilter) : ChallengesIntent
    data class StartChallenge(val challengeId: String) : ChallengesIntent
    data object CancelParticipation : ChallengesIntent
    data class SelectChoice(val index: Int) : ChallengesIntent
    data class TextAnswerChanged(val text: String) : ChallengesIntent
    data class PhotoCaptured(val imageData: ByteArray) : ChallengesIntent
    data object SubmitResponse : ChallengesIntent
    data object LeaderboardClicked : ChallengesIntent
}
