package dev.rahier.colockitchenrace.ui.challenges

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Leaderboard
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colockitchenrace.data.model.ChallengeState
import dev.rahier.colockitchenrace.ui.theme.*
import dev.rahier.colockitchenrace.util.DateUtils

enum class ChallengeFilter(val label: String) {
    ALL("Tous"),
    TODO("A faire"),
    WAITING("En attente"),
    REVIEWED("Evalues"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChallengesScreen(
    viewModel: ChallengesViewModel = hiltViewModel(),
    onShowLeaderboard: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().padding(top = 16.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Challenges", style = MaterialTheme.typography.headlineLarge, color = CkrLavender)
            IconButton(onClick = onShowLeaderboard) {
                Icon(Icons.Default.Leaderboard, contentDescription = "Classement")
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Filter chips
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ChallengeFilter.entries.forEach { filter ->
                FilterChip(
                    selected = state.selectedFilter == filter,
                    onClick = { viewModel.onIntent(ChallengesIntent.FilterSelected(filter)) },
                    label = { Text(filter.label) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = CkrLavender,
                        selectedLabelColor = CkrWhite,
                    ),
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Challenge pager
        if (state.filteredChallenges.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Aucun challenge", style = MaterialTheme.typography.bodyLarge, color = CkrGray)
            }
        } else {
            val pagerState = rememberPagerState(pageCount = { state.filteredChallenges.size })

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 32.dp),
                pageSpacing = 16.dp,
            ) { page ->
                val challenge = state.filteredChallenges[page]
                Card(
                    modifier = Modifier.fillMaxSize(),
                    colors = CardDefaults.cardColors(
                        containerColor = when (challenge.state) {
                            ChallengeState.ONGOING -> CkrMintLight
                            ChallengeState.DONE -> CkrGoldLight
                            ChallengeState.NOT_STARTED -> CkrSkyLight
                        }
                    ),
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp).fillMaxSize(),
                        verticalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Column {
                            // State badge
                            val stateLabel = when (challenge.state) {
                                ChallengeState.ONGOING -> "En cours"
                                ChallengeState.DONE -> "Termine"
                                ChallengeState.NOT_STARTED -> "A venir"
                            }
                            val stateColor = when (challenge.state) {
                                ChallengeState.ONGOING -> CkrMint
                                ChallengeState.DONE -> CkrGold
                                ChallengeState.NOT_STARTED -> CkrSky
                            }
                            Surface(
                                color = stateColor,
                                shape = MaterialTheme.shapes.small,
                            ) {
                                Text(
                                    text = stateLabel,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = CkrWhite,
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))
                            Text(text = challenge.title, style = MaterialTheme.typography.headlineMedium)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(text = challenge.body, style = MaterialTheme.typography.bodyMedium)

                            challenge.points?.let { pts ->
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(text = "$pts points", style = MaterialTheme.typography.labelMedium, color = CkrGold)
                            }
                        }

                        Column {
                            Text(
                                text = "${DateUtils.formatDate(challenge.startDate)} - ${DateUtils.formatDate(challenge.endDate)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = CkrGray,
                            )

                            if (challenge.state == ChallengeState.ONGOING && state.hasCohouse) {
                                Spacer(modifier = Modifier.height(12.dp))
                                Button(
                                    onClick = { viewModel.onIntent(ChallengesIntent.StartChallenge(challenge.id)) },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
                                ) {
                                    Text("Participer", color = CkrWhite)
                                }
                            }
                        }
                    }
                }
            }

            // Page dots
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
            ) {
                repeat(state.filteredChallenges.size) { index ->
                    val color = if (pagerState.currentPage == index) CkrLavender else CkrGray.copy(alpha = 0.3f)
                    Surface(
                        modifier = Modifier.padding(horizontal = 3.dp).size(8.dp),
                        shape = MaterialTheme.shapes.extraSmall,
                        color = color,
                    ) {}
                }
            }
        }
    }
}
