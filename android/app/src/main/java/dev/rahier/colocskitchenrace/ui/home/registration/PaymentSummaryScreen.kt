package dev.rahier.colocskitchenrace.ui.home.registration

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.stripe.android.paymentsheet.PaymentSheet
import com.stripe.android.paymentsheet.PaymentSheetResult
import com.stripe.android.paymentsheet.rememberPaymentSheet
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

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
    onRegistrationComplete: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Stripe PaymentSheet integration
    val paymentSheet = rememberPaymentSheet { result ->
        when (result) {
            is PaymentSheetResult.Completed -> {
                viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded)
            }
            is PaymentSheetResult.Canceled -> {
                // User canceled — do nothing, they can retry
            }
            is PaymentSheetResult.Failed -> {
                viewModel.onIntent(
                    PaymentSummaryIntent.PaymentFailed(
                        result.error.localizedMessage ?: "Erreur de paiement"
                    )
                )
            }
        }
    }

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
                is PaymentSummaryEffect.PresentPaymentSheet -> {
                    val configuration = PaymentSheet.Configuration.Builder("Colocs Kitchen Race")
                        .customer(
                            PaymentSheet.CustomerConfiguration(
                                id = effect.customerId,
                                ephemeralKeySecret = effect.ephemeralKeySecret,
                            )
                        )
                        .build()
                    paymentSheet.presentWithPaymentIntent(
                        paymentIntentClientSecret = effect.clientSecret,
                        configuration = configuration,
                    )
                }
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
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            PaymentOrderSummary(
                participantCount = participantCount,
                formattedPricePerPerson = state.formattedPricePerPerson,
                formattedTotal = state.formattedTotal,
                error = state.error,
            )

            PaymentActionFooter(
                isCreatingPaymentIntent = state.isCreatingPaymentIntent,
                isConfirming = state.isConfirming,
                hasError = state.error != null,
                hasPaymentResult = state.paymentResult != null,
                formattedTotal = state.formattedTotal,
                onRetry = { viewModel.onIntent(PaymentSummaryIntent.PaymentSucceeded) },
                onPay = { viewModel.onIntent(PaymentSummaryIntent.PayClicked) },
            )
        }
    }
}

@Composable
private fun PaymentOrderSummary(
    participantCount: Int,
    formattedPricePerPerson: String,
    formattedTotal: String,
    error: String?,
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
                    Text(formattedPricePerPerson, style = MaterialTheme.typography.bodyMedium, color = CkrGray)
                }

                Spacer(modifier = Modifier.height(8.dp))
                HorizontalDivider()
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Total", style = MaterialTheme.typography.headlineSmall)
                    Text(formattedTotal, style = MaterialTheme.typography.headlineSmall, color = CkrMint)
                }
            }
        }

        // Error message
        error?.let {
            Spacer(modifier = Modifier.height(16.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = CkrCoralLight),
            ) {
                Text(
                    text = it,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = CkrCoral,
                )
            }
        }
    }
}

@Composable
private fun PaymentActionFooter(
    isCreatingPaymentIntent: Boolean,
    isConfirming: Boolean,
    hasError: Boolean,
    hasPaymentResult: Boolean,
    formattedTotal: String,
    onRetry: () -> Unit,
    onPay: () -> Unit,
) {
    Column {
        if (isCreatingPaymentIntent) {
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
        } else if (isConfirming) {
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
        } else if (hasError && hasPaymentResult) {
            CKRButton(
                text = "Reessayer l'inscription",
                onClick = onRetry,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            CKRButton(
                text = "Payer $formattedTotal",
                onClick = onPay,
                enabled = hasPaymentResult,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun PaymentSummaryScreenPreview() {
    CKRTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Recapitulatif") },
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
                    .padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                PaymentOrderSummary(
                    participantCount = 3,
                    formattedPricePerPerson = "5,00 EUR",
                    formattedTotal = "15,00 EUR",
                    error = null,
                )

                PaymentActionFooter(
                    isCreatingPaymentIntent = false,
                    isConfirming = false,
                    hasError = false,
                    hasPaymentResult = true,
                    formattedTotal = "15,00 EUR",
                    onRetry = {},
                    onPay = {},
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun PaymentSummaryLoadingPreview() {
    CKRTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            PaymentActionFooter(
                isCreatingPaymentIntent = true,
                isConfirming = false,
                hasError = false,
                hasPaymentResult = false,
                formattedTotal = "15,00 EUR",
                onRetry = {},
                onPay = {},
            )
        }
    }
}
