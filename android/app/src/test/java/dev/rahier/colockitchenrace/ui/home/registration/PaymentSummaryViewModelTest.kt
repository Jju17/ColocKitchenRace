package dev.rahier.colockitchenrace.ui.home.registration

import app.cash.turbine.test
import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.PaymentIntentResult
import dev.rahier.colockitchenrace.data.repository.StripeRepository
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
    }

    private fun createViewModel() = PaymentSummaryViewModel(stripeRepository, gameRepository)

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
    fun `initialize sets state and creates payment intent`() = runTest {
        coEvery { stripeRepository.createPaymentIntent(any(), any(), any(), any()) } returns paymentResult

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
    fun `payment intent creation error sets error`() = runTest {
        coEvery { stripeRepository.createPaymentIntent(any(), any(), any(), any()) } throws Exception("Stripe error")

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        assertNotNull(viewModel.state.value.error)
        assertFalse(viewModel.state.value.isCreatingPaymentIntent)
    }

    @Test
    fun `pay clicked emits present payment sheet effect`() = runTest {
        coEvery { stripeRepository.createPaymentIntent(any(), any(), any(), any()) } returns paymentResult

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
    fun `payment succeeded registers for game`() = runTest {
        coEvery { stripeRepository.createPaymentIntent(any(), any(), any(), any()) } returns paymentResult

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded)
            advanceUntilIdle()
            assertEquals(PaymentSummaryEffect.RegistrationComplete, awaitItem())
        }

        coVerify {
            gameRepository.registerForGame(
                gameId = "g1",
                cohouseId = "c1",
                attendingUserIds = listOf("u1", "u2"),
                averageAge = 25,
                cohouseType = "mixed",
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
    fun `registration error after payment shows specific message`() = runTest {
        coEvery { stripeRepository.createPaymentIntent(any(), any(), any(), any()) } returns paymentResult
        coEvery { gameRepository.registerForGame(any(), any(), any(), any(), any(), any()) } throws Exception("fail")

        val viewModel = createViewModel()
        viewModel.onIntent(initIntent())
        advanceUntilIdle()

        viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded)
        advanceUntilIdle()

        assertEquals("Paiement reussi mais erreur d'inscription. Reessayez.", viewModel.state.value.error)
        assertFalse(viewModel.state.value.isRegistering)
    }
}
