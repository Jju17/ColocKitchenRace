package dev.rahier.colocskitchenrace.ui.profile

import android.content.Intent
import android.net.Uri
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.DietaryPreference
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.User
import dev.rahier.colocskitchenrace.ui.theme.*

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
                title = { Text(stringResource(R.string.my_profile)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToEdit) {
                        Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.edit))
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
                    ProfileRow(stringResource(R.string.first_name), user.firstName)
                    ProfileRow(stringResource(R.string.last_name), user.lastName)
                    ProfileRow(stringResource(R.string.email), user.email ?: "-")
                    ProfileRow(stringResource(R.string.phone_label), user.phoneNumber ?: "-")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Dietary preferences
            if (user.dietaryPreferences.isNotEmpty()) {
                Text(text = stringResource(R.string.dietary_preferences), style = MaterialTheme.typography.titleMedium)
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

        // Support section
        Spacer(modifier = Modifier.height(24.dp))
        Text(text = stringResource(R.string.support), style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))

        val context = LocalContext.current
        OutlinedButton(
            onClick = {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://colocskitchenrace.be/privacy-policy.html"))
                context.startActivity(intent)
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(stringResource(R.string.privacy_policy))
        }

        Spacer(modifier = Modifier.height(8.dp))

        OutlinedButton(
            onClick = {
                val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:julien@rahier.dev"))
                context.startActivity(intent)
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(stringResource(R.string.contact_support))
        }

        Spacer(modifier = Modifier.weight(1f))

        // Sign out
        Button(
            onClick = { viewModel.onIntent(UserProfileIntent.SignOutClicked) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = CkrCoral),
        ) {
            Text(stringResource(R.string.sign_out), color = CkrWhite)
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Delete account
        TextButton(
            onClick = { viewModel.onIntent(UserProfileIntent.DeleteAccountClicked) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
        ) {
            Text(stringResource(R.string.delete_account))
        }

        // Delete confirmation dialog
        if (state.showDeleteConfirmation) {
            DeleteAccountDialog(
                onConfirm = { viewModel.onIntent(UserProfileIntent.ConfirmDelete) },
                onDismiss = { viewModel.onIntent(UserProfileIntent.DismissDeleteDialog) },
            )
        }
    }
    }
}

@Composable
private fun DeleteAccountDialog(
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.delete_account_title)) },
        text = { Text(stringResource(R.string.delete_account_message)) },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
            ) { Text(stringResource(R.string.delete)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        },
    )
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

// ─── Previews ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun UserProfileScreenPreview() {
    val mockUser = User(
        firstName = "Alice",
        lastName = "Dupont",
        email = "alice.dupont@example.com",
        phoneNumber = "+32 470 12 34 56",
        dietaryPreferences = setOf(DietaryPreference.VEGETARIAN, DietaryPreference.GLUTEN_FREE),
    )

    CKRTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Mon profil") },
                    navigationIcon = {
                        IconButton(onClick = {}) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                        }
                    },
                    actions = {
                        IconButton(onClick = {}) {
                            Icon(Icons.Default.Edit, contentDescription = "Modifier")
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
                Spacer(modifier = Modifier.height(24.dp))

                Icon(
                    imageVector = Icons.Default.Person,
                    contentDescription = null,
                    modifier = Modifier.size(80.dp).align(Alignment.CenterHorizontally),
                    tint = CkrLavender,
                )

                Spacer(modifier = Modifier.height(16.dp))

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        ProfileRow("Prenom", mockUser.firstName)
                        ProfileRow("Nom", mockUser.lastName)
                        ProfileRow("Email", mockUser.email ?: "-")
                        ProfileRow("Telephone", mockUser.phoneNumber ?: "-")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(text = "Preferences alimentaires", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    mockUser.dietaryPreferences.forEach { pref ->
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

                Spacer(modifier = Modifier.weight(1f))

                Button(
                    onClick = {},
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = CkrCoral),
                ) {
                    Text("Se deconnecter", color = CkrWhite)
                }

                Spacer(modifier = Modifier.height(12.dp))

                TextButton(
                    onClick = {},
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                ) {
                    Text("Supprimer mon compte")
                }
            }
        }
    }
}
