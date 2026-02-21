package dev.rahier.colockitchenrace.data.repository.impl

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.functions.FirebaseFunctions
import dev.rahier.colockitchenrace.data.model.*
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.util.Constants
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CKRGameRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val functions: FirebaseFunctions,
) : CKRGameRepository {

    private val _currentGame = MutableStateFlow<CKRGame?>(null)
    override val currentGame: StateFlow<CKRGame?> = _currentGame.asStateFlow()

    @Suppress("UNCHECKED_CAST")
    override suspend fun getLatest(): CKRGame? {
        val snapshot = firestore.collection(Constants.CKR_GAMES_COLLECTION)
            .orderBy("publishedTimestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        if (snapshot.documents.isEmpty()) return null

        val doc = snapshot.documents[0]
        val data = doc.data ?: return null
        val game = mapToGame(data, doc.id)
        _currentGame.value = game
        return game
    }

    override suspend fun registerForGame(
        gameId: String,
        cohouseId: String,
        attendingUserIds: List<String>,
        averageAge: Int,
        cohouseType: String,
        paymentIntentId: String?,
    ) {
        val params = hashMapOf<String, Any?>(
            "gameId" to gameId,
            "cohouseId" to cohouseId,
            "attendingUserIds" to attendingUserIds,
            "averageAge" to averageAge,
            "cohouseType" to cohouseType,
            "paymentIntentId" to paymentIntentId,
        )
        functions.getHttpsCallable("registerForGame").call(params).await()
    }

    @Suppress("UNCHECKED_CAST")
    override suspend fun getMyPlanning(gameId: String, cohouseId: String): CKRMyPlanning {
        val result = functions.getHttpsCallable("getMyPlanning")
            .call(hashMapOf("gameId" to gameId, "cohouseId" to cohouseId))
            .await()

        val data = result.getData() as Map<String, Any>
        val planning = data["planning"] as Map<String, Any>
        val aperoData = planning["apero"] as Map<String, Any>
        val dinerData = planning["diner"] as Map<String, Any>
        val partyData = planning["party"] as Map<String, Any>

        return CKRMyPlanning(
            apero = mapToPlanningStep(aperoData),
            diner = mapToPlanningStep(dinerData),
            party = PartyInfo(
                name = partyData["name"] as? String ?: "",
                address = partyData["address"] as? String ?: "",
                startTime = parseISODate(partyData["startTime"] as? String),
                endTime = parseISODate(partyData["endTime"] as? String),
                note = partyData["note"] as? String,
            ),
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun mapToPlanningStep(data: Map<String, Any>): PlanningStep = PlanningStep(
        role = if (data["role"] == "host") StepRole.HOST else StepRole.VISITOR,
        cohouseName = data["cohouseName"] as? String ?: "",
        address = data["address"] as? String ?: "",
        hostPhone = data["hostPhone"] as? String,
        visitorPhone = data["visitorPhone"] as? String,
        totalPeople = (data["totalPeople"] as? Number)?.toInt() ?: 0,
        dietarySummary = (data["dietarySummary"] as? Map<String, Any>)
            ?.mapValues { (it.value as? Number)?.toInt() ?: 0 } ?: emptyMap(),
        startTime = parseISODate(data["startTime"] as? String),
        endTime = parseISODate(data["endTime"] as? String),
    )

    private fun parseISODate(isoString: String?): Date {
        if (isoString == null) return Date()
        return try {
            val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
            fmt.timeZone = java.util.TimeZone.getTimeZone("UTC")
            fmt.parse(isoString) ?: Date()
        } catch (_: Exception) { Date() }
    }

    @Suppress("UNCHECKED_CAST")
    companion object {
        fun mapToGame(data: Map<String, Any?>, docId: String): CKRGame {
            fun toDate(value: Any?): Date = when (value) {
                is Timestamp -> value.toDate()
                is Date -> value
                else -> Date()
            }

            val matchedGroups = (data["matchedGroups"] as? List<Map<String, Any>>)?.map {
                MatchedGroup(cohouseIds = it["cohouseIds"] as? List<String> ?: emptyList())
            }

            val eventSettings = (data["eventSettings"] as? Map<String, Any>)?.let {
                CKREventSettings(
                    aperoStartTime = toDate(it["aperoStartTime"]),
                    aperoEndTime = toDate(it["aperoEndTime"]),
                    dinerStartTime = toDate(it["dinerStartTime"]),
                    dinerEndTime = toDate(it["dinerEndTime"]),
                    partyStartTime = toDate(it["partyStartTime"]),
                    partyEndTime = toDate(it["partyEndTime"]),
                    partyAddress = it["partyAddress"] as? String ?: "",
                    partyName = it["partyName"] as? String ?: "",
                    partyNote = it["partyNote"] as? String,
                )
            }

            val groupPlannings = (data["groupPlannings"] as? List<Map<String, Any>>)?.map {
                GroupPlanning(
                    id = it["id"] as? String ?: "",
                    groupIndex = (it["groupIndex"] as? Number)?.toInt() ?: 0,
                    cohouseA = it["cohouseA"] as? String ?: "",
                    cohouseB = it["cohouseB"] as? String ?: "",
                    cohouseC = it["cohouseC"] as? String ?: "",
                    cohouseD = it["cohouseD"] as? String ?: "",
                )
            }

            return CKRGame(
                id = data["id"] as? String ?: docId,
                editionNumber = (data["editionNumber"] as? Number)?.toInt() ?: 1,
                startCKRCountdown = toDate(data["startCKRCountdown"]),
                nextGameDate = toDate(data["nextGameDate"]),
                registrationDeadline = toDate(data["registrationDeadline"]),
                maxParticipants = (data["maxParticipants"] as? Number)?.toInt() ?: 100,
                pricePerPersonCents = (data["pricePerPersonCents"] as? Number)?.toInt() ?: 500,
                publishedTimestamp = toDate(data["publishedTimestamp"]),
                cohouseIDs = data["cohouseIDs"] as? List<String> ?: emptyList(),
                totalRegisteredParticipants = (data["totalRegisteredParticipants"] as? Number)?.toInt() ?: 0,
                matchedGroups = matchedGroups,
                matchedAt = (data["matchedAt"] as? Timestamp)?.toDate(),
                eventSettings = eventSettings,
                groupPlannings = groupPlannings,
                isRevealed = data["isRevealed"] as? Boolean ?: false,
                revealedAt = (data["revealedAt"] as? Timestamp)?.toDate(),
            )
        }
    }
}
