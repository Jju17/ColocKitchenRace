package dev.rahier.colockitchenrace.ui.theme

import androidx.compose.ui.graphics.Color

// Primary Colors
val CkrMint = Color(0xFF3BBF7A)
val CkrSky = Color(0xFF4AADCF)
val CkrLavender = Color(0xFF8B7FC7)
val CkrCoral = Color(0xFFE07A6B)
val CkrGold = Color(0xFFD4A843)
val CkrNavy = Color(0xFF2C3A6E)

// Light Colors (backgrounds & cards)
val CkrMintLight = Color(0xFFC8FFD5)
val CkrSkyLight = Color(0xFFD4F1FF)
val CkrLavenderLight = Color(0xFFE8D5FF)
val CkrCoralLight = Color(0xFFFFD9D2)
val CkrGoldLight = Color(0xFFFFF3C4)

// Neutral Colors
val CkrWhite = Color(0xFFFFFFFF)
val CkrOffWhite = Color(0xFFF7F8FA)
val CkrDark = Color(0xFF1A1F2E)
val CkrGray = Color(0xFF6B7280)

// Event type colors
fun eventColor(type: String): Color = when (type) {
    "apero" -> CkrCoral
    "diner" -> CkrMint
    "party" -> CkrLavender
    else -> CkrSky
}

fun eventColorLight(type: String): Color = when (type) {
    "apero" -> CkrCoralLight
    "diner" -> CkrMintLight
    "party" -> CkrLavenderLight
    else -> CkrSkyLight
}
