package dev.rahier.colockitchenrace.ui.planning

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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.data.model.PlanningStep
import dev.rahier.colockitchenrace.data.model.PartyInfo
import dev.rahier.colockitchenrace.data.model.StepRole
import dev.rahier.colockitchenrace.ui.theme.*
import dev.rahier.colockitchenrace.util.DateUtils

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
        Text(text = "Planning", style = MaterialTheme.typography.headlineLarge, color = CkrLavender)
        Spacer(modifier = Modifier.height(24.dp))

        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = CkrLavender)
            }
        } else if (state.planning != null) {
            val planning = state.planning!!

            // Apero
            TimelineItem(
                label = "Apero",
                color = CkrCoral,
                lightColor = CkrCoralLight,
                step = planning.apero,
                isLast = false,
            )

            // Diner
            TimelineItem(
                label = "Diner",
                color = CkrMint,
                lightColor = CkrMintLight,
                step = planning.diner,
                isLast = false,
            )

            // Party
            PartyItem(
                party = planning.party,
            )
        } else {
            Text(
                text = "Le planning n'est pas encore disponible",
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
                            text = if (step.role == StepRole.HOST) "Hote" else "Visiteur",
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = CkrWhite,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(text = step.cohouseName, style = MaterialTheme.typography.titleMedium)
                Text(text = step.address, style = MaterialTheme.typography.bodySmall, color = CkrGray)
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = DateUtils.formatTimeRange(step.startTime, step.endTime),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(text = "${step.totalPeople} personnes", style = MaterialTheme.typography.bodySmall, color = CkrGray)

                if (step.dietarySummary.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    step.dietarySummary.forEach { (pref, count) ->
                        Text(text = "$pref: $count", style = MaterialTheme.typography.bodySmall, color = CkrGray)
                    }
                }

                step.hostPhone?.let {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "Hote: $it", style = MaterialTheme.typography.bodySmall)
                }
                step.visitorPhone?.let {
                    Text(text = "Visiteur: $it", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun PartyItem(party: PartyInfo) {
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
                Text(text = "Soiree", style = MaterialTheme.typography.headlineSmall)
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = party.name, style = MaterialTheme.typography.titleMedium)
                Text(text = party.address, style = MaterialTheme.typography.bodySmall, color = CkrGray)
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
