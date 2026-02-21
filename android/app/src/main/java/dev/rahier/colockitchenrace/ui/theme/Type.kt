package dev.rahier.colockitchenrace.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import dev.rahier.colockitchenrace.R

val BaksoSapi = FontFamily(
    Font(R.font.baksosapi, FontWeight.Normal)
)

val CKRTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 45.sp,
    ),
    displayMedium = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 36.sp,
    ),
    displaySmall = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 28.sp,
    ),
    headlineLarge = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 26.sp,
    ),
    headlineMedium = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 22.sp,
    ),
    headlineSmall = TextStyle(
        fontFamily = BaksoSapi,
        fontSize = 18.sp,
    ),
    titleLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 20.sp,
    ),
    titleMedium = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
    ),
    titleSmall = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
    ),
    bodyLarge = TextStyle(
        fontSize = 17.sp,
    ),
    bodyMedium = TextStyle(
        fontSize = 14.sp,
    ),
    bodySmall = TextStyle(
        fontSize = 12.sp,
    ),
    labelLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 17.sp,
    ),
    labelMedium = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
    ),
    labelSmall = TextStyle(
        fontSize = 12.sp,
    ),
)
