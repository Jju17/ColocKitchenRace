package dev.rahier.colockitchenrace.ui.profile

import app.cash.turbine.test
import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class UserProfileViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var authRepository: AuthRepository
    private val userFlow = MutableStateFlow<User?>(null)

    @Before
    fun setup() {
        authRepository = mockk(relaxed = true)
        every { authRepository.currentUser } returns userFlow
    }

    private fun createViewModel() = UserProfileViewModel(authRepository)

    @Test
    fun `initial state has no user`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertNull(viewModel.state.value.user)
        assertFalse(viewModel.state.value.showDeleteConfirmation)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `user flow updates state`() = runTest {
        val viewModel = createViewModel()
        val user = User(id = "u1", firstName = "Alice", lastName = "Dupont")
        userFlow.value = user
        advanceUntilIdle()

        assertEquals("Alice", viewModel.state.value.user?.firstName)
    }

    @Test
    fun `sign out calls repository and emits effect`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(UserProfileIntent.SignOutClicked)
            assertEquals(UserProfileEffect.SignedOut, awaitItem())
        }

        verify { authRepository.signOut() }
    }

    @Test
    fun `delete account clicked shows confirmation`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileIntent.DeleteAccountClicked)
        assertTrue(viewModel.state.value.showDeleteConfirmation)
    }

    @Test
    fun `dismiss delete dialog hides confirmation`() = runTest {
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileIntent.DeleteAccountClicked)
        viewModel.onIntent(UserProfileIntent.DismissDeleteDialog)
        assertFalse(viewModel.state.value.showDeleteConfirmation)
    }

    @Test
    fun `confirm delete calls repository`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(UserProfileIntent.ConfirmDelete)
            advanceUntilIdle()
            assertEquals(UserProfileEffect.SignedOut, awaitItem())
        }

        coVerify { authRepository.deleteAccount("u1") }
    }

    @Test
    fun `confirm delete with error stops loading`() = runTest {
        userFlow.value = User(id = "u1")
        coEvery { authRepository.deleteAccount(any()) } throws Exception("fail")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileIntent.ConfirmDelete)
        advanceUntilIdle()

        assertFalse(viewModel.state.value.isLoading)
    }
}
