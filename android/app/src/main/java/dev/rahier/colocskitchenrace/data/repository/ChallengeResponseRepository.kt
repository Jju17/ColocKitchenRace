package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import kotlinx.coroutines.flow.Flow

interface ChallengeResponseRepository {
    suspend fun getAll(): List<ChallengeResponse>
    suspend fun getAllForCohouse(cohouseId: String): List<ChallengeResponse>
    suspend fun updateStatus(challengeId: String, cohouseId: String, status: ChallengeResponseStatus)
    suspend fun submit(response: ChallengeResponse): ChallengeResponse
    fun watchStatus(challengeId: String, cohouseId: String): Flow<ChallengeResponseStatus?>
    fun watchAllResponses(cohouseId: String): Flow<List<ChallengeResponse>>
    fun watchAllValidatedResponses(): Flow<List<ChallengeResponse>>
    suspend fun uploadImage(challengeId: String, cohouseId: String, imageData: ByteArray): String
}
