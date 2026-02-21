package dev.rahier.colockitchenrace.ui.planning

import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.CKRMyPlanning
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import io.mockk.coEvery
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
class PlanningViewModelTest {

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

    private fun createViewModel() = PlanningViewModel(gameRepository, cohouseRepository)

    @Test
    fun `initial state has no planning`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.planning)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `no game returns early`() = runTest {
        cohouseFlow.value = Cohouse(id = "c1")
        // game is null

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.planning)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `unrevealed game returns early`() = runTest {
        gameFlow.value = CKRGame(id = "g1", isRevealed = false, cohouseIDs = listOf("c1"))
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.planning)
    }

    @Test
    fun `cohouse not in game returns early`() = runTest {
        gameFlow.value = CKRGame(id = "g1", isRevealed = true, cohouseIDs = listOf("other"))
        cohouseFlow.value = Cohouse(id = "c1")

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.planning)
    }

    @Test
    fun `loads planning when game revealed and cohouse registered`() = runTest {
        val planning = mockk<CKRMyPlanning>()
        gameFlow.value = CKRGame(id = "g1", isRevealed = true, cohouseIDs = listOf("c1"))
        cohouseFlow.value = Cohouse(id = "c1")
        coEvery { gameRepository.getMyPlanning("g1", "c1") } returns planning

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals(planning, viewModel.state.value.planning)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `loading error sets error state`() = runTest {
        gameFlow.value = CKRGame(id = "g1", isRevealed = true, cohouseIDs = listOf("c1"))
        cohouseFlow.value = Cohouse(id = "c1")
        coEvery { gameRepository.getMyPlanning(any(), any()) } throws Exception("Network error")

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals("Network error", viewModel.state.value.error)
        assertFalse(viewModel.state.value.isLoading)
    }
}
