package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.CKRMyPlanning
import kotlinx.coroutines.flow.StateFlow

interface CKRGameRepository {
    val currentGame: StateFlow<CKRGame?>

    suspend fun getLatest(): CKRGame?
    suspend fun confirmRegistration(
        gameId: String,
        cohouseId: String,
        paymentIntentId: String,
    )
    suspend fun getMyPlanning(gameId: String, cohouseId: String): CKRMyPlanning
}
