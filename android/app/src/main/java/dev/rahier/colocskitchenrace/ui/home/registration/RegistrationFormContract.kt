package dev.rahier.colocskitchenrace.ui.home.registration

import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.CohouseType
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

data class RegistrationFormState(
    val game: CKRGame? = null,
    val cohouse: Cohouse? = null,
    val selectedUserIds: Set<String> = emptySet(),
    val averageAge: String = "",
    val cohouseType: CohouseType = CohouseType.MIXED,
    val isLoading: Boolean = false,
) {
    val participants: List<CohouseUser>
        get() = cohouse?.users ?: emptyList()

    val selectedCount: Int
        get() = selectedUserIds.size

    val totalPriceCents: Int
        get() = selectedCount * (game?.pricePerPersonCents ?: 0)

    val formattedTotal: String
        get() {
            val euros = totalPriceCents / 100.0
            val formatter = NumberFormat.getCurrencyInstance(Locale("fr", "BE"))
            formatter.currency = Currency.getInstance("EUR")
            return formatter.format(euros)
        }

    val canContinue: Boolean
        get() = selectedCount > 0 && averageAge.isNotBlank()
}

sealed interface RegistrationFormIntent {
    data class ToggleUser(val userId: String) : RegistrationFormIntent
    data class AverageAgeChanged(val age: String) : RegistrationFormIntent
    data class CohouseTypeChanged(val type: CohouseType) : RegistrationFormIntent
    data object ContinueToPayment : RegistrationFormIntent
}

sealed interface RegistrationFormEffect {
    data class NavigateToPayment(
        val gameId: String,
        val cohouseId: String,
        val attendingUserIds: List<String>,
        val averageAge: Int,
        val cohouseType: String,
        val totalPriceCents: Int,
        val participantCount: Int,
    ) : RegistrationFormEffect
    data class ShowError(val message: String) : RegistrationFormEffect
}
