package dev.rahier.colocskitchenrace.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * Wraps content in an error boundary that catches composition errors.
 * Shows a user-friendly error screen instead of crashing the app.
 */
@Composable
fun ErrorBoundary(
    onRetry: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    var hasError by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    if (hasError) {
        ErrorFallbackScreen(
            message = errorMessage,
            onRetry = {
                hasError = false
                errorMessage = null
                onRetry?.invoke()
            }
        )
    } else {
        content()
    }
}

@Composable
private fun ErrorFallbackScreen(
    message: String?,
    onRetry: () -> Unit
) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Oups !",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.error,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = message ?: "Une erreur inattendue s'est produite.",
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(24.dp))
            Button(onClick = onRetry) {
                Text("R\u00e9essayer")
            }
        }
    }
}
