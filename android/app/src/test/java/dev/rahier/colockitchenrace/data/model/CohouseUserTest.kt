package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class CohouseUserTest {

    @Test
    fun `isAssignedToRealUser true when userId not null`() {
        val user = CohouseUser(userId = "u1")
        assertTrue(user.isAssignedToRealUser)
    }

    @Test
    fun `isAssignedToRealUser false when userId null`() {
        val user = CohouseUser(userId = null)
        assertFalse(user.isAssignedToRealUser)
    }
}
