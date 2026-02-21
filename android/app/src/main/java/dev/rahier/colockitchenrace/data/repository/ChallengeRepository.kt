package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.Challenge
import kotlinx.coroutines.flow.StateFlow

interface ChallengeRepository {
    val challenges: StateFlow<List<Challenge>>

    suspend fun getAll(): List<Challenge>
}
