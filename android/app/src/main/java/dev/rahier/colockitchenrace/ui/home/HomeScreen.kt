package dev.rahier.colockitchenrace.ui.home

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.ui.components.CKRButton
import dev.rahier.colockitchenrace.ui.theme.*
import dev.rahier.colockitchenrace.util.DateUtils

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToProfile: () -> Unit = {},
    onNavigateToRegistration: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Colocs\nKitchen Race",
                style = MaterialTheme.typography.headlineLarge,
                color = CkrLavender,
            )
            IconButton(onClick = onNavigateToProfile) {
                Icon(Icons.Default.Person, contentDescription = "Profil")
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Game info card
        state.game?.let { game ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Edition ${game.editionNumber}",
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = DateUtils.formatDate(game.nextGameDate),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "${game.totalRegisteredParticipants}/${game.maxParticipants} participants",
                        style = MaterialTheme.typography.bodyMedium,
                        color = CkrGray,
                    )

                    if (state.cohouse != null && !state.isRegistered) {
                        Spacer(modifier = Modifier.height(16.dp))
                        if (game.isRegistrationOpen) {
                            CKRButton(
                                text = "S'inscrire - ${game.formattedPricePerPerson}/pers",
                                onClick = onNavigateToRegistration,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        } else {
                            Text(
                                text = "Inscriptions fermees",
                                style = MaterialTheme.typography.bodyMedium,
                                color = CkrCoral,
                            )
                        }
                    } else if (state.isRegistered) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Vous etes inscrits !",
                            style = MaterialTheme.typography.bodyMedium,
                            color = CkrMint,
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Cohouse card
        state.cohouse?.let { cohouse ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = CkrMintLight),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = cohouse.name, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        text = "${cohouse.totalUsers} membres",
                        style = MaterialTheme.typography.bodyMedium,
                        color = CkrGray,
                    )
                }
            }
        } ?: run {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = CkrCoralLight),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "Rejoignez ou creez une coloc pour participer !",
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // News section
        if (state.news.isNotEmpty()) {
            Text(
                text = "Actualites",
                style = MaterialTheme.typography.headlineSmall,
            )
            Spacer(modifier = Modifier.height(8.dp))

            state.news.forEach { news ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = CkrSkyLight),
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text(text = news.title, style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = news.body,
                            style = MaterialTheme.typography.bodySmall,
                            color = CkrGray,
                            maxLines = 3,
                        )
                    }
                }
            }
        }
    }
}
