package dev.rahier.colocskitchenrace.ui.challenges

data class LeaderboardEntry(
    val cohouseId: String,
    val cohouseName: String,
    val score: Int,
    val validatedCount: Int,
    val rank: Int,
)

data class LeaderboardState(
    val entries: List<LeaderboardEntry> = emptyList(),
    val myCohouseId: String? = null,
    val isLoading: Boolean = false,
)
