package dev.rahier.colocskitchenrace.ui.home.registration

import dev.rahier.colocskitchenrace.data.repository.PaymentIntentResult
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

data class PaymentSummaryState(
    val gameId: String = "",
    val cohouseId: String = "",
    val attendingUserIds: List<String> = emptyList(),
    val averageAge: Int = 0,
    val cohouseType: String = "",
    val totalPriceCents: Int = 0,
    val participantCount: Int = 0,
    val isCreatingPaymentIntent: Boolean = false,
    val isConfirming: Boolean = false,
    val paymentResult: PaymentIntentResult? = null,
    val error: String? = null,
    val registrationComplete: Boolean = false,
) {
    val formattedTotal: String
        get() {
            val euros = totalPriceCents / 100.0
            val formatter = NumberFormat.getCurrencyInstance(Locale("fr", "BE"))
            formatter.currency = Currency.getInstance("EUR")
            return formatter.format(euros)
        }

    val formattedPricePerPerson: String
        get() {
            if (participantCount == 0) return ""
            val euros = (totalPriceCents / participantCount) / 100.0
            val formatter = NumberFormat.getCurrencyInstance(Locale("fr", "BE"))
            formatter.currency = Currency.getInstance("EUR")
            return formatter.format(euros)
        }
}

sealed interface PaymentSummaryIntent {
    data class Initialize(
        val gameId: String,
        val cohouseId: String,
        val attendingUserIds: List<String>,
        val averageAge: Int,
        val cohouseType: String,
        val totalPriceCents: Int,
        val participantCount: Int,
    ) : PaymentSummaryIntent
    data object PayClicked : PaymentSummaryIntent
    data object PaymentSucceeded : PaymentSummaryIntent
    data class PaymentFailed(val error: String) : PaymentSummaryIntent
    data object RetryPayment : PaymentSummaryIntent
}

sealed interface PaymentSummaryEffect {
    data class PresentPaymentSheet(
        val clientSecret: String,
        val customerId: String,
        val ephemeralKeySecret: String,
    ) : PaymentSummaryEffect
    data object RegistrationComplete : PaymentSummaryEffect
}
