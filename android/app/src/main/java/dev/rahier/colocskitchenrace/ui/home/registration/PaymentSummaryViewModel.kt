package dev.rahier.colocskitchenrace.ui.home.registration

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colocskitchenrace.data.repository.StripeRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
import dev.rahier.colocskitchenrace.util.ErrorMapper
import javax.inject.Inject

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

sealed class PaymentSummaryIntent {
    data class Initialize(
        val gameId: String,
        val cohouseId: String,
        val attendingUserIds: List<String>,
        val averageAge: Int,
        val cohouseType: String,
        val totalPriceCents: Int,
        val participantCount: Int,
    ) : PaymentSummaryIntent()
    data object PayClicked : PaymentSummaryIntent()
    data object PaymentSucceeded : PaymentSummaryIntent()
    data class PaymentFailed(val error: String) : PaymentSummaryIntent()
    data object RetryPayment : PaymentSummaryIntent()
}

sealed class PaymentSummaryEffect {
    data class PresentPaymentSheet(
        val clientSecret: String,
        val customerId: String,
        val ephemeralKeySecret: String,
    ) : PaymentSummaryEffect()
    data object RegistrationComplete : PaymentSummaryEffect()
}

@HiltViewModel
class PaymentSummaryViewModel @Inject constructor(
    private val stripeRepository: StripeRepository,
    private val gameRepository: CKRGameRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(PaymentSummaryState())
    val state: StateFlow<PaymentSummaryState> = _state.asStateFlow()

    private val _effect = Channel<PaymentSummaryEffect>()
    val effect = _effect.receiveAsFlow()

    fun onIntent(intent: PaymentSummaryIntent) {
        when (intent) {
            is PaymentSummaryIntent.Initialize -> initialize(intent)
            PaymentSummaryIntent.PayClicked -> pay()
            PaymentSummaryIntent.PaymentSucceeded -> onPaymentSucceeded()
            is PaymentSummaryIntent.PaymentFailed -> _state.update { it.copy(error = intent.error, isCreatingPaymentIntent = false) }
            PaymentSummaryIntent.RetryPayment -> pay()
        }
    }

    private fun initialize(intent: PaymentSummaryIntent.Initialize) {
        _state.update {
            it.copy(
                gameId = intent.gameId,
                cohouseId = intent.cohouseId,
                attendingUserIds = intent.attendingUserIds,
                averageAge = intent.averageAge,
                cohouseType = intent.cohouseType,
                totalPriceCents = intent.totalPriceCents,
                participantCount = intent.participantCount,
            )
        }
        reserveAndCreatePayment()
    }

    private fun reserveAndCreatePayment() {
        val s = _state.value
        viewModelScope.launch {
            _state.update { it.copy(isCreatingPaymentIntent = true, error = null) }
            try {
                val result = stripeRepository.reserveAndCreatePayment(
                    gameId = s.gameId,
                    cohouseId = s.cohouseId,
                    amountCents = s.totalPriceCents,
                    participantCount = s.participantCount,
                    attendingUserIds = s.attendingUserIds,
                    averageAge = s.averageAge,
                    cohouseType = s.cohouseType,
                )
                _state.update { it.copy(paymentResult = result, isCreatingPaymentIntent = false) }
            } catch (e: Exception) {
                _state.update { it.copy(error = ErrorMapper.toUserMessage(e, "Erreur lors de la réservation"), isCreatingPaymentIntent = false) }
            }
        }
    }

    private fun pay() {
        val result = _state.value.paymentResult
        if (result == null) {
            reserveAndCreatePayment()
            return
        }
        viewModelScope.launch {
            _effect.send(
                PaymentSummaryEffect.PresentPaymentSheet(
                    clientSecret = result.clientSecret,
                    customerId = result.customerId,
                    ephemeralKeySecret = result.ephemeralKeySecret,
                )
            )
        }
    }

    private fun onPaymentSucceeded() {
        val s = _state.value
        val paymentIntentId = s.paymentResult?.paymentIntentId
        if (paymentIntentId == null) {
            _state.update { it.copy(error = "Erreur: identifiant de paiement manquant") }
            return
        }
        viewModelScope.launch {
            _state.update { it.copy(isConfirming = true, error = null) }
            try {
                gameRepository.confirmRegistration(
                    gameId = s.gameId,
                    cohouseId = s.cohouseId,
                    paymentIntentId = paymentIntentId,
                )
                _state.update { it.copy(isConfirming = false, registrationComplete = true) }
                _effect.send(PaymentSummaryEffect.RegistrationComplete)
            } catch (e: Exception) {
                _state.update { it.copy(isConfirming = false, error = "Paiement reussi mais confirmation echouee. Reessayez.") }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        val s = _state.value
        if (s.paymentResult != null && !s.registrationComplete) {
            // Optimistically update local state so home screen
            // immediately reflects "not registered".
            gameRepository.removeCohouseLocally(s.cohouseId)

            // Use an independent scope so the cancellation request outlives
            // this ViewModel (viewModelScope is already cancelled in onCleared).
            // SupervisorJob prevents failure propagation from child coroutines.
            CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                try {
                    gameRepository.cancelReservation(s.gameId, s.cohouseId)
                } catch (e: Exception) {
                    Log.e("PaymentSummary", "Failed to cancel reservation", e)
                }
            }
        }
    }
}
