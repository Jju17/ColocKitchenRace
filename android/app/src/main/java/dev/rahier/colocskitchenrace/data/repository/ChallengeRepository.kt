package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.Challenge
import kotlinx.coroutines.flow.StateFlow

interface ChallengeRepository {
    val challenges: StateFlow<List<Challenge>>

    suspend fun getAll(): List<Challenge>
}
