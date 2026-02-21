package dev.rahier.colockitchenrace.util

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class DateUtilsTest {

    private fun dateOf(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) =
        Calendar.getInstance(DateUtils.BRUSSELS_TZ).apply {
            set(year, month - 1, day, hour, minute, 0)
            set(Calendar.MILLISECOND, 0)
        }.time

    @Test
    fun `formatTime returns HHhmm format`() {
        val date = dateOf(2026, 4, 15, 18, 30)
        assertEquals("18h30", DateUtils.formatTime(date))
    }

    @Test
    fun `formatTime midnight`() {
        val date = dateOf(2026, 4, 16, 0, 0)
        assertEquals("00h00", DateUtils.formatTime(date))
    }

    @Test
    fun `formatDate returns French date format`() {
        val date = dateOf(2026, 4, 15)
        val result = DateUtils.formatDate(date)
        assertTrue(result.contains("15"))
        assertTrue(result.contains("2026"))
        // April in French is "avril"
        assertTrue(result.lowercase().contains("avril"))
    }

    @Test
    fun `formatDateTime combines date and time`() {
        val date = dateOf(2026, 4, 15, 18, 30)
        val result = DateUtils.formatDateTime(date)
        assertTrue(result.contains("15"))
        assertTrue(result.contains("2026"))
        assertTrue(result.contains("18h30"))
    }

    @Test
    fun `formatTimeRange returns start - end`() {
        val start = dateOf(2026, 4, 15, 18, 0)
        val end = dateOf(2026, 4, 15, 20, 0)
        assertEquals("18h00 - 20h00", DateUtils.formatTimeRange(start, end))
    }

    @Test
    fun `BRUSSELS_TZ is Europe Brussels`() {
        assertEquals(TimeZone.getTimeZone("Europe/Brussels"), DateUtils.BRUSSELS_TZ)
    }
}
