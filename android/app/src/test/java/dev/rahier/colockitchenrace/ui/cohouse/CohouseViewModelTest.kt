package dev.rahier.colockitchenrace.ui.cohouse

import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import io.mockk.coEvery
import io.mockk.coVerify
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
class CohouseViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var cohouseRepository: CohouseRepository
    private lateinit var authRepository: AuthRepository

    private val cohouseFlow = MutableStateFlow<Cohouse?>(null)

    @Before
    fun setup() {
        cohouseRepository = mockk(relaxed = true)
        authRepository = mockk(relaxed = true)
        every { cohouseRepository.currentCohouse } returns cohouseFlow
        every { authRepository.currentUser } returns MutableStateFlow(User(id = "u1"))
    }

    private fun createViewModel() = CohouseViewModel(cohouseRepository, authRepository)

    @Test
    fun `initial state has no cohouse`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.cohouse)
        assertEquals("", viewModel.state.value.joinCode)
    }

    @Test
    fun `cohouse flow updates state`() = runTest {
        val viewModel = createViewModel()
        cohouseFlow.value = Cohouse(id = "c1", name = "La Coloc")
        advanceUntilIdle()

        assertEquals("La Coloc", viewModel.state.value.cohouse?.name)
    }

    @Test
    fun `join code changed updates state`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(CohouseIntent.JoinCodeChanged("ABC123"))
        assertEquals("ABC123", viewModel.state.value.joinCode)
    }

    @Test
    fun `join with blank code does nothing`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(CohouseIntent.JoinCodeChanged("   "))
        viewModel.onIntent(CohouseIntent.JoinClicked)
        advanceUntilIdle()

        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `join with valid code calls repository`() = runTest {
        val cohouse = Cohouse(id = "c1", name = "Found Coloc")
        coEvery { cohouseRepository.getByCode("ABC") } returns cohouse

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(CohouseIntent.JoinCodeChanged("ABC"))
        viewModel.onIntent(CohouseIntent.JoinClicked)
        advanceUntilIdle()

        coVerify { cohouseRepository.getByCode("ABC") }
        coVerify { cohouseRepository.setCurrentCohouse(cohouse) }
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `join with invalid code shows error`() = runTest {
        coEvery { cohouseRepository.getByCode(any()) } throws Exception("Not found")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(CohouseIntent.JoinCodeChanged("INVALID"))
        viewModel.onIntent(CohouseIntent.JoinClicked)
        advanceUntilIdle()

        assertEquals("Code invalide ou coloc introuvable", viewModel.state.value.error)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `quit cohouse calls repository`() = runTest {
        cohouseFlow.value = Cohouse(id = "c1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(CohouseIntent.QuitClicked)
        advanceUntilIdle()

        coVerify { cohouseRepository.quitCohouse() }
    }
}
