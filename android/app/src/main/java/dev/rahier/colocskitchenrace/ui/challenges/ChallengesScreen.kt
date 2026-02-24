package dev.rahier.colocskitchenrace.ui.challenges

import android.Manifest
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.Challenge
import dev.rahier.colocskitchenrace.data.model.ChallengeContent
import dev.rahier.colocskitchenrace.data.model.ChallengeResponse
import dev.rahier.colocskitchenrace.data.model.ChallengeResponseStatus
import dev.rahier.colocskitchenrace.data.model.ChallengeState
import dev.rahier.colocskitchenrace.ui.theme.*
import dev.rahier.colocskitchenrace.util.DateUtils
import java.io.File
import kotlin.math.absoluteValue

enum class ChallengeFilter(val label: String) {
    ALL("Tous"),
    TODO("A faire"),
    WAITING("En attente"),
    REVIEWED("Evalues"),
}

// Stable color palette for challenge headers
private val challengeHeaderColors = listOf(CkrCoral, CkrSky, CkrLavender, CkrMint, CkrGold)

private fun challengeColor(challengeId: String): Color {
    val index = challengeId.hashCode().absoluteValue % challengeHeaderColors.size
    return challengeHeaderColors[index]
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
            Text(
                text = "Challenges",
                style = MaterialTheme.typography.headlineLarge,
                color = CkrDark,
            )
            IconButton(onClick = onShowLeaderboard) {
                Icon(Icons.Default.EmojiEvents, contentDescription = "Classement", tint = CkrGray)
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Filter chips - capsule style like iOS
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ChallengeFilter.entries.forEach { filter ->
                val isSelected = state.selectedFilter == filter
                Surface(
                    onClick = { viewModel.onIntent(ChallengesIntent.FilterSelected(filter)) },
                    shape = RoundedCornerShape(50),
                    color = if (isSelected) CkrMint else CkrOffWhite,
                ) {
                    Text(
                        text = filter.label,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (isSelected) CkrWhite else CkrDark,
                    )
                }
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
                val isParticipating = state.participatingChallengeId == challenge.id
                val response = state.responseFor(challenge.id)

                ChallengeTileCard(
                    challenge = challenge,
                    hasCohouse = state.hasCohouse,
                    isParticipating = isParticipating,
                    response = response,
                    selectedChoiceIndex = if (isParticipating) state.selectedChoiceIndex else null,
                    textAnswer = if (isParticipating) state.textAnswer else "",
                    capturedImageData = if (isParticipating) state.capturedImageData else null,
                    isSubmitting = isParticipating && state.isSubmitting,
                    submitError = if (isParticipating) state.submitError else null,
                    onParticipate = { viewModel.onIntent(ChallengesIntent.StartChallenge(challenge.id)) },
                    onCancel = { viewModel.onIntent(ChallengesIntent.CancelParticipation) },
                    onSelectChoice = { viewModel.onIntent(ChallengesIntent.SelectChoice(it)) },
                    onTextChanged = { viewModel.onIntent(ChallengesIntent.TextAnswerChanged(it)) },
                    onPhotoCaptured = { viewModel.onIntent(ChallengesIntent.PhotoCaptured(it)) },
                    onSubmit = { viewModel.onIntent(ChallengesIntent.SubmitResponse) },
                )
            }

            // Page dots - mint active like iOS
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
            ) {
                repeat(state.filteredChallenges.size) { index ->
                    val isActive = pagerState.currentPage == index
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 3.dp)
                            .size(if (isActive) 8.dp else 6.dp)
                            .clip(CircleShape)
                            .background(
                                if (isActive) CkrMint else CkrGray.copy(alpha = 0.3f)
                            ),
                    )
                }
            }
        }
    }
}

// ─── Two-Part Challenge Card ─────────────────────────────────────────

