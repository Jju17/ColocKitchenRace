package dev.rahier.colockitchenrace.ui.challenges

import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.*
import dev.rahier.colockitchenrace.data.repository.ChallengeRepository
import dev.rahier.colockitchenrace.data.repository.ChallengeResponseRepository
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
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class ChallengesViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var challengeRepository: ChallengeRepository
    private lateinit var responseRepository: ChallengeResponseRepository
    private lateinit var cohouseRepository: CohouseRepository

    private val cohouseFlow = MutableStateFlow<Cohouse?>(null)

    private fun futureDate(): Date {
        val cal = Calendar.getInstance()
        cal.add(Calendar.MONTH, 1)
        return cal.time
    }

    private fun pastDate(): Date {
        val cal = Calendar.getInstance()
        cal.add(Calendar.MONTH, -1)
        return cal.time
    }

    @Before
    fun setup() {
        challengeRepository = mockk(relaxed = true)
        responseRepository = mockk(relaxed = true)
        cohouseRepository = mockk(relaxed = true)
        every { cohouseRepository.currentCohouse } returns cohouseFlow
    }

    private fun createViewModel() = ChallengesViewModel(challengeRepository, responseRepository, cohouseRepository)

    @Test
    fun `initial state has ALL filter`() = runTest {
        coEvery { challengeRepository.getAll() } returns emptyList()
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals(ChallengeFilter.ALL, viewModel.state.value.selectedFilter)
    }

    @Test
    fun `challenges loaded on init`() = runTest {
        val challenges = listOf(
            Challenge(id = "1", title = "Challenge 1", startDate = pastDate(), endDate = futureDate()),
            Challenge(id = "2", title = "Challenge 2", startDate = pastDate(), endDate = futureDate()),
        )
        coEvery { challengeRepository.getAll() } returns challenges

        val viewModel = createViewModel()
        advanceUntilIdle()

        assertEquals(2, viewModel.state.value.challenges.size)
    }

    @Test
    fun `filter selection updates state`() = runTest {
        coEvery { challengeRepository.getAll() } returns emptyList()
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(ChallengesIntent.FilterSelected(ChallengeFilter.TODO))
        assertEquals(ChallengeFilter.TODO, viewModel.state.value.selectedFilter)
    }

    @Test
    fun `TODO filter shows only ongoing challenges without responses`() = runTest {
        val ongoingChallenge = Challenge(id = "1", title = "Ongoing", startDate = pastDate(), endDate = futureDate())
        val respondedChallenge = Challenge(id = "2", title = "Responded", startDate = pastDate(), endDate = futureDate())
        val doneChallenge = Challenge(id = "3", title = "Done", startDate = pastDate(), endDate = pastDate())

        val responses = listOf(
            ChallengeResponse(challengeId = "2", cohouseId = "c1", status = ChallengeResponseStatus.WAITING),
        )

        coEvery { challengeRepository.getAll() } returns listOf(ongoingChallenge, respondedChallenge, doneChallenge)
        cohouseFlow.value = Cohouse(id = "c1")
        coEvery { responseRepository.getAllForCohouse("c1") } returns responses

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(ChallengesIntent.FilterSelected(ChallengeFilter.TODO))

        val filtered = viewModel.state.value.filteredChallenges
        assertEquals(1, filtered.size)
        assertEquals("Ongoing", filtered[0].title)
    }

    @Test
    fun `WAITING filter shows challenges with waiting responses`() = runTest {
        val challenge1 = Challenge(id = "1", title = "C1", startDate = pastDate(), endDate = futureDate())
        val challenge2 = Challenge(id = "2", title = "C2", startDate = pastDate(), endDate = futureDate())

        val responses = listOf(
            ChallengeResponse(challengeId = "1", cohouseId = "c1", status = ChallengeResponseStatus.WAITING),
            ChallengeResponse(challengeId = "2", cohouseId = "c1", status = ChallengeResponseStatus.VALIDATED),
        )

        coEvery { challengeRepository.getAll() } returns listOf(challenge1, challenge2)
        cohouseFlow.value = Cohouse(id = "c1")
        coEvery { responseRepository.getAllForCohouse("c1") } returns responses

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(ChallengesIntent.FilterSelected(ChallengeFilter.WAITING))

        val filtered = viewModel.state.value.filteredChallenges
        assertEquals(1, filtered.size)
        assertEquals("C1", filtered[0].title)
    }

    @Test
    fun `REVIEWED filter shows validated or invalidated responses`() = runTest {
        val challenge1 = Challenge(id = "1", title = "C1", startDate = pastDate(), endDate = futureDate())
        val challenge2 = Challenge(id = "2", title = "C2", startDate = pastDate(), endDate = futureDate())

        val responses = listOf(
            ChallengeResponse(challengeId = "1", cohouseId = "c1", status = ChallengeResponseStatus.WAITING),
            ChallengeResponse(challengeId = "2", cohouseId = "c1", status = ChallengeResponseStatus.VALIDATED),
        )

        coEvery { challengeRepository.getAll() } returns listOf(challenge1, challenge2)
        cohouseFlow.value = Cohouse(id = "c1")
        coEvery { responseRepository.getAllForCohouse("c1") } returns responses

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(ChallengesIntent.FilterSelected(ChallengeFilter.REVIEWED))

        val filtered = viewModel.state.value.filteredChallenges
        assertEquals(1, filtered.size)
        assertEquals("C2", filtered[0].title)
    }

    @Test
    fun `hasCohouse updated when cohouse changes`() = runTest {
        coEvery { challengeRepository.getAll() } returns emptyList()
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertFalse(viewModel.state.value.hasCohouse)

        cohouseFlow.value = Cohouse(id = "c1")
        advanceUntilIdle()

        assertTrue(viewModel.state.value.hasCohouse)
    }
}
