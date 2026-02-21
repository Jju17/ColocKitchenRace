package dev.rahier.colockitchenrace.data.model

import java.util.Date
import java.util.UUID

enum class ChallengeState { DONE, ONGOING, NOT_STARTED }

data class Challenge(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "",
    val startDate: Date = Date(),
    val endDate: Date = Date(),
    val body: String = "",
    val content: ChallengeContent = ChallengeContent.NoChoice(),
    val points: Int? = null,
) {
    val state: ChallengeState
        get() {
            val now = Date()
            return when {
                now.after(endDate) -> ChallengeState.DONE
                now.after(startDate) || now == startDate -> ChallengeState.ONGOING
                else -> ChallengeState.NOT_STARTED
            }
        }
}
