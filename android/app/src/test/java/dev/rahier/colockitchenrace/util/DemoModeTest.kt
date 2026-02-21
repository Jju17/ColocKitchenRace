package dev.rahier.colockitchenrace.util

import dev.rahier.colockitchenrace.data.model.ChallengeResponseStatus
import org.junit.Assert.*
import org.junit.After
import org.junit.Test

class DemoModeTest {

    @After
    fun tearDown() {
        DemoMode.deactivate()
    }

    @Test
    fun `initially inactive`() {
        assertFalse(DemoMode.isActive)
    }

    @Test
    fun `activate and deactivate`() {
        DemoMode.activate()
        assertTrue(DemoMode.isActive)

        DemoMode.deactivate()
        assertFalse(DemoMode.isActive)
    }

    @Test
    fun `demo email is correct`() {
        assertEquals("test_apple@colocskitchenrace.be", DemoMode.DEMO_EMAIL)
    }

    @Test
    fun `demo cohouse has valid data`() {
        val cohouse = DemoMode.demoCohouse
        assertEquals(DemoMode.DEMO_COHOUSE_ID, cohouse.id)
        assertEquals("La Coloc du Soleil", cohouse.name)
        assertNotNull(cohouse.address)
        assertTrue(cohouse.code.isNotBlank())
        assertTrue(cohouse.users.isNotEmpty())
    }

    @Test
    fun `demo cohouse has 3 users`() {
        assertEquals(3, DemoMode.demoCohouseUsers.size)
        assertTrue(DemoMode.demoCohouseUsers[0].isAdmin)
        assertFalse(DemoMode.demoCohouseUsers[1].isAdmin)
    }

    @Test
    fun `demo game has valid data`() {
        val game = DemoMode.demoCKRGame
        assertEquals(DemoMode.DEMO_GAME_ID, game.id)
        assertEquals(3, game.editionNumber)
        assertTrue(game.pricePerPersonCents > 0)
        assertTrue(game.maxParticipants > 0)
        assertTrue(game.isRevealed)
        assertNotNull(game.eventSettings)
        assertNotNull(game.matchedGroups)
    }

    @Test
    fun `demo planning has all steps`() {
        val planning = DemoMode.demoPlanning
        assertNotNull(planning.apero)
        assertNotNull(planning.diner)
        assertNotNull(planning.party)
    }

    @Test
    fun `demo news has items`() {
        val news = DemoMode.demoNews
        assertEquals(3, news.size)
        assertTrue(news.all { it.title.isNotBlank() })
    }

    @Test
    fun `demo challenges has items`() {
        val challenges = DemoMode.demoChallenges
        assertEquals(5, challenges.size)
        assertTrue(challenges.all { it.title.isNotBlank() })
        assertTrue(challenges.all { (it.points ?: 0) > 0 })
    }

    @Test
    fun `demo challenge responses reference valid challenge ids`() {
        val challengeIds = DemoMode.demoChallenges.map { it.id }.toSet()
        val responses = DemoMode.demoChallengeResponses

        assertEquals(3, responses.size)
        responses.forEach { response ->
            assertTrue(
                "Response ${response.id} references unknown challenge ${response.challengeId}",
                response.challengeId in challengeIds
            )
            assertEquals(DemoMode.DEMO_COHOUSE_ID, response.cohouseId)
        }
    }

    @Test
    fun `demo has validated and waiting responses`() {
        val responses = DemoMode.demoChallengeResponses
        assertTrue(responses.any { it.status == ChallengeResponseStatus.VALIDATED })
        assertTrue(responses.any { it.status == ChallengeResponseStatus.WAITING })
    }
}
