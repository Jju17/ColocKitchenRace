package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class PostalAddressTest {

    @Test
    fun `formatted combines all fields`() {
        val address = PostalAddress(
            street = "42 Rue de la Loi",
            city = "Bruxelles",
            postalCode = "1000",
            country = "Belgique",
        )
        assertEquals("42 Rue de la Loi, 1000 Bruxelles, Belgique", address.formatted)
    }

    @Test
    fun `formatted skips blank fields`() {
        val address = PostalAddress(
            street = "42 Rue de la Loi",
            city = "",
            postalCode = "",
            country = "Belgique",
        )
        assertEquals("42 Rue de la Loi, Belgique", address.formatted)
    }

    @Test
    fun `lowercased trims and lowercases all fields`() {
        val address = PostalAddress(
            street = "  42 Rue De La Loi  ",
            city = " Bruxelles ",
            postalCode = " 1000 ",
            country = " Belgique ",
        )
        val result = address.lowercased
        assertEquals("42 rue de la loi", result.street)
        assertEquals("bruxelles", result.city)
        assertEquals("1000", result.postalCode)
        assertEquals("belgique", result.country)
    }

    @Test
    fun `default country is Belgique`() {
        val address = PostalAddress(street = "Test")
        assertEquals("Belgique", address.country)
    }
}
