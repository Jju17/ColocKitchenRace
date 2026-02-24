package dev.rahier.colocskitchenrace.ui.auth.profilecompletion

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

@Composable
fun ProfileCompletionScreen(
    viewModel: ProfileCompletionViewModel = hiltViewModel(),
    onNavigateToMain: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                ProfileCompletionEffect.NavigateToMain -> onNavigateToMain()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CkrMintLight)
            .verticalScroll(rememberScrollState())
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        Text(
            text = "Colocs\nKitchen Race",
            style = MaterialTheme.typography.displaySmall,
            textAlign = TextAlign.Center,
            color = CkrDark,
        )

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = "Completez votre profil",
            style = MaterialTheme.typography.headlineSmall,
            color = CkrDark,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Ces informations sont necessaires pour participer",
            style = MaterialTheme.typography.bodyMedium,
            color = CkrGray,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedTextField(
            value = state.firstName,
            onValueChange = { viewModel.onIntent(ProfileCompletionIntent.FirstNameChanged(it)) },
            label = { Text("Prenom") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = CkrWhite,
                unfocusedContainerColor = CkrWhite,
                focusedBorderColor = CkrMint,
                unfocusedBorderColor = Color.Transparent,
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
        )

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = state.lastName,
            onValueChange = { viewModel.onIntent(ProfileCompletionIntent.LastNameChanged(it)) },
            label = { Text("Nom") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = CkrWhite,
                unfocusedContainerColor = CkrWhite,
                focusedBorderColor = CkrMint,
                unfocusedBorderColor = Color.Transparent,
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
        )

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = state.phoneNumber,
            onValueChange = { viewModel.onIntent(ProfileCompletionIntent.PhoneChanged(it)) },
            label = { Text("Numero de telephone") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = CkrWhite,
                unfocusedContainerColor = CkrWhite,
                focusedBorderColor = CkrMint,
                unfocusedBorderColor = Color.Transparent,
            ),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Phone,
                imeAction = ImeAction.Done,
            ),
        )

        Spacer(modifier = Modifier.height(24.dp))

        CKRButton(
            text = "Continuer",
            isLoading = state.isLoading,
            enabled = state.firstName.isNotBlank() && state.lastName.isNotBlank() && state.phoneNumber.isNotBlank(),
            onClick = { viewModel.onIntent(ProfileCompletionIntent.SaveClicked) },
            modifier = Modifier.fillMaxWidth(),
        )

        state.errorMessage?.let { error ->
            Spacer(modifier = Modifier.height(12.dp))
            Text(text = error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}
