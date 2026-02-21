package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class UserTest {

    @Test
    fun `fullName combines first and last`() {
        val user = User(firstName = "Alice", lastName = "Dupont")
        assertEquals("Alice Dupont", user.fullName)
    }

    @Test
    fun `isEmailEditable true for email auth`() {
        val user = User(authProvider = AuthProvider.EMAIL)
        assertTrue(user.isEmailEditable)
    }

    @Test
    fun `isEmailEditable true for null auth`() {
        val user = User(authProvider = null)
        assertTrue(user.isEmailEditable)
    }

    @Test
    fun `isEmailEditable false for Google auth`() {
        val user = User(authProvider = AuthProvider.GOOGLE)
        assertFalse(user.isEmailEditable)
    }

    @Test
    fun `isEmailEditable false for Apple auth`() {
        val user = User(authProvider = AuthProvider.APPLE)
        assertFalse(user.isEmailEditable)
    }

    @Test
    fun `needsProfileCompletion true when firstName blank`() {
        val user = User(firstName = "", lastName = "Dupont", phoneNumber = "+32 123")
        assertTrue(user.needsProfileCompletion)
    }

    @Test
    fun `needsProfileCompletion true when phone null`() {
        val user = User(firstName = "Alice", lastName = "Dupont", phoneNumber = null)
        assertTrue(user.needsProfileCompletion)
    }

    @Test
    fun `needsProfileCompletion false when all filled`() {
        val user = User(firstName = "Alice", lastName = "Dupont", phoneNumber = "+32 123")
        assertFalse(user.needsProfileCompletion)
    }

    @Test
    fun `toCohouseUser creates CohouseUser with correct data`() {
        val user = User(id = "u1", firstName = "Alice", lastName = "Dupont")
        val cohouseUser = user.toCohouseUser(cohouseUserId = "cu1", isAdmin = true)

        assertEquals("cu1", cohouseUser.id)
        assertTrue(cohouseUser.isAdmin)
        assertEquals("Alice Dupont", cohouseUser.surname)
        assertEquals("u1", cohouseUser.userId)
    }

    @Test
    fun `EMPTY has default values`() {
        val user = User.EMPTY
        assertEquals("", user.firstName)
        assertEquals("", user.lastName)
        assertFalse(user.isAdmin)
    }
}
