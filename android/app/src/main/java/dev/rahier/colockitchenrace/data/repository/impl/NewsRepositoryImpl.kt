package dev.rahier.colockitchenrace.data.repository.impl

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import dev.rahier.colockitchenrace.data.model.News
import dev.rahier.colockitchenrace.data.repository.NewsRepository
import dev.rahier.colockitchenrace.util.Constants
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NewsRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
) : NewsRepository {

    override suspend fun getLatest(): List<News> {
        val snapshot = firestore.collection(Constants.NEWS_COLLECTION)
            .orderBy("publicationTimestamp", Query.Direction.DESCENDING)
            .limit(10)
            .get()
            .await()

        return snapshot.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            mapToNews(data, doc.id)
        }
    }

    override fun listenToNews(): Flow<List<News>> = callbackFlow {
        val registration = firestore.collection(Constants.NEWS_COLLECTION)
            .orderBy("publicationTimestamp", Query.Direction.DESCENDING)
            .limit(10)
            .addSnapshotListener { snapshot, _ ->
                val news = snapshot?.documents?.mapNotNull { doc ->
                    doc.data?.let { mapToNews(it, doc.id) }
                } ?: emptyList()
                trySend(news)
            }
        awaitClose { registration.remove() }
    }

    companion object {
        fun mapToNews(data: Map<String, Any?>, docId: String): News {
            val timestamp = data["publicationTimestamp"]
            val date = when (timestamp) {
                is Timestamp -> timestamp.toDate()
                is Date -> timestamp
                else -> Date()
            }
            return News(
                id = data["id"] as? String ?: docId,
                title = data["title"] as? String ?: "",
                body = data["body"] as? String ?: "",
                publicationDate = date,
            )
        }
    }
}
