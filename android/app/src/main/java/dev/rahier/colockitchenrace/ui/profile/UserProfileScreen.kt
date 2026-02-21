package dev.rahier.colockitchenrace.ui.profile

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserProfileScreen(
    viewModel: UserProfileViewModel = hiltViewModel(),
    onSignedOut: () -> Unit,
    onNavigateToEdit: () -> Unit = {},
    onBack: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                UserProfileEffect.SignedOut -> onSignedOut()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Mon profil") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToEdit) {
                        Icon(Icons.Default.Edit, contentDescription = "Modifier")
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

        Spacer(modifier = Modifier.height(24.dp))

        // Avatar
        Icon(
            imageVector = Icons.Default.Person,
            contentDescription = null,
            modifier = Modifier
                .size(80.dp)
                .align(Alignment.CenterHorizontally),
            tint = CkrLavender,
        )

        Spacer(modifier = Modifier.height(16.dp))

        state.user?.let { user ->
            // Info card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    ProfileRow("Prenom", user.firstName)
                    ProfileRow("Nom", user.lastName)
                    ProfileRow("Email", user.email ?: "-")
                    ProfileRow("Telephone", user.phoneNumber ?: "-")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Dietary preferences
            if (user.dietaryPreferences.isNotEmpty()) {
                Text(text = "Preferences alimentaires", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    user.dietaryPreferences.forEach { pref ->
                        Surface(
                            color = CkrGoldLight,
                            shape = MaterialTheme.shapes.small,
                        ) {
                            Text(
                                text = "${pref.icon} ${pref.displayName}",
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Sign out
        Button(
            onClick = { viewModel.onIntent(UserProfileIntent.SignOutClicked) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = CkrCoral),
        ) {
            Text("Se deconnecter", color = CkrWhite)
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Delete account
        TextButton(
            onClick = { viewModel.onIntent(UserProfileIntent.DeleteAccountClicked) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
        ) {
            Text("Supprimer mon compte")
        }

        // Delete confirmation dialog
        if (state.showDeleteConfirmation) {
            AlertDialog(
                onDismissRequest = { viewModel.onIntent(UserProfileIntent.DismissDeleteDialog) },
                title = { Text("Supprimer votre compte ?") },
                text = { Text("Cette action est irreversible. Toutes vos donnees seront supprimees.") },
                confirmButton = {
                    TextButton(
                        onClick = { viewModel.onIntent(UserProfileIntent.ConfirmDelete) },
                        colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    ) { Text("Supprimer") }
                },
                dismissButton = {
                    TextButton(onClick = { viewModel.onIntent(UserProfileIntent.DismissDeleteDialog) }) {
                        Text("Annuler")
                    }
                },
            )
        }
    }
    }
}

@Composable
private fun ProfileRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = CkrGray)
        Text(text = value, style = MaterialTheme.typography.bodyMedium)
    }
}
