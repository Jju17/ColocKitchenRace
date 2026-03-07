package dev.rahier.colocskitchenrace.ui.home.registration

import app.cash.turbine.test
import dev.rahier.colocskitchenrace.MainDispatcherRule
import android.content.Context
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colocskitchenrace.data.repository.StripeRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaymentSummaryViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var stripeRepository: StripeRepository
    private lateinit var gameRepository: CKRGameRepository
    private lateinit var context: Context

    private val paymentResult = PaymentIntentResult(
        clientSecret = "secret_123",
        customerId = "cus_123",
        ephemeralKeySecret = "ek_123",
        paymentIntentId = "pi_123",
    )

    @Before
    fun setup() {
        stripeRepository = mockk(relaxed = true)
        gameRepository = mockk(relaxed = true)
        context = mockk(relaxed = true)
    }

    private fun createViewModel() = PaymentSummaryViewModel(stripeRepository, gameRepository, context)

    private fun initIntent() = PaymentSummaryIntent.Initialize(
        gameId = "g1",
        cohouseId = "c1",
        attendingUserIds = listOf("u1", "u2"),
        averageAge = 25,
        cohouseType = "mixed",
        totalPriceCents = 1000,
        participantCount = 2,
    )

    @Test
    fun `initialize sets state and reserves payment`() = runTest {
        coEvery { stripeRepository.reserveAndCreatePayment(any(), any(), any(), any(), any(), any(), any()) } returns paymentResult

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals("g1", state.gameId)
        assertEquals("c1", state.cohouseId)
        assertEquals(2, state.participantCount)
        assertEquals(1000, state.totalPriceCents)
        assertNotNull(state.paymentResult)
        assertFalse(state.isCreatingPaymentIntent)
    }

    @Test
    fun `reserve and create payment error sets error`() = runTest {
        coEvery { stripeRepository.reserveAndCreatePayment(any(), any(), any(), any(), any(), any(), any()) } throws Exception("Stripe error")

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        assertNotNull(viewModel.state.value.error)
        assertFalse(viewModel.state.value.isCreatingPaymentIntent)
    }

    @Test
    fun `pay clicked emits present payment sheet effect`() = runTest {
        coEvery { stripeRepository.reserveAndCreatePayment(any(), any(), any(), any(), any(), any(), any()) } returns paymentResult

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(PaymentSummaryIntent.PayClicked)
            val effect = awaitItem()
            assertTrue(effect is PaymentSummaryEffect.PresentPaymentSheet)
            val sheet = effect as PaymentSummaryEffect.PresentPaymentSheet
            assertEquals("secret_123", sheet.clientSecret)
        }
    }

    @Test
    fun `payment succeeded confirms registration`() = runTest {
        coEvery { stripeRepository.reserveAndCreatePayment(any(), any(), any(), any(), any(), any(), any()) } returns paymentResult

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded)
            advanceUntilIdle()
            assertEquals(PaymentSummaryEffect.RegistrationComplete, awaitItem())
        }

        coVerify {
            gameRepository.confirmRegistration(
                gameId = "g1",
                cohouseId = "c1",
                paymentIntentId = "pi_123",
            )
        }
        assertTrue(viewModel.state.value.registrationComplete)
    }

    @Test
    fun `payment failed sets error`() = runTest {
        val viewModel = createViewModel()
        viewModel.onIntent(PaymentSummaryIntent.PaymentFailed("Card declined"))

        assertEquals("Card declined", viewModel.state.value.error)
    }

    @Test
    fun `confirmation error after payment shows specific message`() = runTest {
        coEvery { stripeRepository.reserveAndCreatePayment(any(), any(), any(), any(), any(), any(), any()) } returns paymentResult
        coEvery { gameRepository.confirmRegistration(any(), any(), any()) } throws Exception("fail")

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded)
        advanceUntilIdle()

        assertNotNull(viewModel.state.value.error)
        assertFalse(viewModel.state.value.isConfirming)
    }
}
