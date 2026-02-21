package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class CohouseTypeTest {

    @Test
    fun `fromFirestore maps correctly`() {
        assertEquals(CohouseType.MIXED, CohouseType.fromFirestore("mixed"))
        assertEquals(CohouseType.GIRLS, CohouseType.fromFirestore("girls"))
        assertEquals(CohouseType.BOYS, CohouseType.fromFirestore("boys"))
    }

    @Test
    fun `fromFirestore returns null for unknown`() {
        assertNull(CohouseType.fromFirestore("unknown"))
    }

    @Test
    fun `toFirestore maps correctly`() {
        assertEquals("mixed", CohouseType.MIXED.toFirestore())
        assertEquals("girls", CohouseType.GIRLS.toFirestore())
        assertEquals("boys", CohouseType.BOYS.toFirestore())
    }

    @Test
    fun `roundtrip fromFirestore and toFirestore`() {
        CohouseType.entries.forEach { type ->
            assertEquals(type, CohouseType.fromFirestore(type.toFirestore()))
        }
    }
}
