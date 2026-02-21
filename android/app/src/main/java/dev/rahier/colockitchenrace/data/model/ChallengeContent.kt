package dev.rahier.colockitchenrace.data.model

sealed class ChallengeContent {
    data class Picture(val dummy: Unit = Unit) : ChallengeContent()
    data class MultipleChoice(
        val choices: List<String> = listOf("", "", "", ""),
        val correctAnswerIndex: Int? = null,
        val shuffleAnswers: Boolean = true,
    ) : ChallengeContent()

    data class SingleAnswer(val dummy: Unit = Unit) : ChallengeContent()
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
