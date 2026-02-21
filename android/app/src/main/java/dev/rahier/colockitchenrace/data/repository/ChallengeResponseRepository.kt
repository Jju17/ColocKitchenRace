package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.ChallengeResponse
import dev.rahier.colockitchenrace.data.model.ChallengeResponseContent
import dev.rahier.colockitchenrace.data.model.ChallengeResponseStatus
import kotlinx.coroutines.flow.Flow

interface ChallengeResponseRepository {
    suspend fun getAllForCohouse(cohouseId: String): List<ChallengeResponse>
    suspend fun submit(response: ChallengeResponse): ChallengeResponse
    fun watchStatus(challengeId: String, cohouseId: String): Flow<ChallengeResponseStatus?>
    fun watchAllValidatedResponses(): Flow<List<ChallengeResponse>>
}
