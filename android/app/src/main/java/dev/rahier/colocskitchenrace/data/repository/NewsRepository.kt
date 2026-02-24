package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.News
import kotlinx.coroutines.flow.Flow

interface NewsRepository {
    suspend fun getLatest(): List<News>
    fun listenToNews(): Flow<List<News>>
}
