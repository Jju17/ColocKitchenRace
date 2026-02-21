package dev.rahier.colockitchenrace.data.model

import org.junit.Assert.*
import org.junit.Test

class ChallengeContentTest {

    @Test
    fun `Picture type is picture`() {
        assertEquals("picture", ChallengeContent.Picture().type)
    }

    @Test
    fun `MultipleChoice type is multipleChoice`() {
        assertEquals("multipleChoice", ChallengeContent.MultipleChoice().type)
    }

    @Test
    fun `SingleAnswer type is singleAnswer`() {
        assertEquals("singleAnswer", ChallengeContent.SingleAnswer().type)
    }

    @Test
    fun `NoChoice type is noChoice`() {
        assertEquals("noChoice", ChallengeContent.NoChoice().type)
    }

    @Test
    fun `Picture toResponseContent returns Picture`() {
        val response = ChallengeContent.Picture().toResponseContent()
        assertTrue(response is ChallengeResponseContent.Picture)
    }

    @Test
    fun `MultipleChoice toResponseContent returns MultipleChoice`() {
        val response = ChallengeContent.MultipleChoice().toResponseContent()
        assertTrue(response is ChallengeResponseContent.MultipleChoice)
    }

    @Test
    fun `SingleAnswer toResponseContent returns SingleAnswer`() {
        val response = ChallengeContent.SingleAnswer().toResponseContent()
        assertTrue(response is ChallengeResponseContent.SingleAnswer)
    }

    @Test
    fun `NoChoice toResponseContent returns NoChoice`() {
        val response = ChallengeContent.NoChoice().toResponseContent()
        assertTrue(response is ChallengeResponseContent.NoChoice)
    }

    @Test
    fun `MultipleChoice default has 4 empty choices`() {
        val mc = ChallengeContent.MultipleChoice()
        assertEquals(4, mc.choices.size)
        assertTrue(mc.choices.all { it.isEmpty() })
        assertNull(mc.correctAnswerIndex)
        assertTrue(mc.shuffleAnswers)
    }
}
