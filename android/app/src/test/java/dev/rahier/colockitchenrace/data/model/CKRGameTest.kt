package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.Date

class CKRGameTest {

    private fun futureDate(daysFromNow: Int): Date {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, daysFromNow)
        return cal.time
    }

    private fun pastDate(daysAgo: Int): Date {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, -daysAgo)
        return cal.time
    }

    @Test
    fun `isRegistrationOpen true when before deadline and spots available`() {
        val game = CKRGame(
            registrationDeadline = futureDate(30),
            maxParticipants = 100,
            totalRegisteredParticipants = 50,
        )
        assertTrue(game.isRegistrationOpen)
    }

    @Test
    fun `isRegistrationOpen false when past deadline`() {
        val game = CKRGame(
            registrationDeadline = pastDate(1),
            maxParticipants = 100,
            totalRegisteredParticipants = 50,
        )
        assertFalse(game.isRegistrationOpen)
    }

    @Test
    fun `isRegistrationOpen false when full`() {
        val game = CKRGame(
            registrationDeadline = futureDate(30),
            maxParticipants = 100,
            totalRegisteredParticipants = 100,
        )
        assertFalse(game.isRegistrationOpen)
    }

    @Test
    fun `remainingSpots computed correctly`() {
        val game = CKRGame(maxParticipants = 100, totalRegisteredParticipants = 48)
        assertEquals(52, game.remainingSpots)
    }

    @Test
    fun `remainingSpots never negative`() {
        val game = CKRGame(maxParticipants = 100, totalRegisteredParticipants = 150)
        assertEquals(0, game.remainingSpots)
    }

    @Test
    fun `hasCountdownStarted true when past start date`() {
        val game = CKRGame(startCKRCountdown = pastDate(1))
        assertTrue(game.hasCountdownStarted)
    }

    @Test
    fun `hasCountdownStarted false when before start date`() {
        val game = CKRGame(startCKRCountdown = futureDate(30))
        assertFalse(game.hasCountdownStarted)
    }

    @Test
    fun `formattedPricePerPerson formats as EUR`() {
        val game = CKRGame(pricePerPersonCents = 500)
        val formatted = game.formattedPricePerPerson
        assertTrue(formatted.contains("5"))
    }
}
