package dev.rahier.colocskitchenrace.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp

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

private val CKRShapes = Shapes(
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(15.dp),
    large = RoundedCornerShape(20.dp),
    extraLarge = RoundedCornerShape(28.dp),
)

@Composable
fun CKRTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = CKRColorScheme,
        typography = CKRTypography,
        shapes = CKRShapes,
        content = content,
    )
}
