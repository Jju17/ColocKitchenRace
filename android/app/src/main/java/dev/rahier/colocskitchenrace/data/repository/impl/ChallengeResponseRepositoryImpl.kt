package dev.rahier.colocskitchenrace.data.repository.impl

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.repository.ChallengeResponseRepository
import dev.rahier.colocskitchenrace.util.Constants
import dev.rahier.colocskitchenrace.util.DemoMode
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChallengeResponseRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val storage: FirebaseStorage,
    private val auth: FirebaseAuth,
) : ChallengeResponseRepository {

    @Suppress("UNCHECKED_CAST")
    override suspend fun getAll(): List<ChallengeResponse> {
        if (DemoMode.isActive) return DemoMode.demoChallengeResponses

        val snapshot = firestore.collectionGroup(Constants.RESPONSES_SUBCOLLECTION)
            .limit(500)
            .get()
            .await()

        return snapshot.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            mapToResponse(data, doc.id)
        }
    }

    @Suppress("UNCHECKED_CAST")
    override suspend fun getAllForCohouse(cohouseId: String): List<ChallengeResponse> {
        if (DemoMode.isActive) {
            return DemoMode.demoChallengeResponses.filter { it.cohouseId == cohouseId }
        }

        val snapshot = firestore.collectionGroup(Constants.RESPONSES_SUBCOLLECTION)
            .whereEqualTo("cohouseId", cohouseId)
            .limit(200)
            .get()
            .await()

        return snapshot.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            mapToResponse(data, doc.id)
        }
    }

    override suspend fun updateStatus(
        challengeId: String,
        cohouseId: String,
        status: ChallengeResponseStatus,
    ) {
        firestore.collection(Constants.CHALLENGES_COLLECTION)
            .document(challengeId)
            .collection(Constants.RESPONSES_SUBCOLLECTION)
            .document(cohouseId)
            .update("status", status.name.lowercase())
            .await()
    }

    override suspend fun submit(response: ChallengeResponse): ChallengeResponse {
        if (DemoMode.isActive) return response

        val data = responseToMap(response, auth.currentUser?.uid.orEmpty())
        firestore.collection(Constants.CHALLENGES_COLLECTION)
            .document(response.challengeId)
            .collection(Constants.RESPONSES_SUBCOLLECTION)
            .document(response.cohouseId)
            .set(data)
            .await()
        return response
    }

    override fun watchStatus(challengeId: String, cohouseId: String): Flow<ChallengeResponseStatus?> = callbackFlow {
        val registration = firestore.collection(Constants.CHALLENGES_COLLECTION)
            .document(challengeId)
            .collection(Constants.RESPONSES_SUBCOLLECTION)
            .document(cohouseId)
            .addSnapshotListener { snapshot, _ ->
                val status = snapshot?.data?.get("status") as? String
                trySend(status?.let { parseStatus(it) })
            }
        awaitClose { registration.remove() }
    }

    override fun watchAllResponses(): Flow<List<ChallengeResponse>> = callbackFlow {
        val registration = firestore.collectionGroup(Constants.RESPONSES_SUBCOLLECTION)
            .addSnapshotListener { snapshot, _ ->
                val responses = snapshot?.documents?.mapNotNull { doc ->
                    doc.data?.let { mapToResponse(it, doc.id) }
                } ?: emptyList()
                trySend(responses)
            }
        awaitClose { registration.remove() }
    }

    override fun watchAllValidatedResponses(): Flow<List<ChallengeResponse>> = callbackFlow {
        val registration = firestore.collectionGroup(Constants.RESPONSES_SUBCOLLECTION)
            .whereEqualTo("status", "validated")
            .addSnapshotListener { snapshot, _ ->
                val responses = snapshot?.documents?.mapNotNull { doc ->
                    doc.data?.let { mapToResponse(it, doc.id) }
                } ?: emptyList()
                trySend(responses)
            }
        awaitClose { registration.remove() }
    }

    override suspend fun uploadImage(challengeId: String, cohouseId: String, imageData: ByteArray): String {
        val ref = storage.reference.child("challenges/$challengeId/responses/$cohouseId.jpg")
        ref.putBytes(imageData).await()
        return ref.path
    }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun mapToResponse(data: Map<String, Any?>, docId: String): ChallengeResponse {
            val contentData = data["content"] as? Map<String, Any?>
            val content = parseContent(contentData)

            fun toDate(value: Any?): Date = when (value) {
                is Timestamp -> value.toDate()
                is Date -> value
                else -> Date()
            }

            return ChallengeResponse(
                id = data["id"] as? String ?: docId,
                challengeId = data["challengeId"] as? String ?: "",
                cohouseId = data["cohouseId"] as? String ?: "",
                challengeTitle = data["challengeTitle"] as? String ?: "",
                cohouseName = data["cohouseName"] as? String ?: "",
                content = content,
                status = parseStatus(data["status"] as? String ?: "waiting"),
                submissionDate = toDate(data["submissionDate"]),
            )
        }

        @Suppress("UNCHECKED_CAST")
        private fun parseContent(data: Map<String, Any?>?): ChallengeResponseContent {
            if (data == null) return ChallengeResponseContent.NoChoice
            return when {
                data.containsKey("picture") -> ChallengeResponseContent.Picture(data["picture"] as? String ?: "")
                data.containsKey("multipleChoice") -> ChallengeResponseContent.MultipleChoice(
                    (data["multipleChoice"] as? List<Number>)?.map { it.toInt() } ?: emptyList()
                )
                data.containsKey("singleAnswer") -> ChallengeResponseContent.SingleAnswer(data["singleAnswer"] as? String ?: "")
                else -> ChallengeResponseContent.NoChoice
            }
        }

        private fun parseStatus(status: String): ChallengeResponseStatus = when (status) {
            "validated" -> ChallengeResponseStatus.VALIDATED
            "invalidated" -> ChallengeResponseStatus.INVALIDATED
            else -> ChallengeResponseStatus.WAITING
        }

        fun responseToMap(response: ChallengeResponse, authUid: String): Map<String, Any?> {
            val contentMap = when (response.content) {
                is ChallengeResponseContent.Picture -> mapOf("picture" to response.content.url)
                is ChallengeResponseContent.MultipleChoice -> mapOf("multipleChoice" to response.content.selectedIndices)
                is ChallengeResponseContent.SingleAnswer -> mapOf("singleAnswer" to response.content.answer)
                is ChallengeResponseContent.NoChoice -> mapOf("noChoice" to true)
            }
            return mapOf(
                "id" to response.id,
                "challengeId" to response.challengeId,
                "cohouseId" to response.cohouseId,
                "challengeTitle" to response.challengeTitle,
                "cohouseName" to response.cohouseName,
                "content" to contentMap,
                "status" to response.status.name.lowercase(),
                "submissionDate" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                "submittedByAuthId" to authUid,
            )
        }
    }
}
