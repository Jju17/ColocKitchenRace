package dev.rahier.colockitchenrace.data.repository

data class PaymentIntentResult(
    val clientSecret: String,
    val customerId: String,
    val ephemeralKeySecret: String,
    val paymentIntentId: String,
)

interface StripeRepository {
    suspend fun createPaymentIntent(
        gameId: String,
        cohouseId: String,
        amountCents: Int,
        participantCount: Int,
    ): PaymentIntentResult
}
