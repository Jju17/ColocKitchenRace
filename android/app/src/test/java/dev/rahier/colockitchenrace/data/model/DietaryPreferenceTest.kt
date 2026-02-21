package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class DietaryPreferenceTest {

    @Test
    fun `fromFirestore maps correctly`() {
        assertEquals(DietaryPreference.VEGETARIAN, DietaryPreference.fromFirestore("vegetarian"))
        assertEquals(DietaryPreference.VEGAN, DietaryPreference.fromFirestore("vegan"))
        assertEquals(DietaryPreference.GLUTEN_FREE, DietaryPreference.fromFirestore("glutenFree"))
        assertEquals(DietaryPreference.LACTOSE_FREE, DietaryPreference.fromFirestore("lactoseFree"))
        assertEquals(DietaryPreference.NUT_FREE, DietaryPreference.fromFirestore("nutFree"))
    }

    @Test
    fun `fromFirestore returns null for unknown`() {
        assertNull(DietaryPreference.fromFirestore("unknown"))
    }

    @Test
    fun `toFirestore maps correctly`() {
        assertEquals("vegetarian", DietaryPreference.VEGETARIAN.toFirestore())
        assertEquals("vegan", DietaryPreference.VEGAN.toFirestore())
        assertEquals("glutenFree", DietaryPreference.GLUTEN_FREE.toFirestore())
        assertEquals("lactoseFree", DietaryPreference.LACTOSE_FREE.toFirestore())
        assertEquals("nutFree", DietaryPreference.NUT_FREE.toFirestore())
    }

    @Test
    fun `roundtrip fromFirestore and toFirestore`() {
        DietaryPreference.entries.forEach { pref ->
            assertEquals(pref, DietaryPreference.fromFirestore(pref.toFirestore()))
        }
    }

    @Test
    fun `displayName is not blank`() {
        DietaryPreference.entries.forEach { pref ->
            assertTrue(pref.displayName.isNotBlank())
        }
    }
}
