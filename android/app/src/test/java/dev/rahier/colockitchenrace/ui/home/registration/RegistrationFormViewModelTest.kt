package dev.rahier.colockitchenrace.ui.home.registration

import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.CohouseType
import dev.rahier.colockitchenrace.data.model.CohouseUser
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RegistrationFormViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var gameRepository: CKRGameRepository
    private lateinit var cohouseRepository: CohouseRepository

    private val gameFlow = MutableStateFlow<CKRGame?>(null)
    private val cohouseFlow = MutableStateFlow<Cohouse?>(null)

    @Before
    fun setup() {
        gameRepository = mockk(relaxed = true)
        cohouseRepository = mockk(relaxed = true)
        every { gameRepository.currentGame } returns gameFlow
        every { cohouseRepository.currentCohouse } returns cohouseFlow
    }

    private fun createViewModel() = RegistrationFormViewModel(gameRepository, cohouseRepository)

    @Test
    fun `initial state loads game and cohouse`() = runTest {
        val game = CKRGame(id = "g1", pricePerPersonCents = 500)
        val cohouse = Cohouse(
            id = "c1",
            cohouseType = CohouseType.GIRLS,
            users = listOf(CohouseUser(id = "cu1", surname = "Alice"))
        )
        gameFlow.value = game
        cohouseFlow.value = cohouse

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals("g1", viewModel.state.value.game?.id)
        assertEquals("c1", viewModel.state.value.cohouse?.id)
        assertEquals(CohouseType.GIRLS, viewModel.state.value.cohouseType)
    }

    @Test
    fun `toggle user selects and deselects`() = runTest {
        gameFlow.value = CKRGame(id = "g1")
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(RegistrationFormIntent.ToggleUser("u1"))
        assertTrue("u1" in viewModel.state.value.selectedUserIds)

        viewModel.onIntent(RegistrationFormIntent.ToggleUser("u1"))
        assertFalse("u1" in viewModel.state.value.selectedUserIds)
    }

    @Test
    fun `average age changed updates state`() = runTest {
        gameFlow.value = CKRGame(id = "g1")
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(RegistrationFormIntent.AverageAgeChanged("25"))
        assertEquals("25", viewModel.state.value.averageAge)
    }

    @Test
    fun `total price computed from selected users and game price`() = runTest {
        gameFlow.value = CKRGame(id = "g1", pricePerPersonCents = 500)
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(RegistrationFormIntent.ToggleUser("u1"))
        viewModel.onIntent(RegistrationFormIntent.ToggleUser("u2"))
        assertEquals(1000, viewModel.state.value.totalPriceCents)
    }

    @Test
    fun `canContinue requires selected users and average age`() = runTest {
        gameFlow.value = CKRGame(id = "g1")
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertFalse(viewModel.state.value.canContinue)

        viewModel.onIntent(RegistrationFormIntent.ToggleUser("u1"))
        assertFalse(viewModel.state.value.canContinue)

        viewModel.onIntent(RegistrationFormIntent.AverageAgeChanged("22"))
        assertTrue(viewModel.state.value.canContinue)
    }

    @Test
    fun `cohouse type changed updates state`() = runTest {
        gameFlow.value = CKRGame(id = "g1")
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(RegistrationFormIntent.CohouseTypeChanged(CohouseType.BOYS))
        assertEquals(CohouseType.BOYS, viewModel.state.value.cohouseType)
    }
}
