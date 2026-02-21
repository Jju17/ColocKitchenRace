package dev.rahier.colockitchenrace.data.model

import java.text.NumberFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

data class MatchedGroup(
    val cohouseIds: List<String> = emptyList(),
)

data class CKREventSettings(
    val aperoStartTime: Date = Date(),
    val aperoEndTime: Date = Date(),
    val dinerStartTime: Date = Date(),
    val dinerEndTime: Date = Date(),
    val partyStartTime: Date = Date(),
    val partyEndTime: Date = Date(),
    val partyAddress: String = "",
    val partyName: String = "",
    val partyNote: String? = null,
)

data class GroupPlanning(
    val id: String = UUID.randomUUID().toString(),
    val groupIndex: Int = 0,
    val cohouseA: String = "",
    val cohouseB: String = "",
    val cohouseC: String = "",
    val cohouseD: String = "",
)

data class CKRGame(
    val id: String = UUID.randomUUID().toString(),
    val editionNumber: Int = 1,
    val startCKRCountdown: Date = Date(),
    val nextGameDate: Date = Date(),
    val registrationDeadline: Date = Date(),
    val maxParticipants: Int = 100,
    val pricePerPersonCents: Int = 500,
    val publishedTimestamp: Date = Date(),
    val cohouseIDs: List<String> = emptyList(),
    val totalRegisteredParticipants: Int = 0,
    val matchedGroups: List<MatchedGroup>? = null,
    val matchedAt: Date? = null,
    val eventSettings: CKREventSettings? = null,
    val groupPlannings: List<GroupPlanning>? = null,
    val isRevealed: Boolean = false,
    val revealedAt: Date? = null,
) {
    val isRegistrationOpen: Boolean
        get() = Date().before(registrationDeadline) && totalRegisteredParticipants < maxParticipants

    val remainingSpots: Int
        get() = maxOf(0, maxParticipants - totalRegisteredParticipants)

    val hasCountdownStarted: Boolean
        get() = Date().after(startCKRCountdown) || Date() == startCKRCountdown

    val formattedPricePerPerson: String
        get() {
            val euros = pricePerPersonCents / 100.0
            val formatter = NumberFormat.getCurrencyInstance(Locale("fr", "BE"))
            formatter.currency = java.util.Currency.getInstance("EUR")
            return formatter.format(euros)
        }
}
