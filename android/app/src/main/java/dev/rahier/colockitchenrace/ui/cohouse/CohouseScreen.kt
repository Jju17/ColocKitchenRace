package dev.rahier.colockitchenrace.ui.cohouse

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*

@Composable
fun CohouseScreen(
    viewModel: CohouseViewModel = hiltViewModel(),
    onNavigateToCreate: () -> Unit = {},
    onNavigateToEdit: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    if (state.cohouse == null) {
        NoCohouseContent(
            joinCode = state.joinCode,
            isLoading = state.isLoading,
            error = state.error,
            onJoinCodeChanged = { viewModel.onIntent(CohouseIntent.JoinCodeChanged(it)) },
            onJoinClicked = { viewModel.onIntent(CohouseIntent.JoinClicked) },
            onCreateClicked = onNavigateToCreate,
        )
    } else {
        CohouseDetailContent(
            state = state,
            onIntent = viewModel::onIntent,
            onNavigateToEdit = onNavigateToEdit,
        )
    }
}

@Composable
private fun NoCohouseContent(
    joinCode: String,
    isLoading: Boolean,
    error: String?,
    onJoinCodeChanged: (String) -> Unit,
    onJoinClicked: () -> Unit,
    onCreateClicked: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.People,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = CkrLavender,
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Vous n'avez pas encore de coloc",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Join by code
        OutlinedTextField(
            value = joinCode,
            onValueChange = onJoinCodeChanged,
            label = { Text("Code de la coloc") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        )

        Spacer(modifier = Modifier.height(12.dp))

        CKRButton(
            text = "Rejoindre",
            onClick = onJoinClicked,
            isLoading = isLoading,
            enabled = joinCode.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        )

        error?.let {
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(24.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f))
            Text(text = "  ou  ", style = MaterialTheme.typography.bodySmall, color = CkrGray)
            HorizontalDivider(modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedButton(
            onClick = onCreateClicked,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text("Creer une coloc")
        }
    }
}

@Composable
private fun CohouseDetailContent(
    state: CohouseState,
    onIntent: (CohouseIntent) -> Unit,
    onNavigateToEdit: () -> Unit = {},
) {
    val cohouse = state.cohouse ?: return
    val clipboardManager = LocalClipboardManager.current
    var showCopied by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Ma coloc", style = MaterialTheme.typography.headlineLarge, color = CkrLavender)
            IconButton(onClick = onNavigateToEdit) {
                Icon(Icons.Default.Edit, contentDescription = "Modifier")
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // Cohouse name + code
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = CkrMintLight),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = cohouse.name, style = MaterialTheme.typography.headlineMedium)

                Spacer(modifier = Modifier.height(8.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = "Code: ${cohouse.code}", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.width(8.dp))
                    IconButton(
                        onClick = {
                            clipboardManager.setText(AnnotatedString(cohouse.code))
                            showCopied = true
                        },
                        modifier = Modifier.size(24.dp),
                    ) {
                        Icon(Icons.Default.ContentCopy, contentDescription = "Copier", modifier = Modifier.size(16.dp))
                    }
                    if (showCopied) {
                        Text(text = "Copie !", style = MaterialTheme.typography.bodySmall, color = CkrMint)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = cohouse.address.formatted,
                    style = MaterialTheme.typography.bodyMedium,
                    color = CkrGray,
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Members section
        Text(text = "Membres (${cohouse.totalUsers})", style = MaterialTheme.typography.headlineSmall)
        Spacer(modifier = Modifier.height(8.dp))

        cohouse.users.forEach { user ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
            ) {
                Row(
                    modifier = Modifier.padding(12.dp).fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text = user.surname, style = MaterialTheme.typography.bodyLarge)
                    if (user.isAdmin) {
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
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Quit cohouse
        TextButton(
            onClick = { onIntent(CohouseIntent.QuitClicked) },
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
        ) {
            Text("Quitter la coloc")
        }
    }
}
