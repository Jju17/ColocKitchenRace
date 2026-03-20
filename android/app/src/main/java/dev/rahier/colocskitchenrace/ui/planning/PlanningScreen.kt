package dev.rahier.colocskitchenrace.ui.planning

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.PlanningStep
import dev.rahier.colocskitchenrace.data.model.PartyInfo
import dev.rahier.colocskitchenrace.data.model.StepRole
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*
import dev.rahier.colocskitchenrace.util.DateUtils
import java.util.Date
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextDecoration

@Composable
fun PlanningScreen(
    viewModel: PlanningViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(text = stringResource(R.string.tab_planning), style = MaterialTheme.typography.headlineLarge, color = CkrLavender)
        Spacer(modifier = Modifier.height(24.dp))

        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = CkrLavender)
            }
        } else if (state.planning != null) {
            val planning = state.planning!!

            // Apero
            TimelineItem(
                label = stringResource(R.string.apero),
                color = CkrCoral,
                lightColor = CkrCoralLight,
                step = planning.apero,
                isLast = false,
            )

            // Diner
            TimelineItem(
                label = stringResource(R.string.dinner),
                color = CkrMint,
                lightColor = CkrMintLight,
                step = planning.diner,
                isLast = false,
            )

            // Party
            PartyItem(
                party = planning.party,
            )
        } else if (state.error != null) {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = stringResource(R.string.error_loading_planning),
                        style = MaterialTheme.typography.bodyLarge,
                        color = CkrCoral,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    CKRButton(
                        text = stringResource(R.string.retry),
                        onClick = { viewModel.onIntent(PlanningIntent.Retry) },
                    )
                }
            }
        } else {
            Text(
                text = stringResource(R.string.planning_not_revealed),
                style = MaterialTheme.typography.bodyLarge,
                color = CkrGray,
            )
        }
    }
}

