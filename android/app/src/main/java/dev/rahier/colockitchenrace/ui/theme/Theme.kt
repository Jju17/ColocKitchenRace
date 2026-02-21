package dev.rahier.colockitchenrace.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val CKRColorScheme = lightColorScheme(
    primary = CkrLavender,
    onPrimary = CkrWhite,
    primaryContainer = CkrLavenderLight,
    onPrimaryContainer = CkrDark,
    secondary = CkrMint,
    onSecondary = CkrWhite,
    secondaryContainer = CkrMintLight,
    onSecondaryContainer = CkrDark,
    tertiary = CkrCoral,
    onTertiary = CkrWhite,
    tertiaryContainer = CkrCoralLight,
    onTertiaryContainer = CkrDark,
    background = CkrOffWhite,
    onBackground = CkrDark,
    surface = CkrWhite,
    onSurface = CkrDark,
    surfaceVariant = CkrOffWhite,
    onSurfaceVariant = CkrGray,
    outline = CkrGray,
)

@Composable
fun CKRTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = CKRColorScheme,
        typography = CKRTypography,
        content = content,
    )
}
