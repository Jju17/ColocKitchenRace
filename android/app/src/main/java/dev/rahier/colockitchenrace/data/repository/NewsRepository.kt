package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.News
import kotlinx.coroutines.flow.Flow

interface NewsRepository {
    suspend fun getLatest(): List<News>
    fun listenToNews(): Flow<List<News>>
}
