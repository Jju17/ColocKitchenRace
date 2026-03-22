package dev.rahier.colocskitchenrace.data.model

import dev.rahier.colocskitchenrace.ui.home.HomeState
import org.junit.Assert.*
import org.junit.Test

class EditionModelTest {

    // MARK: - CKRGame multi-edition fields

    @Test
    fun `CKRGame defaults to global edition type`() {
        val game = CKRGame()
        assertEquals(CKREditionType.GLOBAL, game.editionType)
    }

    @Test
    fun `CKRGame defaults to published status`() {
        val game = CKRGame()
        assertEquals(CKRGameStatus.PUBLISHED, game.status)
    }

    @Test
    fun `CKRGame special edition fields`() {
        val game = CKRGame(
            editionType = CKREditionType.SPECIAL,
            title = "CKR de Julien",
            joinCode = "ABC123",
            createdByAuthUid = "auth-uid-1",
            status = CKRGameStatus.DRAFT,
        )
        assertEquals(CKREditionType.SPECIAL, game.editionType)
        assertEquals("CKR de Julien", game.title)
        assertEquals("ABC123", game.joinCode)
        assertEquals("auth-uid-1", game.createdByAuthUid)
        assertEquals(CKRGameStatus.DRAFT, game.status)
    }

    @Test
    fun `CKRGame joinCode defaults to null`() {
        val game = CKRGame()
        assertNull(game.joinCode)
    }

    @Test
    fun `CKRGame title defaults to null`() {
        val game = CKRGame()
        assertNull(game.title)
    }

    @Test
    fun `CKRGame createdByAuthUid defaults to null`() {
        val game = CKRGame()
        assertNull(game.createdByAuthUid)
    }

    @Test
    fun `CKRGame editionDescription defaults to null`() {
        val game = CKRGame()
        assertNull(game.editionDescription)
    }

    // MARK: - Challenge editionId

    @Test
    fun `Challenge editionId defaults to null`() {
        val challenge = Challenge(title = "Test")
        assertNull(challenge.editionId)
    }

    @Test
    fun `Challenge editionId can be set`() {
        val challenge = Challenge(title = "Test", editionId = "game-special-1")
        assertEquals("game-special-1", challenge.editionId)
    }

    @Test
    fun `Two challenges same id but different editionIds are not equal`() {
        val c1 = Challenge(id = "1", title = "T", editionId = null)
        val c2 = Challenge(id = "1", title = "T", editionId = "game-1")
        assertNotEquals(c1, c2)
    }

    // MARK: - User activeEditionId

    @Test
    fun `User activeEditionId defaults to null`() {
        val user = User()
        assertNull(user.activeEditionId)
    }

    @Test
    fun `User activeEditionId can be set`() {
        val user = User(activeEditionId = "game-special-1")
        assertEquals("game-special-1", user.activeEditionId)
    }

    // MARK: - HomeState edition fields

    @Test
    fun `HomeState hasActiveEdition false by default`() {
        val state = HomeState()
        assertFalse(state.hasActiveEdition)
    }

    @Test
    fun `HomeState hasActiveEdition true when activeEditionId set`() {
        val state = HomeState(activeEditionId = "game-1")
        assertTrue(state.hasActiveEdition)
    }

    @Test
    fun `HomeState edition loading defaults`() {
        val state = HomeState()
        assertFalse(state.isJoiningEdition)
        assertFalse(state.isLeavingEdition)
        assertNull(state.joinEditionError)
        assertNull(state.joinEditionSuccess)
        assertNull(state.activeEdition)
        assertEquals("", state.joinCode)
        assertFalse(state.isLoadingEdition)
    }

    // MARK: - Challenge filtering logic (pure function tests)

    @Test
    fun `global mode filters out challenges with editionId`() {
        val global1 = Challenge(id = "1", title = "Global 1", editionId = null)
        val global2 = Challenge(id = "2", title = "Global 2", editionId = null)
        val special = Challenge(id = "3", title = "Special", editionId = "game-1")

        val allChallenges = listOf(global1, global2, special)
        val activeEditionId: String? = null

        val filtered = filterChallengesByEdition(allChallenges, activeEditionId)

        assertEquals(2, filtered.size)
        assertTrue(filtered.all { it.editionId == null })
    }

    @Test
    fun `special edition mode shows only matching challenges`() {
        val global = Challenge(id = "1", title = "Global", editionId = null)
        val myEdition = Challenge(id = "2", title = "My Edition", editionId = "game-1")
        val otherEdition = Challenge(id = "3", title = "Other Edition", editionId = "game-2")

        val allChallenges = listOf(global, myEdition, otherEdition)

        val filtered = filterChallengesByEdition(allChallenges, "game-1")

        assertEquals(1, filtered.size)
        assertEquals("My Edition", filtered[0].title)
        assertEquals("game-1", filtered[0].editionId)
    }

    @Test
    fun `special edition with no matching challenges returns empty`() {
        val global = Challenge(id = "1", title = "Global", editionId = null)
        val other = Challenge(id = "2", title = "Other", editionId = "game-2")

        val allChallenges = listOf(global, other)

        val filtered = filterChallengesByEdition(allChallenges, "game-no-challenges")

        assertTrue(filtered.isEmpty())
    }

    @Test
    fun `all challenges belong to same edition`() {
        val c1 = Challenge(id = "1", title = "C1", editionId = "game-1")
        val c2 = Challenge(id = "2", title = "C2", editionId = "game-1")
        val c3 = Challenge(id = "3", title = "C3", editionId = "game-1")

        val filtered = filterChallengesByEdition(listOf(c1, c2, c3), "game-1")

        assertEquals(3, filtered.size)
    }

    @Test
    fun `global mode with all global challenges returns all`() {
        val c1 = Challenge(id = "1", title = "C1", editionId = null)
        val c2 = Challenge(id = "2", title = "C2", editionId = null)

        val filtered = filterChallengesByEdition(listOf(c1, c2), null)

        assertEquals(2, filtered.size)
    }

    @Test
    fun `empty challenges list returns empty`() {
        val filtered = filterChallengesByEdition(emptyList(), null)
        assertTrue(filtered.isEmpty())

        val filtered2 = filterChallengesByEdition(emptyList(), "game-1")
        assertTrue(filtered2.isEmpty())
    }

    // MARK: - CKREditionType enum values

    @Test
    fun `CKREditionType enum contains GLOBAL and SPECIAL`() {
        val values = CKREditionType.values()
        assertEquals(2, values.size)
        assertTrue(values.contains(CKREditionType.GLOBAL))
        assertTrue(values.contains(CKREditionType.SPECIAL))
    }

    @Test
    fun `CKRGameStatus enum contains DRAFT, PUBLISHED, and ARCHIVED`() {
        val values = CKRGameStatus.values()
        assertEquals(3, values.size)
        assertTrue(values.contains(CKRGameStatus.DRAFT))
        assertTrue(values.contains(CKRGameStatus.PUBLISHED))
        assertTrue(values.contains(CKRGameStatus.ARCHIVED))
    }

    // Helper: replicates the filtering logic used in ChallengesViewModel
    private fun filterChallengesByEdition(
        challenges: List<Challenge>,
        activeEditionId: String?,
    ): List<Challenge> {
        return challenges.filter { challenge ->
            if (activeEditionId != null) {
                challenge.editionId == activeEditionId
            } else {
                challenge.editionId == null
            }
        }
    }
}
