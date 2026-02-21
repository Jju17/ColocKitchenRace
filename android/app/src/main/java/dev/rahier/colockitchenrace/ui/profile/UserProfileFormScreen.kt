package dev.rahier.colockitchenrace.ui.profile

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.data.model.DietaryPreference
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun UserProfileFormScreen(
    viewModel: UserProfileFormViewModel = hiltViewModel(),
    onSaved: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                UserProfileFormEffect.Saved -> onSaved()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Modifier le profil") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            // Basic info section
            Text(text = "Informations", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = state.firstName,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.FirstNameChanged(it)) },
                label = { Text("Prenom") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.lastName,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.LastNameChanged(it)) },
                label = { Text("Nom") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.email,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.EmailChanged(it)) },
                label = { Text("Email") },
                singleLine = true,
                enabled = state.isEmailEditable,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.phoneNumber,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.PhoneChanged(it)) },
                label = { Text("Telephone") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Dietary preferences
            Text(text = "Preferences alimentaires", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(12.dp))

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                DietaryPreference.entries.forEach { pref ->
                    val isSelected = pref in state.dietaryPreferences
                    FilterChip(
                        selected = isSelected,
                        onClick = { viewModel.onIntent(UserProfileFormIntent.ToggleDietaryPreference(pref)) },
                        label = { Text("${pref.icon} ${pref.displayName}") },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = CkrGoldLight,
                        ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // News subscription
            Text(text = "CKR", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "S'abonner aux actualites",
                    style = MaterialTheme.typography.bodyLarge,
                )
                Switch(
                    checked = state.isSubscribeToNews,
                    onCheckedChange = { viewModel.onIntent(UserProfileFormIntent.SubscribeToNewsChanged(it)) },
                    colors = SwitchDefaults.colors(checkedTrackColor = CkrMint),
                )
            }

            // Error
            state.error?.let { error ->
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Save button
            CKRButton(
                text = "Enregistrer",
                onClick = { viewModel.onIntent(UserProfileFormIntent.Save) },
                isLoading = state.isSaving,
                enabled = state.canSave,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
