package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.CKRMyPlanning
import kotlinx.coroutines.flow.StateFlow

interface CKRGameRepository {
    val currentGame: StateFlow<CKRGame?>

    suspend fun getLatest(): CKRGame?
    suspend fun registerForGame(
        gameId: String,
        cohouseId: String,
        attendingUserIds: List<String>,
        averageAge: Int,
        cohouseType: String,
        paymentIntentId: String?,
    )
    suspend fun getMyPlanning(gameId: String, cohouseId: String): CKRMyPlanning
}
