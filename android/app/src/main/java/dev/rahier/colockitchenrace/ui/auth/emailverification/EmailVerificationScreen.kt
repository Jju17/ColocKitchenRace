package dev.rahier.colockitchenrace.ui.auth.emailverification

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.CkrLavender

@Composable
fun EmailVerificationScreen(
    viewModel: EmailVerificationViewModel = hiltViewModel(),
    onNavigateToProfileCompletion: () -> Unit,
    onNavigateToMain: () -> Unit,
    onNavigateToSignIn: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                EmailVerificationEffect.NavigateToProfileCompletion -> onNavigateToProfileCompletion()
                EmailVerificationEffect.NavigateToMain -> onNavigateToMain()
                EmailVerificationEffect.NavigateToSignIn -> onNavigateToSignIn()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.Email,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = CkrLavender,
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Verifiez votre email",
            style = MaterialTheme.typography.headlineMedium,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Nous avons envoye un email de verification. Cliquez sur le lien dans l'email pour continuer.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(32.dp))

        CKRButton(
            text = "J'ai verifie mon email",
            isLoading = state.isLoading,
            onClick = { viewModel.onIntent(EmailVerificationIntent.CheckVerification) },
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(modifier = Modifier.height(12.dp))

        TextButton(onClick = { viewModel.onIntent(EmailVerificationIntent.ResendEmail) }) {
            Text("Renvoyer l'email")
        }

        state.errorMessage?.let { error ->
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(24.dp))

        TextButton(onClick = { viewModel.onIntent(EmailVerificationIntent.SignOut) }) {
            Text("Se deconnecter", color = MaterialTheme.colorScheme.error)
        }
    }
}
