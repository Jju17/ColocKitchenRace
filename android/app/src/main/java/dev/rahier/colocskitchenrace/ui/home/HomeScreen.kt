package dev.rahier.colocskitchenrace.ui.home

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AddCircleOutline
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.toUpperCase
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.News
import dev.rahier.colocskitchenrace.data.model.PostalAddress
import dev.rahier.colocskitchenrace.ui.theme.*
import dev.rahier.colocskitchenrace.util.DateUtils
import java.util.Date
import kotlinx.coroutines.delay

@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToProfile: () -> Unit = {},
    onNavigateToRegistration: () -> Unit = {},
    onNavigateToCohouse: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Header - matches iOS .navigationTitle("Colocs Kitchen Race") + profile toolbar button
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Colocs Kitchen Race",
                style = MaterialTheme.typography.headlineLarge,
                color = CkrDark,
            )
            IconButton(onClick = onNavigateToProfile) {
                Icon(
                    Icons.Default.Person,
                    contentDescription = "Profil",
                    tint = CkrGray,
                    modifier = Modifier.size(28.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(15.dp))

        // ── 1. Cohouse Tile (always visible, tappable → switches to cohouse tab) ──
        CohouseTile(
            cohouse = state.cohouse,
            coverImageData = state.coverImageData,
            onClick = onNavigateToCohouse,
        )

        Spacer(modifier = Modifier.height(15.dp))

        // ── 2. Registration Tile (only if game AND cohouse exist) ──
        val game = state.game
        val cohouse = state.cohouse
        if (game != null && cohouse != null) {
            RegistrationTile(
                game = game,
                isRegistered = state.isRegistered,
                onRegisterClick = onNavigateToRegistration,
            )

            Spacer(modifier = Modifier.height(15.dp))
        }

        // ── 3. Countdown Tile (always visible) ──
        CountdownTile(
            nextGameDate = state.game?.nextGameDate,
            countdownStart = state.game?.startCKRCountdown,
            hasCountdownStarted = state.game?.hasCountdownStarted ?: false,
        )

        Spacer(modifier = Modifier.height(15.dp))

        // ── 4. News Tile (always visible, shows empty state) ──
        NewsTile(news = state.news)

        Spacer(modifier = Modifier.height(16.dp))
    }
}

// ─── 1. Cohouse Tile ─────────────────────────────────────────────────
// iOS: CohouseTileView — image background with gradient overlay, cohouse name in BaksoSapi 45,
//      or plus.circle icon if no cohouse. Button that switches to cohouse tab.

@Composable
private fun CohouseTile(
    cohouse: Cohouse?,
    coverImageData: ByteArray?,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        // Background: cover image or default photo (like iOS)
        if (coverImageData != null) {
            val bitmap = remember(coverImageData) {
                BitmapFactory.decodeByteArray(coverImageData, 0, coverImageData.size)
            }
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
        } else {
            Image(
                painter = painterResource(id = R.drawable.default_coloc_background),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }

        // Gradient overlay: transparent → black (like iOS)
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.5f))
                    )
                ),
        )

        if (cohouse != null) {
            Text(
                text = cohouse.name,
                style = MaterialTheme.typography.displayLarge,
                color = CkrWhite,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(16.dp),
            )
        } else {
            Icon(
                Icons.Default.AddCircleOutline,
                contentDescription = "Ajouter une coloc",
                modifier = Modifier.size(40.dp),
                tint = CkrWhite,
            )
        }
    }
}

// ─── 2. Registration Tile ────────────────────────────────────────────
// iOS: RegistrationTileView — mint green, 150dp height, "CKR Registration" title,
//      3 states: registered (gold checkmark), open (deadline + "Register your cohouse!"), closed.

