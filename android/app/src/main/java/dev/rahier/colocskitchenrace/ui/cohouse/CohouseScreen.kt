package dev.rahier.colocskitchenrace.ui.cohouse

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import dev.rahier.colocskitchenrace.data.model.PostalAddress
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

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
            text = stringResource(R.string.no_cohouse_title),
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = joinCode,
            onValueChange = onJoinCodeChanged,
            label = { Text(stringResource(R.string.cohouse_code)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        )

        Spacer(modifier = Modifier.height(12.dp))

        CKRButton(
            text = stringResource(R.string.join),
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
            Text(text = "  ${stringResource(R.string.or)}  ", style = MaterialTheme.typography.bodySmall, color = CkrGray)
            HorizontalDivider(modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedButton(
            onClick = onCreateClicked,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text(stringResource(R.string.create_cohouse))
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

    // Reset "copied" indicator after 2 seconds
    LaunchedEffect(showCopied) {
        if (showCopied) {
            kotlinx.coroutines.delay(2000)
            showCopied = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Title row: cohouse name + edit button (like iOS)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = cohouse.name,
                style = MaterialTheme.typography.displaySmall,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onNavigateToEdit) {
                Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.edit))
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Cover image (like iOS: full width, rounded, default if no cover)
        CoverImageSection(state)

        Spacer(modifier = Modifier.height(16.dp))

        // Code card (lavender background, matching iOS purple card)
        CodeCard(
            code = cohouse.code,
            onCopy = {
                clipboardManager.setText(AnnotatedString(cohouse.code))
                showCopied = true
            },
            showCopied = showCopied,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Localisation section (table rows like iOS)
        LocalisationSection(cohouse)

        Spacer(modifier = Modifier.height(24.dp))

        // Members section
        MembersSection(cohouse)

        Spacer(modifier = Modifier.height(24.dp))

        // Quit cohouse
        TextButton(
            onClick = { onIntent(CohouseIntent.QuitClicked) },
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
        ) {
            Text(stringResource(R.string.quit_cohouse))
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun CoverImageSection(state: CohouseState) {
    val imageData = state.coverImageData
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(RoundedCornerShape(16.dp)),
    ) {
        if (imageData != null) {
            val bitmap = remember(imageData) {
                BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
            }
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = stringResource(R.string.cohouse_photo),
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
        } else {
            Image(
                painter = painterResource(id = R.drawable.default_coloc_background),
                contentDescription = stringResource(R.string.default_photo),
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

@Composable
private fun CodeCard(
    code: String,
    onCopy: () -> Unit,
    showCopied: Boolean,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CkrLavender),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.code_label, code),
                    style = MaterialTheme.typography.headlineSmall,
                    color = CkrWhite,
                )
                IconButton(
                    onClick = onCopy,
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.Default.ContentCopy,
                        contentDescription = stringResource(R.string.copy_code),
                        tint = CkrWhite.copy(alpha = 0.8f),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            Text(
                text = if (showCopied) stringResource(R.string.copy_code) else stringResource(R.string.share_code_hint),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = CkrWhite.copy(alpha = 0.85f),
            )
        }
    }
}

@Composable
private fun LocalisationSection(cohouse: Cohouse) {
    Text(
        text = stringResource(R.string.localisation),
        style = MaterialTheme.typography.labelLarge,
        color = CkrGray,
        letterSpacing = 1.sp,
    )

    Spacer(modifier = Modifier.height(8.dp))

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CkrWhite),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column {
            AddressRow(label = stringResource(R.string.address_label), value = cohouse.address.street)
            HorizontalDivider(color = CkrOffWhite)
            AddressRow(label = stringResource(R.string.zip_code_label), value = cohouse.address.postalCode)
            HorizontalDivider(color = CkrOffWhite)
            AddressRow(label = stringResource(R.string.city_label), value = cohouse.address.city)
        }
    }

    // Map (if coordinates available — like iOS Map with marker)
    if (cohouse.latitude != null && cohouse.longitude != null) {
        Spacer(modifier = Modifier.height(12.dp))
        val position = LatLng(cohouse.latitude, cohouse.longitude)
        val cameraPositionState = rememberCameraPositionState {
            this.position = CameraPosition.fromLatLngZoom(position, 15f)
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(16.dp)),
        ) {
            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    scrollGesturesEnabled = false,
                    zoomGesturesEnabled = false,
                    tiltGesturesEnabled = false,
                    rotationGesturesEnabled = false,
                    mapToolbarEnabled = false,
                ),
                properties = MapProperties(isMyLocationEnabled = false),
            ) {
                Marker(
                    state = MarkerState(position = position),
                    title = cohouse.name,
                )
            }
        }
    }
}

@Composable
private fun AddressRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = CkrGray,
        )
    }
}

@Composable
private fun MembersSection(cohouse: Cohouse) {
    Text(
        text = stringResource(R.string.members_section),
        style = MaterialTheme.typography.labelLarge,
        color = CkrGray,
        letterSpacing = 1.sp,
    )

    Spacer(modifier = Modifier.height(8.dp))

    cohouse.users.forEach { user ->
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 3.dp),
            colors = CardDefaults.cardColors(containerColor = CkrWhite),
            shape = RoundedCornerShape(12.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = user.surname,
                    style = MaterialTheme.typography.bodyLarge,
                )
                if (user.isAdmin) {
                    Surface(
                        color = CkrGold,
                        shape = RoundedCornerShape(8.dp),
                    ) {
                        Text(
                            text = stringResource(R.string.admin_badge),
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = CkrWhite,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

// ─── Previews ────────────────────────────────────────────────────────

@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun NoCohouseContentPreview() {
    CKRTheme {
        NoCohouseContent(
            joinCode = "",
            isLoading = false,
            error = null,
            onJoinCodeChanged = {},
            onJoinClicked = {},
            onCreateClicked = {},
        )
    }
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
private fun CohouseDetailContentPreview() {
    CKRTheme {
        CohouseDetailContent(
            state = CohouseState(
                cohouse = Cohouse(
                    name = "Les Colocs du Soleil",
                    address = PostalAddress(
                        street = "Rue de la Loi 16",
                        city = "Bruxelles",
                        postalCode = "1000",
                    ),
                    code = "CKR-2024",
                    users = listOf(
                        CohouseUser(surname = "Alice Dupont", isAdmin = true),
                        CohouseUser(surname = "Bob Martin", isAdmin = false),
                        CohouseUser(surname = "Charlie Leroy", isAdmin = false),
                    ),
                ),
            ),
            onIntent = {},
            onNavigateToEdit = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun CodeCardPreview() {
    CKRTheme {
        Box(modifier = Modifier.padding(16.dp)) {
            CodeCard(
                code = "CKR-2024",
                onCopy = {},
                showCopied = false,
            )
        }
    }
}
