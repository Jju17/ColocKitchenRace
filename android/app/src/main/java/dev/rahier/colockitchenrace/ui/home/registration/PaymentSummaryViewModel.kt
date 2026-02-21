package dev.rahier.colockitchenrace.ui.home.registration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colockitchenrace.data.repository.StripeRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
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
    val isRegistering: Boolean = false,
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
        createPaymentIntent()
    }

    private fun createPaymentIntent() {
        val s = _state.value
        viewModelScope.launch {
            _state.update { it.copy(isCreatingPaymentIntent = true, error = null) }
            try {
                val result = stripeRepository.createPaymentIntent(
                    gameId = s.gameId,
                    cohouseId = s.cohouseId,
                    amountCents = s.totalPriceCents,
                    participantCount = s.participantCount,
                )
                _state.update { it.copy(paymentResult = result, isCreatingPaymentIntent = false) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "Erreur lors de la creation du paiement", isCreatingPaymentIntent = false) }
            }
        }
    }

    private fun pay() {
        val result = _state.value.paymentResult
        if (result == null) {
            createPaymentIntent()
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
        viewModelScope.launch {
            _state.update { it.copy(isRegistering = true, error = null) }
            try {
                gameRepository.registerForGame(
                    gameId = s.gameId,
                    cohouseId = s.cohouseId,
                    attendingUserIds = s.attendingUserIds,
                    averageAge = s.averageAge,
                    cohouseType = s.cohouseType,
                    paymentIntentId = s.paymentResult?.paymentIntentId,
                )
                _state.update { it.copy(isRegistering = false, registrationComplete = true) }
                _effect.send(PaymentSummaryEffect.RegistrationComplete)
            } catch (e: Exception) {
                _state.update { it.copy(isRegistering = false, error = "Paiement reussi mais erreur d'inscription. Reessayez.") }
            }
        }
    }
}
