package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.CKRGame

data class JoinEditionResult(
    val gameId: String,
    val title: String,
    val editionType: String,
)

interface EditionRepository {
    /** Join a special edition by its 6-character code. */
    suspend fun joinByCode(code: String): JoinEditionResult

    /** Leave the current special edition. */
    suspend fun leave(gameId: String)

    /** Fetch a specific edition by game ID. */
    suspend fun getEdition(gameId: String): CKRGame?
}
