package dev.rahier.colocskitchenrace.data.repository.impl

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.functions.FirebaseFunctions
import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.repository.EditionRepository
import dev.rahier.colocskitchenrace.data.repository.JoinEditionResult
import dev.rahier.colocskitchenrace.util.Constants
import dev.rahier.colocskitchenrace.util.DemoMode
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class EditionRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val functions: FirebaseFunctions,
) : EditionRepository {

    override suspend fun joinByCode(code: String): JoinEditionResult {
        if (DemoMode.isActive) {
            return JoinEditionResult(
                gameId = "demo-special-edition",
                title = "Demo Edition",
                editionType = "special",
            )
        }

        val result = functions.getHttpsCallable("joinEditionByCode")
            .call(hashMapOf("joinCode" to code.uppercase()))
            .await()

        @Suppress("UNCHECKED_CAST")
        val data = result.data as? Map<String, Any>
            ?: throw Exception("Invalid response from joinEditionByCode")

        return JoinEditionResult(
            gameId = data["gameId"] as? String ?: throw Exception("Missing gameId"),
            title = data["title"] as? String ?: "",
            editionType = data["editionType"] as? String ?: "special",
        )
    }

    override suspend fun leave(gameId: String) {
        if (DemoMode.isActive) return

        functions.getHttpsCallable("leaveEdition")
            .call(hashMapOf("gameId" to gameId))
            .await()
    }

    @Suppress("UNCHECKED_CAST")
    override suspend fun getEdition(gameId: String): CKRGame? {
        if (DemoMode.isActive) return null

        val doc = firestore.collection(Constants.CKR_GAMES_COLLECTION)
            .document(gameId)
            .get()
            .await()

        if (!doc.exists()) return null

        val data = doc.data ?: return null
        return CKRGameRepositoryImpl.mapToGame(data, doc.id)
    }
}
