package dev.rahier.colockitchenrace.ui.home.registration

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.data.model.CohouseType
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegistrationFormScreen(
    viewModel: RegistrationFormViewModel = hiltViewModel(),
    onNavigateToPayment: (gameId: String, cohouseId: String, attendingUserIds: List<String>, averageAge: Int, cohouseType: String, totalPriceCents: Int, participantCount: Int) -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is RegistrationFormEffect.NavigateToPayment -> onNavigateToPayment(
                    effect.gameId,
                    effect.cohouseId,
                    effect.attendingUserIds,
                    effect.averageAge,
                    effect.cohouseType,
                    effect.totalPriceCents,
                    effect.participantCount,
                )
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Inscription") },
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
            // Participants section
            Text(
                text = "Qui participe ?",
                style = MaterialTheme.typography.headlineSmall,
                color = CkrLavender,
            )
            Spacer(modifier = Modifier.height(12.dp))

            state.participants.forEach { user ->
                val isSelected = user.id in state.selectedUserIds
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clickable {
                            viewModel.onIntent(RegistrationFormIntent.ToggleUser(user.id))
                        },
                    colors = CardDefaults.cardColors(
                        containerColor = if (isSelected) CkrMintLight else MaterialTheme.colorScheme.surface,
                    ),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(text = user.surname, style = MaterialTheme.typography.bodyLarge)
                        Icon(
                            imageVector = if (isSelected) Icons.Default.CheckCircle else Icons.Outlined.Circle,
                            contentDescription = null,
                            tint = if (isSelected) CkrMint else CkrGray,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Average age
            Text(
                text = "Age moyen de la coloc",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.averageAge,
                onValueChange = { viewModel.onIntent(RegistrationFormIntent.AverageAgeChanged(it)) },
                label = { Text("Age moyen") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Cohouse type
            Text(
                text = "Type de coloc",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CohouseType.entries.forEach { type ->
                    FilterChip(
                        selected = state.cohouseType == type,
                        onClick = { viewModel.onIntent(RegistrationFormIntent.CohouseTypeChanged(type)) },
                        label = { Text(type.displayName) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = CkrLavenderLight,
                        ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Price summary
            if (state.selectedCount > 0) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CkrGoldLight),
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "${state.selectedCount} participant(s)",
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Total: ${state.formattedTotal}",
                            style = MaterialTheme.typography.headlineSmall,
                        )
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Continue button
            CKRButton(
                text = "Continuer vers le paiement",
                onClick = { viewModel.onIntent(RegistrationFormIntent.ContinueToPayment) },
                enabled = state.canContinue,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
