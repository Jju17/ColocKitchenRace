package dev.rahier.colocskitchenrace.ui.challenges

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardBottomSheet(
    viewModel: LeaderboardViewModel = hiltViewModel(),
    onDismiss: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.9f)
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.leaderboard),
                style = MaterialTheme.typography.headlineMedium,
                color = CkrLavender,
            )
            Spacer(modifier = Modifier.height(16.dp))

            if (state.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = CkrLavender)
                }
            } else if (state.entries.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.no_leaderboard),
                        style = MaterialTheme.typography.bodyLarge,
                        color = CkrGray,
                    )
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(bottom = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    // Top 3 podium
                    val top3 = state.entries.take(3)
                    if (top3.isNotEmpty()) {
                        PodiumSection(
                            entries = top3,
                            myCohouseId = state.myCohouseId,
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                    }

                    // Remaining entries
                    state.entries.drop(3).forEach { entry ->
                        LeaderboardRow(
                            entry = entry,
                            isMyCohouse = entry.cohouseId == state.myCohouseId,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PodiumSection(
    entries: List<LeaderboardEntry>,
    myCohouseId: String?,
) {
    val medals = listOf("\uD83E\uDD47", "\uD83E\uDD48", "\uD83E\uDD49") // gold, silver, bronze
    val heights = listOf(130.dp, 100.dp, 80.dp)
    val colors = listOf(CkrGold, CkrGray, CkrCoral)

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.Bottom,
    ) {
        // Show in order: 2nd, 1st, 3rd for podium visual effect
        val podiumOrder = when {
            entries.size >= 3 -> listOf(1, 0, 2)
            entries.size == 2 -> listOf(1, 0)
            else -> listOf(0)
        }

        podiumOrder.forEach { index ->
            if (index < entries.size) {
                val entry = entries[index]
                val isMyCohouse = entry.cohouseId == myCohouseId

                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = medals.getOrElse(index) { "" },
                        style = MaterialTheme.typography.headlineLarge,
                    )
                    Spacer(modifier = Modifier.height(4.dp))

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp)
                            .height(heights.getOrElse(index) { 80.dp }),
                        colors = CardDefaults.cardColors(
                            containerColor = if (isMyCohouse) CkrSkyLight else CkrLavenderLight,
                        ),
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Text(
                                text = entry.cohouseName,
                                style = MaterialTheme.typography.bodySmall,
                                textAlign = TextAlign.Center,
                                maxLines = 2,
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = stringResource(R.string.pts_format, entry.score),
                                style = MaterialTheme.typography.titleMedium,
                                color = colors.getOrElse(index) { CkrGray },
                            )
                            Text(
                                text = stringResource(R.string.challenges_validated, entry.validatedCount),
                                style = MaterialTheme.typography.bodySmall,
                                color = CkrGray,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LeaderboardRow(
    entry: LeaderboardEntry,
    isMyCohouse: Boolean,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isMyCohouse) CkrSkyLight else MaterialTheme.colorScheme.surface,
        ),
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
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "#${entry.rank}",
                    style = MaterialTheme.typography.titleMedium,
                    color = CkrGray,
                    modifier = Modifier.width(36.dp),
                )
                Column {
                    Text(text = entry.cohouseName, style = MaterialTheme.typography.bodyLarge)
                    Text(
                        text = stringResource(R.string.challenges_validated_long, entry.validatedCount),
                        style = MaterialTheme.typography.bodySmall,
                        color = CkrGray,
                    )
                }
            }
            Text(
                text = stringResource(R.string.pts_format, entry.score),
                style = MaterialTheme.typography.titleMedium,
                color = CkrLavender,
            )
        }
    }
}
