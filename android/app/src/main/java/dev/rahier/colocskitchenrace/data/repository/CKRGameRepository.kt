package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.CKRMyPlanning
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface CKRGameRepository {
    val currentGame: StateFlow<CKRGame?>

    suspend fun getLatest(): CKRGame?
    fun listenToGame(): Flow<CKRGame?>
    suspend fun confirmRegistration(
        gameId: String,
        cohouseId: String,
        paymentIntentId: String,
    )
    suspend fun cancelReservation(gameId: String, cohouseId: String)
    fun removeCohouseLocally(cohouseId: String)
    suspend fun getMyPlanning(gameId: String, cohouseId: String): CKRMyPlanning
}
