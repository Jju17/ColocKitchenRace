package dev.rahier.colockitchenrace.ui.home

import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.News
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import dev.rahier.colockitchenrace.data.repository.NewsRepository
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
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var gameRepository: CKRGameRepository
    private lateinit var cohouseRepository: CohouseRepository
    private lateinit var newsRepository: NewsRepository
    private lateinit var authRepository: AuthRepository

    private val gameFlow = MutableStateFlow<CKRGame?>(null)
    private val cohouseFlow = MutableStateFlow<Cohouse?>(null)

    @Before
    fun setup() {
        gameRepository = mockk(relaxed = true)
        cohouseRepository = mockk(relaxed = true)
        newsRepository = mockk(relaxed = true)
        authRepository = mockk(relaxed = true)

        every { gameRepository.currentGame } returns gameFlow
        every { cohouseRepository.currentCohouse } returns cohouseFlow
        coEvery { newsRepository.getLatest() } returns emptyList()
    }

    private fun createViewModel() = HomeViewModel(gameRepository, cohouseRepository, newsRepository, authRepository)

    @Test
    fun `initial state is empty`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        val state = viewModel.state.value
        assertNull(state.game)
        assertNull(state.cohouse)
        assertTrue(state.news.isEmpty())
        assertFalse(state.isRegistered)
    }

    @Test
    fun `game update reflects in state`() = runTest {
        val viewModel = createViewModel()
        val game = CKRGame(editionNumber = 3, totalRegisteredParticipants = 42)
        gameFlow.value = game
        advanceUntilIdle()

        assertEquals(3, viewModel.state.value.game?.editionNumber)
        assertEquals(42, viewModel.state.value.game?.totalRegisteredParticipants)
    }

    @Test
    fun `cohouse update reflects in state`() = runTest {
        val viewModel = createViewModel()
        val cohouse = Cohouse(name = "Test Coloc")
        cohouseFlow.value = cohouse
        advanceUntilIdle()

        assertEquals("Test Coloc", viewModel.state.value.cohouse?.name)
    }

    @Test
    fun `isRegistered true when cohouse is in game cohouseIDs`() = runTest {
        val cohouse = Cohouse(id = "cohouse-1", name = "My Coloc")
        val game = CKRGame(cohouseIDs = listOf("cohouse-1", "cohouse-2"))

        cohouseFlow.value = cohouse
        gameFlow.value = game

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertTrue(viewModel.state.value.isRegistered)
    }

    @Test
    fun `isRegistered false when cohouse not in game cohouseIDs`() = runTest {
        val cohouse = Cohouse(id = "cohouse-3", name = "My Coloc")
        val game = CKRGame(cohouseIDs = listOf("cohouse-1", "cohouse-2"))

        cohouseFlow.value = cohouse
        gameFlow.value = game

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertFalse(viewModel.state.value.isRegistered)
    }

    @Test
    fun `news loaded on init`() = runTest {
        val news = listOf(
            News(id = "1", title = "Title 1", body = "Body 1"),
            News(id = "2", title = "Title 2", body = "Body 2"),
        )
        coEvery { newsRepository.getLatest() } returns news

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals(2, viewModel.state.value.news.size)
        assertEquals("Title 1", viewModel.state.value.news[0].title)
    }

    @Test
    fun `news error does not crash`() = runTest {
        coEvery { newsRepository.getLatest() } throws Exception("Network error")

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertTrue(viewModel.state.value.news.isEmpty())
    }
}
