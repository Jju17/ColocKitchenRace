package dev.rahier.colockitchenrace.ui.cohouse.form

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CohouseFormScreen(
    isEditMode: Boolean,
    viewModel: CohouseFormViewModel = hiltViewModel(),
    onSaved: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(isEditMode) {
        if (isEditMode) viewModel.initForEdit() else viewModel.initForCreate()
    }

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                CohouseFormEffect.Saved -> onSaved()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isEditMode) "Modifier la coloc" else "Creer une coloc") },
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
            // Cohouse name
            Text(text = "Nom de la coloc", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.name,
                onValueChange = { viewModel.onIntent(CohouseFormIntent.NameChanged(it)) },
                label = { Text("Nom") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Address
            Text(text = "Adresse", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.street,
                onValueChange = { viewModel.onIntent(CohouseFormIntent.StreetChanged(it)) },
                label = { Text("Rue et numero") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = state.postalCode,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.PostalCodeChanged(it)) },
                    label = { Text("Code postal") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = MaterialTheme.shapes.medium,
                )
                OutlinedTextField(
                    value = state.city,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.CityChanged(it)) },
                    label = { Text("Ville") },
                    singleLine = true,
                    modifier = Modifier.weight(2f),
                    shape = MaterialTheme.shapes.medium,
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Members
            Text(text = "Membres (${state.members.size})", style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))

            state.members.forEach { member ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(text = member.surname, style = MaterialTheme.typography.bodyLarge)
                            if (member.isAdmin) {
                                Surface(color = CkrGold, shape = MaterialTheme.shapes.small) {
                                    Text(
                                        text = "Admin",
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = CkrWhite,
                                    )
                                }
                            }
                        }
                        if (!member.isAdmin) {
                            IconButton(
                                onClick = { viewModel.onIntent(CohouseFormIntent.RemoveMember(member.id)) },
                                modifier = Modifier.size(24.dp),
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "Supprimer", tint = CkrCoral)
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Add member
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = state.newMemberName,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.NewMemberNameChanged(it)) },
                    label = { Text("Nouveau membre") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = MaterialTheme.shapes.medium,
                )
                IconButton(
                    onClick = { viewModel.onIntent(CohouseFormIntent.AddMember) },
                    enabled = state.newMemberName.isNotBlank(),
                ) {
                    Icon(Icons.Default.PersonAdd, contentDescription = "Ajouter", tint = CkrMint)
                }
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
                text = if (state.isEditMode) "Enregistrer" else "Creer la coloc",
                onClick = { viewModel.onIntent(CohouseFormIntent.Save) },
                isLoading = state.isSaving,
                enabled = state.canSave,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
