package dev.rahier.colocskitchenrace.ui.profile

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.DietaryPreference
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

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
                title = { Text(stringResource(R.string.edit_profile)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
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
            Text(text = stringResource(R.string.information), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = state.firstName,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.FirstNameChanged(it)) },
                label = { Text(stringResource(R.string.first_name)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.lastName,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.LastNameChanged(it)) },
                label = { Text(stringResource(R.string.last_name)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.email,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.EmailChanged(it)) },
                label = { Text(stringResource(R.string.email)) },
                singleLine = true,
                enabled = state.isEmailEditable,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = state.phoneNumber,
                onValueChange = { viewModel.onIntent(UserProfileFormIntent.PhoneChanged(it)) },
                label = { Text(stringResource(R.string.phone_label)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Dietary preferences
            Text(text = stringResource(R.string.dietary_preferences), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
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
            Text(text = stringResource(R.string.ckr_section), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = stringResource(R.string.subscribe_news),
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
                text = stringResource(R.string.save),
                onClick = { viewModel.onIntent(UserProfileFormIntent.Save) },
                isLoading = state.isSaving,
                enabled = state.canSave,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
