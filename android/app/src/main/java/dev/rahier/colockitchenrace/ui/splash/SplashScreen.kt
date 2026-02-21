package dev.rahier.colockitchenrace.ui.splash

import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import dev.rahier.colockitchenrace.ui.theme.CkrLavender

@Composable
fun SplashScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Colocs\nKitchen Race",
            style = MaterialTheme.typography.displayLarge,
            textAlign = TextAlign.Center,
            color = CkrLavender,
        )
    }
}
