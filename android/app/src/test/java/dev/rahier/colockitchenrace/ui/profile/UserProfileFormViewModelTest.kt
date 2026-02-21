package dev.rahier.colockitchenrace.ui.profile

import app.cash.turbine.test
import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.DietaryPreference
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.AuthRepository
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
class UserProfileFormViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var authRepository: AuthRepository
    private val userFlow = MutableStateFlow<User?>(null)

    @Before
    fun setup() {
        authRepository = mockk(relaxed = true)
        every { authRepository.currentUser } returns userFlow
    }

    private fun createViewModel(): UserProfileFormViewModel {
        return UserProfileFormViewModel(authRepository)
    }

    @Test
    fun `loads user data on init`() = runTest {
        val user = User(
            id = "u1",
            firstName = "Alice",
            lastName = "Dupont",
            email = "alice@test.com",
            phoneNumber = "+32 470 123456",
            dietaryPreferences = setOf(DietaryPreference.VEGAN),
            isSubscribeToNews = true,
        )
        userFlow.value = user

        val viewModel = createViewModel()
        advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals("Alice", state.firstName)
        assertEquals("Dupont", state.lastName)
        assertEquals("alice@test.com", state.email)
        assertEquals("+32 470 123456", state.phoneNumber)
        assertTrue(DietaryPreference.VEGAN in state.dietaryPreferences)
        assertTrue(state.isSubscribeToNews)
    }

    @Test
    fun `first name changed updates state`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileFormIntent.FirstNameChanged("Bob"))
        assertEquals("Bob", viewModel.state.value.firstName)
    }

    @Test
    fun `last name changed updates state`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileFormIntent.LastNameChanged("Martin"))
        assertEquals("Martin", viewModel.state.value.lastName)
    }

    @Test
    fun `toggle dietary preference adds then removes`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileFormIntent.ToggleDietaryPreference(DietaryPreference.GLUTEN_FREE))
        assertTrue(DietaryPreference.GLUTEN_FREE in viewModel.state.value.dietaryPreferences)

        viewModel.onIntent(UserProfileFormIntent.ToggleDietaryPreference(DietaryPreference.GLUTEN_FREE))
        assertFalse(DietaryPreference.GLUTEN_FREE in viewModel.state.value.dietaryPreferences)
    }

    @Test
    fun `canSave requires first and last name`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        assertFalse(viewModel.state.value.canSave)

        viewModel.onIntent(UserProfileFormIntent.FirstNameChanged("Alice"))
        assertFalse(viewModel.state.value.canSave)

        viewModel.onIntent(UserProfileFormIntent.LastNameChanged("Dupont"))
        assertTrue(viewModel.state.value.canSave)
    }

    @Test
    fun `save calls repository and emits effect`() = runTest {
        val user = User(id = "u1", firstName = "Alice", lastName = "Dupont")
        userFlow.value = user
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.effect.test {
            viewModel.onIntent(UserProfileFormIntent.Save)
            advanceUntilIdle()
            assertEquals(UserProfileFormEffect.Saved, awaitItem())
        }

        coVerify { authRepository.updateUser(any()) }
    }

    @Test
    fun `save with blank name does nothing`() = runTest {
        userFlow.value = User(id = "u1")
        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileFormIntent.Save)
        advanceUntilIdle()

        assertFalse(viewModel.state.value.isSaving)
    }

    @Test
    fun `save error sets error message`() = runTest {
        val user = User(id = "u1", firstName = "Alice", lastName = "Dupont")
        userFlow.value = user
        coEvery { authRepository.updateUser(any()) } throws Exception("Network error")

        val viewModel = createViewModel()
        advanceUntilIdle()

        viewModel.onIntent(UserProfileFormIntent.Save)
        advanceUntilIdle()

        assertEquals("Network error", viewModel.state.value.error)
        assertFalse(viewModel.state.value.isSaving)
    }
}
