package dev.rahier.colockitchenrace.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object DateUtils {
    val BRUSSELS_TZ: TimeZone = TimeZone.getTimeZone("Europe/Brussels")
    private val brusselsTimeZone = BRUSSELS_TZ

    fun formatTime(date: Date): String {
        val fmt = SimpleDateFormat("HH'h'mm", Locale.FRANCE)
        fmt.timeZone = brusselsTimeZone
        return fmt.format(date)
    }

    fun formatDate(date: Date): String {
        val fmt = SimpleDateFormat("d MMMM yyyy", Locale.FRANCE)
        fmt.timeZone = brusselsTimeZone
        return fmt.format(date)
    }

    fun formatDateTime(date: Date): String {
        val fmt = SimpleDateFormat("d MMMM yyyy 'a' HH'h'mm", Locale.FRANCE)
        fmt.timeZone = brusselsTimeZone
        return fmt.format(date)
    }

    fun formatTimeRange(start: Date, end: Date): String {
        return "${formatTime(start)} - ${formatTime(end)}"
    }
}
