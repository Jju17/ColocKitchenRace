package dev.rahier.colocskitchenrace.data.model

sealed class ChallengeContent {
    data object Picture : ChallengeContent()
    data class MultipleChoice(
        val choices: List<String> = listOf("", "", "", ""),
        val correctAnswerIndex: Int? = null,
        val shuffleAnswers: Boolean = true,
    ) : ChallengeContent()

    data object SingleAnswer : ChallengeContent()
    data class NoChoice(val text: String = "") : ChallengeContent()

    val type: String
        get() = when (this) {
            is Picture -> "picture"
            is MultipleChoice -> "multipleChoice"
            is SingleAnswer -> "singleAnswer"
            is NoChoice -> "noChoice"
        }

    fun toResponseContent(): ChallengeResponseContent = when (this) {
        is Picture -> ChallengeResponseContent.Picture("")
        is MultipleChoice -> ChallengeResponseContent.MultipleChoice(emptyList())
        is SingleAnswer -> ChallengeResponseContent.SingleAnswer("")
        is NoChoice -> ChallengeResponseContent.NoChoice
    }
}
