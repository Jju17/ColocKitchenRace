package dev.rahier.colocskitchenrace.ui.home.registration

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colocskitchenrace.data.repository.StripeRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlin.coroutines.cancellation.CancellationException
import javax.inject.Inject

@HiltViewModel
class PaymentSummaryViewModel @Inject constructor(
    private val stripeRepository: StripeRepository,
    private val gameRepository: CKRGameRepository,
    @ApplicationContext private val context: Context,
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
                _state.update { it.copy(error = ErrorMapper.toUserMessage(e, context), isCreatingPaymentIntent = false) }
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
            _state.update { it.copy(error = context.getString(R.string.error_payment_id_missing)) }
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
                _state.update { it.copy(isConfirming = false, error = ErrorMapper.toUserMessage(e, context)) }
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

            // GlobalScope is intentional: viewModelScope is already cancelled in onCleared,
            // but we must still notify the backend to release the reserved spot. This fire-and-forget
            // call is acceptable because the backend also has a TTL-based cleanup (Cloud Task).
            @OptIn(kotlinx.coroutines.DelicateCoroutinesApi::class)
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    gameRepository.cancelReservation(s.gameId, s.cohouseId)
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Log.e("PaymentSummary", "Failed to cancel reservation", e)
                }
            }
        }
    }
}
