package dev.rahier.colockitchenrace.ui.home.registration

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
fun PaymentSummaryScreen(
    gameId: String,
    cohouseId: String,
    attendingUserIds: List<String>,
    averageAge: Int,
    cohouseType: String,
    totalPriceCents: Int,
    participantCount: Int,
    viewModel: PaymentSummaryViewModel = hiltViewModel(),
    onPaymentSheet: (clientSecret: String, customerId: String, ephemeralKeySecret: String) -> Unit,
    onRegistrationComplete: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.onIntent(
            PaymentSummaryIntent.Initialize(
                gameId = gameId,
                cohouseId = cohouseId,
                attendingUserIds = attendingUserIds,
                averageAge = averageAge,
                cohouseType = cohouseType,
                totalPriceCents = totalPriceCents,
                participantCount = participantCount,
            )
        )
    }

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is PaymentSummaryEffect.PresentPaymentSheet -> onPaymentSheet(
                    effect.clientSecret,
                    effect.customerId,
                    effect.ephemeralKeySecret,
                )
                PaymentSummaryEffect.RegistrationComplete -> onRegistrationComplete()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Recapitulatif") },
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
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                // Order summary card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Votre commande",
                            style = MaterialTheme.typography.headlineSmall,
                        )
                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text("Participants", style = MaterialTheme.typography.bodyLarge)
                            Text("$participantCount", style = MaterialTheme.typography.bodyLarge)
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text("Prix par personne", style = MaterialTheme.typography.bodyMedium, color = CkrGray)
                            Text(state.formattedPricePerPerson, style = MaterialTheme.typography.bodyMedium, color = CkrGray)
                        }

                        Spacer(modifier = Modifier.height(8.dp))
                        HorizontalDivider()
                        Spacer(modifier = Modifier.height(8.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text("Total", style = MaterialTheme.typography.headlineSmall)
                            Text(state.formattedTotal, style = MaterialTheme.typography.headlineSmall, color = CkrMint)
                        }
                    }
                }

                // Error message
                state.error?.let { error ->
                    Spacer(modifier = Modifier.height(16.dp))
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = CkrCoralLight),
                    ) {
                        Text(
                            text = error,
                            modifier = Modifier.padding(16.dp),
                            style = MaterialTheme.typography.bodyMedium,
                            color = CkrCoral,
                        )
                    }
                }
            }

            // Pay button
            Column {
                if (state.isCreatingPaymentIntent) {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = CkrLavender)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Preparation du paiement...",
                        style = MaterialTheme.typography.bodySmall,
                        color = CkrGray,
                        modifier = Modifier.align(Alignment.CenterHorizontally),
                    )
                } else if (state.isRegistering) {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = CkrMint)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Finalisation de l'inscription...",
                        style = MaterialTheme.typography.bodySmall,
                        color = CkrGray,
                        modifier = Modifier.align(Alignment.CenterHorizontally),
                    )
                } else if (state.error != null && state.paymentResult != null) {
                    CKRButton(
                        text = "Reessayer l'inscription",
                        onClick = { viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    CKRButton(
                        text = "Payer ${state.formattedTotal}",
                        onClick = { viewModel.onIntent(PaymentSummaryIntent.PayClicked) },
                        enabled = state.paymentResult != null,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}
