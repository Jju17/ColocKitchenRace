package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class CohouseTest {

    @Test
    fun `totalUsers returns user count`() {
        val cohouse = Cohouse(
            users = listOf(
                CohouseUser(id = "cu1", surname = "Alice"),
                CohouseUser(id = "cu2", surname = "Bob"),
            )
        )
        assertEquals(2, cohouse.totalUsers)
    }

    @Test
    fun `totalUsers returns 0 for empty list`() {
        val cohouse = Cohouse(users = emptyList())
        assertEquals(0, cohouse.totalUsers)
    }

    @Test
    fun `isAdmin returns true for admin user`() {
        val cohouse = Cohouse(
            users = listOf(
                CohouseUser(id = "cu1", userId = "u1", isAdmin = true),
                CohouseUser(id = "cu2", userId = "u2", isAdmin = false),
            )
        )
        assertTrue(cohouse.isAdmin("u1"))
    }

    @Test
    fun `isAdmin returns false for non-admin user`() {
        val cohouse = Cohouse(
            users = listOf(CohouseUser(id = "cu1", userId = "u1", isAdmin = false))
        )
        assertFalse(cohouse.isAdmin("u1"))
    }

    @Test
    fun `isAdmin returns false for null userId`() {
        val cohouse = Cohouse(
            users = listOf(CohouseUser(id = "cu1", userId = "u1", isAdmin = true))
        )
        assertFalse(cohouse.isAdmin(null))
    }

    @Test
    fun `isAdmin returns false for unknown user`() {
        val cohouse = Cohouse(
            users = listOf(CohouseUser(id = "cu1", userId = "u1", isAdmin = true))
        )
        assertFalse(cohouse.isAdmin("unknown"))
    }
}