@Composable
private fun RegistrationTile(
    game: CKRGame,
    isRegistered: Boolean,
    onRegisterClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CkrMint)
            .then(
                if (!isRegistered && game.isRegistrationOpen) {
                    Modifier.clickable(onClick = onRegisterClick)
                } else Modifier
            ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Left content
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Title — iOS: "CKR Registration" BaksoSapi 26, heavy
                Text(
                    text = "CKR Registration",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = CkrWhite,
                )

                when {
                    isRegistered -> {
                        // iOS: checkmark.circle.fill + "Registered!" in gold
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = CkrGoldLight,
                                modifier = Modifier.size(18.dp),
                            )
                            Text(
                                text = "Registered!",
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                color = CkrGoldLight,
                            )
                        }
                    }
                    game.isRegistrationOpen -> {
                        // iOS: "Register before [date]" BaksoSapi 14, light, uppercase
                        Text(
                            text = "Register before ${DateUtils.formatDate(game.registrationDeadline)}".uppercase(),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Light,
                            color = CkrWhite,
                        )
                        // iOS: "Register your cohouse!" + arrow icon in gold
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                text = "Register your cohouse!",
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                color = CkrGoldLight,
                            )
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                tint = CkrGoldLight,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                    else -> {
                        // iOS: "Registrations closed" BaksoSapi 16, light
                        Text(
                            text = "Registrations closed",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Light,
                            color = CkrWhite,
                        )
                    }
                }
            }

            // Right chevron — iOS: chevron.right, 24pt bold, white 0.6 opacity
            if (!isRegistered && game.isRegistrationOpen) {
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint = CkrWhite.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// ─── 3. Countdown Tile ───────────────────────────────────────────────
// iOS: CountdownTileView — lavender, 230dp, two modes:
//   a. Countdown started: "Next Edition In" + date + vertical rows (value — label)
//   b. Coming soon: "Next Edition" + "Coming Soon" + "Stay tuned!"

@Composable
private fun CountdownTile(
    nextGameDate: java.util.Date?,
    countdownStart: java.util.Date?,
    hasCountdownStarted: Boolean,
) {
    // Live countdown
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            now = System.currentTimeMillis()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CkrLavender)
            .padding(16.dp),
    ) {
        if (hasCountdownStarted && nextGameDate != null) {
            // ── Mode A: Countdown started ──
            val diff = nextGameDate.time - now

            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                // Header
                Column {
                    // iOS: "Next Edition In" BaksoSapi 26, heavy
                    Text(
                        text = "Next Edition In",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = CkrWhite,
                    )
                    // iOS: date in BaksoSapi 12, light, uppercase
                    Text(
                        text = DateUtils.formatDate(nextGameDate).uppercase(),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Light,
                        color = CkrWhite,
                    )
                }

                if (diff > 0) {
                    // Countdown rows — iOS: vertical HStacks, value left, label right, BaksoSapi 22
                    val days = (diff / (1000 * 60 * 60 * 24)).toInt()
                    val hours = ((diff / (1000 * 60 * 60)) % 24).toInt()
                    val minutes = ((diff / (1000 * 60)) % 60).toInt()
                    val seconds = ((diff / 1000) % 60).toInt()

                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        CountdownRow(value = String.format("%02d", days), label = "Days")
                        CountdownRow(value = String.format("%02d", hours), label = "Hours")
                        CountdownRow(value = String.format("%02d", minutes), label = "Minutes")
                        CountdownRow(value = String.format("%02d", seconds), label = "Seconds")
                    }
                } else {
                    // Countdown finished
                    Text(
                        text = "C'est parti !",
                        style = MaterialTheme.typography.displaySmall,
                        color = CkrGoldLight,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                    )
                }
            }
        } else {
            // ── Mode B: Coming soon ──
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // iOS: "Next Edition" BaksoSapi 26, heavy
                Text(
                    text = "Next Edition",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = CkrWhite,
                )
                // iOS: "Coming Soon" BaksoSapi 38, heavy
                Text(
                    text = "Coming Soon",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = CkrWhite,
                )
                Spacer(modifier = Modifier.height(4.dp))
                // iOS: "Stay tuned!" BaksoSapi 16, light, uppercase
                Text(
                    text = "Stay tuned!".uppercase(),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Light,
                    color = CkrWhite,
                )
            }
        }
    }
}

