package dev.rahier.colocskitchenrace.util

import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object DateUtils {
    val BRUSSELS_TZ: TimeZone = TimeZone.getTimeZone("Europe/Brussels")
    private val brusselsZoneId: ZoneId = ZoneId.of("Europe/Brussels")

    private val timeFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("HH'h'mm", Locale.FRANCE)

    private val dateFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("d MMMM yyyy", Locale.FRANCE)

    private val dateTimeFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("d MMMM yyyy 'a' HH'h'mm", Locale.FRANCE)

    fun formatTime(date: Date): String {
        val zdt = ZonedDateTime.ofInstant(date.toInstant(), brusselsZoneId)
        return zdt.format(timeFormatter)
    }

    fun formatDate(date: Date): String {
        val zdt = ZonedDateTime.ofInstant(date.toInstant(), brusselsZoneId)
        return zdt.format(dateFormatter)
    }

    fun formatDateTime(date: Date): String {
        val zdt = ZonedDateTime.ofInstant(date.toInstant(), brusselsZoneId)
        return zdt.format(dateTimeFormatter)
    }

    fun formatTimeRange(start: Date, end: Date): String {
        return "${formatTime(start)} - ${formatTime(end)}"
    }
}
