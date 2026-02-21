package dev.rahier.colockitchenrace.ui.auth.signin

import android.app.Activity
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*

@Composable
fun SignInScreen(
    viewModel: SignInViewModel = hiltViewModel(),
    onNavigateToMain: () -> Unit,
    onNavigateToEmailVerification: () -> Unit,
    onNavigateToProfileCompletion: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context as? Activity

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                SignInEffect.NavigateToMain -> onNavigateToMain()
                SignInEffect.NavigateToEmailVerification -> onNavigateToEmailVerification()
                SignInEffect.NavigateToProfileCompletion -> onNavigateToProfileCompletion()
            }
        }
    }

    // Create account confirmation dialog
    if (state.showCreateAccountDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.onIntent(SignInIntent.CreateAccountDismissed) },
            title = { Text("Creer un compte ?") },
            text = { Text("Aucun compte ne correspond a cet email. Voulez-vous en creer un ?") },
            confirmButton = {
                TextButton(onClick = { viewModel.onIntent(SignInIntent.CreateAccountConfirmed) }) {
                    Text("Oui")
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.onIntent(SignInIntent.CreateAccountDismissed) }) {
                    Text("Non")
                }
            },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 32.dp)
            .padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Logo / Title
        Text(
            text = "Colocs\nKitchen Race",
            style = MaterialTheme.typography.displayMedium,
            textAlign = TextAlign.Center,
            color = CkrLavender,
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Email field
        OutlinedTextField(
            value = state.email,
            onValueChange = { viewModel.onIntent(SignInIntent.EmailChanged(it)) },
            label = { Text("Email") },
            leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next,
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Password field
        OutlinedTextField(
            value = state.password,
            onValueChange = { viewModel.onIntent(SignInIntent.PasswordChanged(it)) },
            label = { Text("Mot de passe") },
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done,
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Sign in button
        CKRButton(
            text = "Se connecter",
            isLoading = state.isLoading,
            onClick = { viewModel.onIntent(SignInIntent.SignInClicked) },
            modifier = Modifier.fillMaxWidth(),
        )

        // Error message
        state.errorMessage?.let { error ->
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = error,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Divider
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f))
            Text(
                text = "  ou  ",
                style = MaterialTheme.typography.bodySmall,
                color = CkrGray,
            )
            HorizontalDivider(modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Google Sign-In
        OutlinedButton(
            onClick = { activity?.let { viewModel.signInWithGoogle(it) } },
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text("Continuer avec Google")
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Apple Sign-In
        OutlinedButton(
            onClick = { activity?.let { viewModel.signInWithApple(it) } },
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text("Continuer avec Apple")
        }
    }
}