@Composable
private fun ChallengeTileCard(
    challenge: Challenge,
    hasCohouse: Boolean,
    isParticipating: Boolean,
    response: ChallengeResponse?,
    selectedChoiceIndex: Int?,
    textAnswer: String,
    capturedImageData: ByteArray?,
    isSubmitting: Boolean,
    submitError: String?,
    onParticipate: () -> Unit,
    onCancel: () -> Unit,
    onSelectChoice: (Int) -> Unit,
    onTextChanged: (String) -> Unit,
    onPhotoCaptured: (ByteArray) -> Unit,
    onSubmit: () -> Unit,
) {
    val headerColor = challengeColor(challenge.id)

    Card(
        modifier = Modifier
            .fillMaxSize()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(20.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
            ),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = CkrWhite),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // ── Colored Header ──
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(headerColor)
                    .padding(20.dp),
            ) {
                Column {
                    // Title
                    Text(
                        text = challenge.title.uppercase(),
                        style = MaterialTheme.typography.headlineMedium,
                        color = CkrWhite,
                        fontWeight = FontWeight.Bold,
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Date range
                    Text(
                        text = "${DateUtils.formatDate(challenge.startDate)} - ${DateUtils.formatDate(challenge.endDate)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = CkrWhite.copy(alpha = 0.85f),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Badges row
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        // Points badge
                        challenge.points?.let { pts ->
                            Surface(
                                shape = RoundedCornerShape(50),
                                color = CkrWhite.copy(alpha = 0.25f),
                            ) {
                                Text(
                                    text = "$pts pts",
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = CkrWhite,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }

                        // State badge
                        val stateLabel = when (challenge.state) {
                            ChallengeState.ONGOING -> "En cours"
                            ChallengeState.DONE -> "Termine"
                            ChallengeState.NOT_STARTED -> "A venir"
                        }
                        Surface(
                            shape = RoundedCornerShape(50),
                            color = CkrWhite.copy(alpha = 0.25f),
                        ) {
                            Text(
                                text = stateLabel,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                style = MaterialTheme.typography.labelSmall,
                                color = CkrWhite,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }

            // ── White Body ── (description top, actions bottom)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(20.dp),
            ) {
                // Description at top
                Text(
                    text = challenge.body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = CkrDark,
                    overflow = TextOverflow.Ellipsis,
                )

                // Push action area to bottom
                Spacer(modifier = Modifier.weight(1f))

                // Action area at bottom
                when {
                    // Already reviewed
                    response != null && response.status != ChallengeResponseStatus.WAITING -> {
                        FinalStatusSection(response)
                    }
                    // Waiting for admin review
                    response != null -> {
                        WaitingReviewSection()
                    }
                    // Currently participating — inline form
                    isParticipating -> {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            when (challenge.content) {
                                is ChallengeContent.NoChoice -> NoChoiceForm(
                                    isSubmitting = isSubmitting,
                                    onSubmit = onSubmit,
                                )
                                is ChallengeContent.SingleAnswer -> SingleAnswerForm(
                                    textAnswer = textAnswer,
                                    isSubmitting = isSubmitting,
                                    onTextChanged = onTextChanged,
                                    onSubmit = onSubmit,
                                )
                                is ChallengeContent.MultipleChoice -> MultipleChoiceForm(
                                    choices = challenge.content.choices,
                                    selectedIndex = selectedChoiceIndex,
                                    isSubmitting = isSubmitting,
                                    onSelectChoice = onSelectChoice,
                                    onSubmit = onSubmit,
                                )
                                is ChallengeContent.Picture -> PictureForm(
                                    capturedImageData = capturedImageData,
                                    isSubmitting = isSubmitting,
                                    onPhotoCaptured = onPhotoCaptured,
                                    onSubmit = onSubmit,
                                )
                            }

                            submitError?.let {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = it,
                                    color = MaterialTheme.colorScheme.error,
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            }

                            Spacer(modifier = Modifier.height(4.dp))

                            TextButton(onClick = onCancel) {
                                Text("Annuler", color = CkrGray)
                            }
                        }
                    }
                    // Can participate
                    challenge.state == ChallengeState.ONGOING && hasCohouse -> {
                        Button(
                            onClick = onParticipate,
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(15.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
                        ) {
                            Text(
                                text = "Participer",
                                color = CkrWhite,
                                style = MaterialTheme.typography.labelLarge,
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─── Inline Forms ────────────────────────────────────────────────────

@Composable
private fun NoChoiceForm(
    isSubmitting: Boolean,
    onSubmit: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = CkrMint,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Tu as releve le defi ?",
            style = MaterialTheme.typography.bodyMedium,
            color = CkrGray,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            onClick = onSubmit,
            enabled = !isSubmitting,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
        ) {
            if (isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = CkrWhite, strokeWidth = 2.dp)
            } else {
                Text("C'est fait !", color = CkrWhite, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun SingleAnswerForm(
    textAnswer: String,
    isSubmitting: Boolean,
    onTextChanged: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = textAnswer,
            onValueChange = onTextChanged,
            label = { Text("Ta reponse") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            minLines = 2,
            maxLines = 5,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            onClick = onSubmit,
            enabled = !isSubmitting && textAnswer.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
        ) {
            if (isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = CkrWhite, strokeWidth = 2.dp)
            } else {
                Text("Envoyer", color = CkrWhite, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun MultipleChoiceForm(
    choices: List<String>,
    selectedIndex: Int?,
    isSubmitting: Boolean,
    onSelectChoice: (Int) -> Unit,
    onSubmit: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        choices.forEachIndexed { index, choice ->
            if (choice.isBlank()) return@forEachIndexed

            val isSelected = selectedIndex == index
            val backgroundColor by animateColorAsState(
                targetValue = if (isSelected) CkrSky else CkrOffWhite,
                label = "choiceBg",
            )
            val borderColor by animateColorAsState(
                targetValue = if (isSelected) CkrSky else CkrGray.copy(alpha = 0.3f),
                label = "choiceBorder",
            )
            val textColor = if (isSelected) CkrWhite else CkrDark

            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .border(1.dp, borderColor, RoundedCornerShape(12.dp))
                    .clickable { onSelectChoice(index) },
                shape = RoundedCornerShape(12.dp),
                color = backgroundColor,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = choice,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = textColor,
                        modifier = Modifier.weight(1f),
                    )
                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = CkrWhite,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            onClick = onSubmit,
            enabled = !isSubmitting && selectedIndex != null,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(15.dp),
            colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
        ) {
            if (isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = CkrWhite, strokeWidth = 2.dp)
            } else {
                Text("Envoyer", color = CkrWhite, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun PictureForm(
    capturedImageData: ByteArray?,
    isSubmitting: Boolean,
    onPhotoCaptured: (ByteArray) -> Unit,
    onSubmit: () -> Unit,
) {
    val context = LocalContext.current
    var showPhotoDialog by remember { mutableStateOf(false) }

    // Create temp file for camera capture
    val tempImageFile = remember {
        File(context.cacheDir, "challenge_photo.jpg").also {
            if (!it.exists()) it.createNewFile()
        }
    }
    val tempImageUri = remember {
        FileProvider.getUriForFile(context, "${context.packageName}.provider", tempImageFile)
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            context.contentResolver.openInputStream(tempImageUri)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isNotEmpty()) onPhotoCaptured(bytes)
            }
        }
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            context.contentResolver.openInputStream(it)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isNotEmpty()) onPhotoCaptured(bytes)
            }
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            cameraLauncher.launch(tempImageUri)
        }
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (capturedImageData != null) {
            val bitmap = remember(capturedImageData) {
                BitmapFactory.decodeByteArray(capturedImageData, 0, capturedImageData.size)
            }
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = "Photo selectionnee",
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 200.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .border(2.dp, CkrMint.copy(alpha = 0.5f), RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop,
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            TextButton(onClick = { showPhotoDialog = true }) {
                Text("Changer la photo", color = CkrSky)
            }

            Spacer(modifier = Modifier.height(8.dp))

            Button(
                onClick = onSubmit,
                enabled = !isSubmitting,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(15.dp),
                colors = ButtonDefaults.buttonColors(containerColor = CkrMint),
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), color = CkrWhite, strokeWidth = 2.dp)
                } else {
                    Text("Envoyer la photo", color = CkrWhite, style = MaterialTheme.typography.labelLarge)
                }
            }
        } else {
            OutlinedButton(
                onClick = { showPhotoDialog = true },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(15.dp),
            ) {
                Icon(Icons.Default.PhotoCamera, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Prendre ou choisir une photo")
            }
        }
    }

    if (showPhotoDialog) {
        AlertDialog(
            onDismissRequest = { showPhotoDialog = false },
            title = { Text("Choisir une source") },
            text = { Text("Comment souhaitez-vous ajouter votre photo ?") },
            confirmButton = {
                TextButton(onClick = {
                    showPhotoDialog = false
                    cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                }) {
                    Text("Camera")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showPhotoDialog = false
                    galleryLauncher.launch("image/*")
                }) {
                    Text("Galerie")
                }
            },
        )
    }
}

// ─── Status Sections ─────────────────────────────────────────────────

@Composable
private fun WaitingReviewSection() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Default.HourglassEmpty,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = CkrGold,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "En attente de validation",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = CkrGold,
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = "Ta reponse a ete envoyee. Un admin va bientot l'evaluer.",
            style = MaterialTheme.typography.bodySmall,
            color = CkrGray,
        )
    }
}

@Composable
private fun FinalStatusSection(response: ChallengeResponse) {
    val isValidated = response.status == ChallengeResponseStatus.VALIDATED
    val icon = if (isValidated) Icons.Default.CheckCircle else Icons.Default.Cancel
    val color = if (isValidated) CkrMint else CkrCoral
    val title = if (isValidated) "Valide !" else "Invalide"
    val subtitle = if (isValidated) {
        "Bravo ! Ton defi a ete valide."
    } else {
        "Malheureusement, ta reponse n'a pas ete acceptee."
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = color,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color,
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = CkrGray,
        )
    }
}
