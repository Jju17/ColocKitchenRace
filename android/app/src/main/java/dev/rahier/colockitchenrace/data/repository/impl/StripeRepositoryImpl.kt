package dev.rahier.colockitchenrace.data.repository.impl

import com.google.firebase.functions.FirebaseFunctions
import dev.rahier.colockitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colockitchenrace.data.repository.StripeRepository
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StripeRepositoryImpl @Inject constructor(
    private val functions: FirebaseFunctions,
) : StripeRepository {

    @Suppress("UNCHECKED_CAST")
    override suspend fun createPaymentIntent(
        gameId: String,
        cohouseId: String,
        amountCents: Int,
        participantCount: Int,
    ): PaymentIntentResult {
        val result = functions.getHttpsCallable("createPaymentIntent")
            .call(
                hashMapOf(
                    "gameId" to gameId,
                    "cohouseId" to cohouseId,
                    "amountCents" to amountCents,
                    "participantCount" to participantCount,
                )
            )
            .await()

        val data = result.getData() as Map<String, Any>
        return PaymentIntentResult(
            clientSecret = data["clientSecret"] as? String ?: "",
            customerId = data["customerId"] as? String ?: "",
            ephemeralKeySecret = data["ephemeralKeySecret"] as? String ?: "",
            paymentIntentId = data["paymentIntentId"] as? String ?: "",
        )
    }
}