@Composable
private fun CountdownRow(value: String, label: String) {
    // iOS: HStack { Text(value); Spacer; Text(label) } — BaksoSapi 22, heavy, white
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = CkrWhite,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = CkrWhite,
        )
    }
}

// ─── 4. News Tile ────────────────────────────────────────────────────
// iOS: NewsTileView — sky blue, 230dp, "News" title, List with NewsCell,
//      empty state: white box with "No news at the moment"

@Composable
private fun NewsTile(news: List<News>) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(CkrSky),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Title — iOS: "News" BaksoSapi 26, heavy, white
            Text(
                text = "News",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = CkrWhite,
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 16.dp),
            )

            if (news.isNotEmpty()) {
                // News list — iOS: List { ForEach { NewsCell } }.listStyle(.inset)
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(CkrWhite)
                        .verticalScroll(rememberScrollState())
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    news.forEach { item ->
                        // iOS NewsCell: title (headline), date (caption, gray), body (subheadline)
                        Column {
                            Text(
                                text = item.title,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = CkrDark,
                            )
                            Text(
                                text = DateUtils.formatDate(item.publicationDate),
                                style = MaterialTheme.typography.bodySmall,
                                color = CkrGray,
                            )
                            Text(
                                text = item.body,
                                style = MaterialTheme.typography.bodyMedium,
                                color = CkrDark,
                                maxLines = 3,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        if (item != news.last()) {
                            HorizontalDivider(color = CkrGray.copy(alpha = 0.2f))
                        }
                    }
                }
            } else {
                // Empty state — iOS: white rounded box with "No news at the moment"
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(CkrWhite),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No news at the moment",
                        style = MaterialTheme.typography.bodyMedium,
                        color = CkrGray,
                    )
                }
            }
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────

@Preview(showBackground = true)
@Composable
private fun CohouseTileWithCohousePreview() {
    CKRTheme {
        CohouseTile(
            cohouse = Cohouse(
                name = "Les Colocs du Soleil",
                address = PostalAddress(street = "Rue de la Loi 16", city = "Bruxelles", postalCode = "1000"),
                code = "ABC123",
            ),
            coverImageData = null,
            onClick = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun CohouseTileNoCohousePreview() {
    CKRTheme {
        CohouseTile(
            cohouse = null,
            coverImageData = null,
            onClick = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun RegistrationTileOpenPreview() {
    CKRTheme {
        RegistrationTile(
            game = CKRGame(
                registrationDeadline = Date(System.currentTimeMillis() + 7 * 24 * 3600 * 1000L),
                maxParticipants = 100,
                totalRegisteredParticipants = 42,
            ),
            isRegistered = false,
            onRegisterClick = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun RegistrationTileRegisteredPreview() {
    CKRTheme {
        RegistrationTile(
            game = CKRGame(),
            isRegistered = true,
            onRegisterClick = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun CountdownTileComingSoonPreview() {
    CKRTheme {
        CountdownTile(
            nextGameDate = null,
            countdownStart = null,
            hasCountdownStarted = false,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun CountdownTileActivePreview() {
    CKRTheme {
        CountdownTile(
            nextGameDate = Date(System.currentTimeMillis() + 3 * 24 * 3600 * 1000L),
            countdownStart = Date(System.currentTimeMillis() - 1000L),
            hasCountdownStarted = true,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun NewsTileWithNewsPreview() {
    CKRTheme {
        NewsTile(
            news = listOf(
                News(id = "1", title = "Nouvelle edition !", body = "La prochaine edition de la CKR arrive bientot. Restez connectes pour plus d'infos.", publicationDate = Date()),
                News(id = "2", title = "Resultats CKR #5", body = "Felicitations a tous les participants ! Decouvrez les resultats.", publicationDate = Date()),
            ),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun NewsTileEmptyPreview() {
    CKRTheme {
        NewsTile(news = emptyList())
    }
}
