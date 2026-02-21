package dev.rahier.colockitchenrace.ui.auth.signin

import app.cash.turbine.test
import dev.rahier.colockitchenrace.MainDispatcherRule
import dev.rahier.colockitchenrace.data.model.User
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.impl.NoAccountException
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SignInViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var authRepository: AuthRepository
    private lateinit var viewModel: SignInViewModel

    @Before
    fun setup() {
        authRepository = mockk(relaxed = true)
        every { authRepository.currentUser } returns MutableStateFlow(null)
        every { authRepository.isLoggedIn } returns flowOf(false)
        viewModel = SignInViewModel(authRepository)
    }

    @Test
    fun `initial state is empty`() {
        val state = viewModel.state.value
        assertEquals("", state.email)
        assertEquals("", state.password)
        assertFalse(state.isLoading)
        assertNull(state.errorMessage)
        assertFalse(state.showCreateAccountDialog)
    }

    @Test
    fun `email changed updates state`() {
        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        assertEquals("test@test.com", viewModel.state.value.email)
    }

    @Test
    fun `password changed updates state`() {
        viewModel.onIntent(SignInIntent.PasswordChanged("secret"))
        assertEquals("secret", viewModel.state.value.password)
    }

    @Test
    fun `sign in with empty fields shows error`() {
        viewModel.onIntent(SignInIntent.SignInClicked)
        assertEquals("Veuillez remplir tous les champs", viewModel.state.value.errorMessage)
    }

    @Test
    fun `sign in with email only shows error`() {
        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.SignInClicked)
        assertEquals("Veuillez remplir tous les champs", viewModel.state.value.errorMessage)
    }

    @Test
    fun `successful sign in navigates to main`() = runTest {
        val user = User(firstName = "John", lastName = "Doe", phoneNumber = "+32123")
        coEvery { authRepository.signIn(any(), any()) } returns user
        every { authRepository.isEmailVerified() } returns true

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))

        viewModel.effect.test {
            viewModel.onIntent(SignInIntent.SignInClicked)
            advanceUntilIdle()

            assertEquals(SignInEffect.NavigateToMain, awaitItem())
        }

        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `sign in with unverified email navigates to verification`() = runTest {
        val user = User(firstName = "John", lastName = "Doe", phoneNumber = "+32123")
        coEvery { authRepository.signIn(any(), any()) } returns user
        every { authRepository.isEmailVerified() } returns false

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))

        viewModel.effect.test {
            viewModel.onIntent(SignInIntent.SignInClicked)
            advanceUntilIdle()

            assertEquals(SignInEffect.NavigateToEmailVerification, awaitItem())
        }
    }

    @Test
    fun `sign in with incomplete profile navigates to profile completion`() = runTest {
        val user = User(firstName = "", lastName = "", phoneNumber = null) // needsProfileCompletion = true
        coEvery { authRepository.signIn(any(), any()) } returns user
        every { authRepository.isEmailVerified() } returns true

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))

        viewModel.effect.test {
            viewModel.onIntent(SignInIntent.SignInClicked)
            advanceUntilIdle()

            assertEquals(SignInEffect.NavigateToProfileCompletion, awaitItem())
        }
    }

    @Test
    fun `no account exception shows create dialog`() = runTest {
        coEvery { authRepository.signIn(any(), any()) } throws NoAccountException("test@test.com")

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))
        viewModel.onIntent(SignInIntent.SignInClicked)
        advanceUntilIdle()

        assertTrue(viewModel.state.value.showCreateAccountDialog)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `generic error shows error message`() = runTest {
        coEvery { authRepository.signIn(any(), any()) } throws Exception("Auth failed")

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))
        viewModel.onIntent(SignInIntent.SignInClicked)
        advanceUntilIdle()

        assertEquals("Auth failed", viewModel.state.value.errorMessage)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun `dismiss error clears error`() {
        viewModel.onIntent(SignInIntent.SignInClicked) // triggers empty fields error
        assertNotNull(viewModel.state.value.errorMessage)

        viewModel.onIntent(SignInIntent.DismissError)
        assertNull(viewModel.state.value.errorMessage)
    }

    @Test
    fun `create account confirmed calls repository and navigates`() = runTest {
        val user = User()
        coEvery { authRepository.createAccount(any(), any()) } returns user

        viewModel.onIntent(SignInIntent.EmailChanged("test@test.com"))
        viewModel.onIntent(SignInIntent.PasswordChanged("password"))

        viewModel.effect.test {
            viewModel.onIntent(SignInIntent.CreateAccountConfirmed)
            advanceUntilIdle()

            assertEquals(SignInEffect.NavigateToEmailVerification, awaitItem())
        }

        coVerify { authRepository.createAccount("test@test.com", "password") }
        assertFalse(viewModel.state.value.showCreateAccountDialog)
    }

    @Test
    fun `create account dismissed hides dialog`() {
        viewModel.onIntent(SignInIntent.CreateAccountDismissed)
        assertFalse(viewModel.state.value.showCreateAccountDialog)
    }
}
