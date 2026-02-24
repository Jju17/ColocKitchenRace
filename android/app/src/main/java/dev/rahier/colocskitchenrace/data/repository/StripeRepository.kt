package dev.rahier.colocskitchenrace.data.repository

data class PaymentIntentResult(
    val clientSecret: String,
    val customerId: String,
    val ephemeralKeySecret: String,
    val paymentIntentId: String,
)

interface StripeRepository {
    suspend fun reserveAndCreatePayment(
        gameId: String,
        cohouseId: String,
        amountCents: Int,
        participantCount: Int,
        attendingUserIds: List<String>,
        averageAge: Int,
        cohouseType: String,
    ): PaymentIntentResult
}
