package dev.rahier.colockitchenrace.data.model

import java.util.Date
import java.util.UUID

enum class ChallengeResponseStatus { WAITING, VALIDATED, INVALIDATED }

sealed class ChallengeResponseContent {
    data class Picture(val url: String) : ChallengeResponseContent()
    data class MultipleChoice(val selectedIndices: List<Int>) : ChallengeResponseContent()
    data class SingleAnswer(val answer: String) : ChallengeResponseContent()
    data object NoChoice : ChallengeResponseContent()
}

data class ChallengeResponse(
    val id: String = UUID.randomUUID().toString(),
    val challengeId: String = "",
    val cohouseId: String = "",
    val challengeTitle: String = "",
    val cohouseName: String = "",
    val content: ChallengeResponseContent = ChallengeResponseContent.NoChoice,
    val status: ChallengeResponseStatus = ChallengeResponseStatus.WAITING,
    val submissionDate: Date = Date(),
)
