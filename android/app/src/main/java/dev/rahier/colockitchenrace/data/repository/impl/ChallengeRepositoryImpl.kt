package dev.rahier.colockitchenrace.data.repository.impl

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import dev.rahier.colockitchenrace.data.model.Challenge
import dev.rahier.colockitchenrace.data.model.ChallengeContent
import dev.rahier.colockitchenrace.data.repository.ChallengeRepository
import dev.rahier.colockitchenrace.util.Constants
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChallengeRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
) : ChallengeRepository {

    private val _challenges = MutableStateFlow<List<Challenge>>(emptyList())
    override val challenges: StateFlow<List<Challenge>> = _challenges.asStateFlow()

    @Suppress("UNCHECKED_CAST")
    override suspend fun getAll(): List<Challenge> {
        val snapshot = firestore.collection(Constants.CHALLENGES_COLLECTION)
            .orderBy("endDate", Query.Direction.ASCENDING)
            .get()
            .await()

        val list = snapshot.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            mapToChallenge(data, doc.id)
        }
        _challenges.value = list
        return list
    }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun mapToChallenge(data: Map<String, Any?>, docId: String): Challenge {
            fun toDate(value: Any?): Date = when (value) {
                is Timestamp -> value.toDate()
                is Date -> value
                else -> Date()
            }

            val contentMap = data["content"] as? Map<String, Any?>
            val content = parseContent(contentMap)

            return Challenge(
                id = data["id"] as? String ?: docId,
                title = data["title"] as? String ?: "",
                startDate = toDate(data["startDate"]),
                endDate = toDate(data["endDate"]),
                body = data["body"] as? String ?: "",
                content = content,
                points = (data["points"] as? Number)?.toInt(),
            )
        }

        @Suppress("UNCHECKED_CAST")
        private fun parseContent(data: Map<String, Any?>?): ChallengeContent {
            if (data == null) return ChallengeContent.NoChoice()

            // The content is stored as a discriminated union with type key
            return when {
                data.containsKey("picture") -> ChallengeContent.Picture()
                data.containsKey("multipleChoice") -> {
                    val mc = data["multipleChoice"] as? Map<String, Any?> ?: return ChallengeContent.MultipleChoice()
                    ChallengeContent.MultipleChoice(
                        choices = mc["choices"] as? List<String> ?: emptyList(),
                        correctAnswerIndex = (mc["correctAnswerIndex"] as? Number)?.toInt(),
                        shuffleAnswers = mc["shuffleAnswers"] as? Boolean ?: true,
                    )
                }
                data.containsKey("singleAnswer") -> ChallengeContent.SingleAnswer()
                data.containsKey("noChoice") -> {
                    val nc = data["noChoice"] as? Map<String, Any?>
                    ChallengeContent.NoChoice(text = nc?.get("text") as? String ?: "")
                }
                else -> ChallengeContent.NoChoice()
            }
        }
    }
}