@Composable
private fun TimelineItem(
    label: String,
    color: androidx.compose.ui.graphics.Color,
    lightColor: androidx.compose.ui.graphics.Color,
    step: PlanningStep,
    isLast: Boolean,
) {
    val context = LocalContext.current
    Row(modifier = Modifier.fillMaxWidth()) {
        // Timeline indicator
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.width(40.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(16.dp)
                    .clip(CircleShape)
                    .background(color),
            )
            if (!isLast) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(180.dp)
                        .background(color.copy(alpha = 0.3f)),
                )
            }
        }

        // Content
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
            colors = CardDefaults.cardColors(containerColor = lightColor),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(text = label, style = MaterialTheme.typography.headlineSmall)
                    Surface(color = color, shape = MaterialTheme.shapes.small) {
                        Text(
                            text = if (step.role == StepRole.HOST) stringResource(R.string.host) else stringResource(R.string.visitor),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = CkrWhite,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(text = step.cohouseName, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = step.address,
                    style = MaterialTheme.typography.bodySmall,
                    color = CkrLavender,
                    textDecoration = TextDecoration.Underline,
                    modifier = Modifier.clickable {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=${Uri.encode(step.address)}"))
                        context.startActivity(intent)
                    },
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = DateUtils.formatTimeRange(step.startTime, step.endTime),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(text = stringResource(R.string.people_count, step.totalPeople), style = MaterialTheme.typography.bodySmall, color = CkrGray)

                if (step.dietarySummary.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    step.dietarySummary.forEach { (pref, count) ->
                        Text(text = "$pref: $count", style = MaterialTheme.typography.bodySmall, color = CkrGray)
                    }
                }

                step.hostPhone?.let {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = stringResource(R.string.host_phone, it), style = MaterialTheme.typography.bodySmall)
                }
                step.visitorPhone?.let {
                    Text(text = stringResource(R.string.visitor_phone, it), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun PartyItem(party: PartyInfo) {
    val context = LocalContext.current
    Row(modifier = Modifier.fillMaxWidth()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.width(40.dp),
        ) {
            Box(
                modifier = Modifier.size(16.dp).clip(CircleShape).background(CkrLavender),
            )
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = stringResource(R.string.party), style = MaterialTheme.typography.headlineSmall)
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = party.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = party.address,
                    style = MaterialTheme.typography.bodySmall,
                    color = CkrLavender,
                    textDecoration = TextDecoration.Underline,
                    modifier = Modifier.clickable {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=${Uri.encode(party.address)}"))
                        context.startActivity(intent)
                    },
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = DateUtils.formatTimeRange(party.startTime, party.endTime),
                    style = MaterialTheme.typography.bodyMedium,
                )
                party.note?.let {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = it, style = MaterialTheme.typography.bodySmall, color = CkrGray)
                }
            }
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────

@Preview(showBackground = true)
@Composable
private fun TimelineItemHostPreview() {
    CKRTheme {
        TimelineItem(
            label = "Apero",
            color = CkrCoral,
            lightColor = CkrCoralLight,
            step = PlanningStep(
                role = StepRole.HOST,
                cohouseName = "Les Joyeux Colocs",
                address = "Rue de la Loi 16, 1000 Bruxelles",
                hostPhone = "+32 470 12 34 56",
                visitorPhone = "+32 475 98 76 54",
                totalPeople = 8,
                dietarySummary = mapOf("Vegetarien" to 2, "Sans gluten" to 1),
                startTime = Date(),
                endTime = Date(System.currentTimeMillis() + 2 * 3600 * 1000L),
            ),
            isLast = false,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun TimelineItemVisitorPreview() {
    CKRTheme {
        TimelineItem(
            label = "Diner",
            color = CkrMint,
            lightColor = CkrMintLight,
            step = PlanningStep(
                role = StepRole.VISITOR,
                cohouseName = "La Coloc du Bonheur",
                address = "Avenue Louise 42, 1050 Ixelles",
                totalPeople = 6,
                startTime = Date(),
                endTime = Date(System.currentTimeMillis() + 2 * 3600 * 1000L),
            ),
            isLast = true,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun PartyItemPreview() {
    CKRTheme {
        PartyItem(
            party = PartyInfo(
                name = "Le Fuse",
                address = "Rue Blaes 208, 1000 Bruxelles",
                startTime = Date(),
                endTime = Date(System.currentTimeMillis() + 4 * 3600 * 1000L),
                note = "Entree gratuite pour les participants CKR !",
            ),
        )
    }
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun PlanningScreenContentPreview() {
    CKRTheme {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Text(text = "Planning", style = MaterialTheme.typography.headlineLarge, color = CkrLavender)
            Spacer(modifier = Modifier.height(24.dp))

            TimelineItem(
                label = "Apero",
                color = CkrCoral,
                lightColor = CkrCoralLight,
                step = PlanningStep(
                    role = StepRole.HOST,
                    cohouseName = "Les Joyeux Colocs",
                    address = "Rue de la Loi 16, 1000 Bruxelles",
                    totalPeople = 8,
                    startTime = Date(),
                    endTime = Date(System.currentTimeMillis() + 2 * 3600 * 1000L),
                ),
                isLast = false,
            )

            TimelineItem(
                label = "Diner",
                color = CkrMint,
                lightColor = CkrMintLight,
                step = PlanningStep(
                    role = StepRole.VISITOR,
                    cohouseName = "La Coloc du Bonheur",
                    address = "Avenue Louise 42, 1050 Ixelles",
                    totalPeople = 6,
                    startTime = Date(),
                    endTime = Date(System.currentTimeMillis() + 2 * 3600 * 1000L),
                ),
                isLast = false,
            )

            PartyItem(
                party = PartyInfo(
                    name = "Le Fuse",
                    address = "Rue Blaes 208, 1000 Bruxelles",
                    startTime = Date(),
                    endTime = Date(System.currentTimeMillis() + 4 * 3600 * 1000L),
                    note = "Entree gratuite pour les participants CKR !",
                ),
            )
        }
    }
}
