package dev.rahier.colocskitchenrace.ui.home.registration

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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.CohouseType
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

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
                title = { Text(stringResource(R.string.registration_title)) },
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
            ParticipantSelector(
                participants = state.participants,
                selectedUserIds = state.selectedUserIds,
                onToggleUser = { viewModel.onIntent(RegistrationFormIntent.ToggleUser(it)) },
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Average age
            Text(
                text = stringResource(R.string.average_age_title),
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.averageAge,
                onValueChange = { viewModel.onIntent(RegistrationFormIntent.AverageAgeChanged(it)) },
                label = { Text(stringResource(R.string.average_age_label)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Cohouse type
            Text(
                text = stringResource(R.string.cohouse_type_title),
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
                PriceSummaryCard(
                    selectedCount = state.selectedCount,
                    formattedTotal = state.formattedTotal,
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Continue button
            CKRButton(
                text = stringResource(R.string.continue_to_payment),
                onClick = { viewModel.onIntent(RegistrationFormIntent.ContinueToPayment) },
                enabled = state.canContinue,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun ParticipantSelector(
    participants: List<CohouseUser>,
    selectedUserIds: Set<String>,
    onToggleUser: (String) -> Unit,
) {
    Text(
        text = stringResource(R.string.who_participates),
        style = MaterialTheme.typography.headlineSmall,
        color = CkrLavender,
    )
    Spacer(modifier = Modifier.height(12.dp))

    participants.forEach { user ->
        val isSelected = user.id in selectedUserIds
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp)
                .clickable { onToggleUser(user.id) },
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
}

@Composable
private fun PriceSummaryCard(
    selectedCount: Int,
    formattedTotal: String,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CkrGoldLight),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = stringResource(R.string.participants_count, selectedCount),
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.total_price, formattedTotal),
                style = MaterialTheme.typography.headlineSmall,
            )
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun RegistrationFormScreenPreview() {
    val participants = listOf(
        CohouseUser(id = "u1", surname = "Alice Dupont", isAdmin = true),
        CohouseUser(id = "u2", surname = "Bob Martin", isAdmin = false),
        CohouseUser(id = "u3", surname = "Charlie Leroy", isAdmin = false),
    )
    val selectedIds = setOf("u1", "u2")

    CKRTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Inscription") },
                    navigationIcon = {
                        IconButton(onClick = {}) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
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
                Text(
                    text = "Qui participe ?",
                    style = MaterialTheme.typography.headlineSmall,
                    color = CkrLavender,
                )
                Spacer(modifier = Modifier.height(12.dp))

                participants.forEach { user ->
                    val isSelected = user.id in selectedIds
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = if (isSelected) CkrMintLight else MaterialTheme.colorScheme.surface,
                        ),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
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

                Text(text = "Age moyen de la coloc", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = "23",
                    onValueChange = {},
                    label = { Text("Age moyen") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium,
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(text = "Type de coloc", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CohouseType.entries.forEach { type ->
                        FilterChip(
                            selected = type == CohouseType.MIXED,
                            onClick = {},
                            label = { Text(type.displayName) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = CkrLavenderLight,
                            ),
                        )
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                PriceSummaryCard(selectedCount = 2, formattedTotal = "10,00 EUR")

                Spacer(modifier = Modifier.height(16.dp))

                CKRButton(
                    text = "Continuer vers le paiement",
                    onClick = {},
                    enabled = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
