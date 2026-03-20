package dev.rahier.colocskitchenrace.ui.cohouse.form

import android.Manifest
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.CohouseType
import dev.rahier.colocskitchenrace.data.model.IdCardScanResult
import dev.rahier.colocskitchenrace.data.model.ValidatedAddress
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CohouseFormScreen(
    isEditMode: Boolean,
    viewModel: CohouseFormViewModel = hiltViewModel(),
    onSaved: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var showCoverPhotoDialog by remember { mutableStateOf(false) }

    // Camera for cover image
    val tempCoverFile = remember {
        val dir = File(context.cacheDir, "cohouse_photos").also { it.mkdirs() }
        File(dir, "cover_photo.jpg").also { if (!it.exists()) it.createNewFile() }
    }
    val tempCoverUri = remember {
        FileProvider.getUriForFile(context, "${context.packageName}.provider", tempCoverFile)
    }

    val coverCameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            context.contentResolver.openInputStream(tempCoverUri)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isNotEmpty()) viewModel.onIntent(CohouseFormIntent.CoverImagePicked(bytes))
            }
        }
    }

    val coverGalleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            context.contentResolver.openInputStream(it)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isNotEmpty()) viewModel.onIntent(CohouseFormIntent.CoverImagePicked(bytes))
            }
        }
    }

    val coverCameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) coverCameraLauncher.launch(tempCoverUri)
    }

    // ID card picker (gallery only)
    val idCardPickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            context.contentResolver.openInputStream(it)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isNotEmpty()) viewModel.onIntent(CohouseFormIntent.IdCardPicked(bytes))
            }
        }
    }

    LaunchedEffect(isEditMode) {
        if (isEditMode) viewModel.initForEdit() else viewModel.initForCreate()
    }

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                CohouseFormEffect.Saved -> onSaved()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isEditMode) stringResource(R.string.edit_cohouse) else stringResource(R.string.create_cohouse)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
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
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            // Cohouse name
            Text(text = stringResource(R.string.cohouse_name), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.name,
                onValueChange = { viewModel.onIntent(CohouseFormIntent.NameChanged(it)) },
                label = { Text(stringResource(R.string.cohouse_name_label)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Cohouse type picker
            Text(text = stringResource(R.string.cohouse_type_title), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                CohouseType.entries.forEachIndexed { index, type ->
                    SegmentedButton(
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = CohouseType.entries.size),
                        onClick = { viewModel.onIntent(CohouseFormIntent.CohouseTypeChanged(type)) },
                        selected = state.cohouseType == type,
                    ) {
                        Text(type.displayName)
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Cover image (CKR-12: camera + gallery)
            Text(text = stringResource(R.string.cover_image), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))

            if (state.coverImageData != null) {
                val bitmap = remember(state.coverImageData) {
                    BitmapFactory.decodeByteArray(state.coverImageData!!, 0, state.coverImageData!!.size)
                }
                if (bitmap != null) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .clip(RoundedCornerShape(12.dp)),
                    ) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = stringResource(R.string.cover_image),
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                        IconButton(
                            onClick = { viewModel.onIntent(CohouseFormIntent.CoverImageCleared) },
                            modifier = Modifier.align(Alignment.TopEnd),
                        ) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = stringResource(R.string.delete_photo),
                                tint = CkrWhite,
                            )
                        }
                    }
                }
            } else {
                OutlinedButton(
                    onClick = { showCoverPhotoDialog = true },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium,
                ) {
                    Icon(Icons.Default.AddAPhoto, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.choose_photo))
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Address
            Text(text = stringResource(R.string.address), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.street,
                onValueChange = { viewModel.onIntent(CohouseFormIntent.StreetChanged(it)) },
                label = { Text(stringResource(R.string.street_and_number)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = state.postalCode,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.PostalCodeChanged(it)) },
                    label = { Text(stringResource(R.string.postal_code)) },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = MaterialTheme.shapes.medium,
                )
                OutlinedTextField(
                    value = state.city,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.CityChanged(it)) },
                    label = { Text(stringResource(R.string.city)) },
                    singleLine = true,
                    modifier = Modifier.weight(2f),
                    shape = MaterialTheme.shapes.medium,
                )
            }

            // Address validation status
            Spacer(modifier = Modifier.height(8.dp))
            AddressValidationStatus(state)

            // Map picker button (CKR-13) — shown when coordinates are available
            if (state.latitude != null && state.longitude != null) {
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(
                    onClick = { viewModel.onIntent(CohouseFormIntent.ShowMapPicker) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium,
                ) {
                    Icon(Icons.Default.Place, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.adjust_map_pin))
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // ID card scan (CKR-11) — only for create mode
            if (!state.isEditMode) {
                Text(text = stringResource(R.string.scan_id_card), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(
                    onClick = { idCardPickerLauncher.launch("image/*") },
                    enabled = !state.isProcessingIdCard,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium,
                ) {
                    if (state.isProcessingIdCard) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = CkrLavender)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(stringResource(R.string.id_card_scanning))
                    } else {
                        Icon(Icons.Default.CreditCard, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(stringResource(R.string.scan_id_card))
                    }
                }

                // ID card scan result
                state.idCardScanResult?.let { result ->
                    Spacer(modifier = Modifier.height(8.dp))
                    IdCardScanStatus(result)
                }

                Spacer(modifier = Modifier.height(24.dp))
            }

            // Members
            Text(text = stringResource(R.string.members_count, state.members.size), style = MaterialTheme.typography.titleMedium, color = CkrLavender)
            Spacer(modifier = Modifier.height(8.dp))

            state.members.forEach { member ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
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
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(text = member.surname, style = MaterialTheme.typography.bodyLarge)
                            if (member.isAdmin) {
                                Surface(color = CkrGold, shape = MaterialTheme.shapes.small) {
                                    Text(
                                        text = stringResource(R.string.admin_badge),
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = CkrWhite,
                                    )
                                }
                            }
                        }
                        if (!member.isAdmin) {
                            IconButton(
                                onClick = { viewModel.onIntent(CohouseFormIntent.RemoveMember(member.id)) },
                                modifier = Modifier.size(24.dp),
                            ) {
                                Icon(Icons.Default.Close, contentDescription = stringResource(R.string.remove_member), tint = CkrCoral)
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Add member
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = state.newMemberName,
                    onValueChange = { viewModel.onIntent(CohouseFormIntent.NewMemberNameChanged(it)) },
                    label = { Text(stringResource(R.string.new_member)) },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                    shape = MaterialTheme.shapes.medium,
                )
                IconButton(
                    onClick = { viewModel.onIntent(CohouseFormIntent.AddMember) },
                    enabled = state.newMemberName.isNotBlank(),
                ) {
                    Icon(Icons.Default.PersonAdd, contentDescription = stringResource(R.string.add), tint = CkrMint)
                }
            }

            // Error
            state.error?.let { error ->
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Save button
            CKRButton(
                text = if (state.isEditMode) stringResource(R.string.save) else stringResource(R.string.create_cohouse_button),
                onClick = { viewModel.onIntent(CohouseFormIntent.Save) },
                isLoading = state.isSaving,
                enabled = state.canSave,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }

    // Cover photo source dialog (CKR-12)
    if (showCoverPhotoDialog) {
        AlertDialog(
            onDismissRequest = { showCoverPhotoDialog = false },
            title = { Text(stringResource(R.string.choose_source)) },
            text = { Text(stringResource(R.string.choose_source_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showCoverPhotoDialog = false
                    coverCameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                }) {
                    Text(stringResource(R.string.camera))
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showCoverPhotoDialog = false
                    coverGalleryLauncher.launch("image/*")
                }) {
                    Text(stringResource(R.string.gallery))
                }
            },
        )
    }

    // Map picker dialog (CKR-13)
    if (state.showMapPicker && state.latitude != null && state.longitude != null) {
        MapPickerDialog(
            latitude = state.latitude!!,
            longitude = state.longitude!!,
            onPinMoved = { lat, lng -> viewModel.onIntent(CohouseFormIntent.MapPinMoved(lat, lng)) },
            onDismiss = { viewModel.onIntent(CohouseFormIntent.DismissMapPicker) },
        )
    }
}

@Composable
private fun IdCardScanStatus(result: IdCardScanResult) {
    when (result) {
        is IdCardScanResult.Valid -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = CkrMint, modifier = Modifier.size(18.dp))
                Column {
                    Text(stringResource(R.string.id_card_valid), style = MaterialTheme.typography.bodySmall, color = CkrMint)
                    result.info.name?.let { name ->
                        Text(stringResource(R.string.id_card_name, name), style = MaterialTheme.typography.bodySmall, color = CkrGray)
                    }
                }
            }
        }
        is IdCardScanResult.NotAnIdCard -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = CkrCoral, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.id_card_not_found), style = MaterialTheme.typography.bodySmall, color = CkrCoral)
            }
        }
        is IdCardScanResult.PoorQuality -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.Warning, contentDescription = null, tint = CkrGold, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.id_card_poor_quality), style = MaterialTheme.typography.bodySmall, color = CkrGold)
            }
        }
        is IdCardScanResult.Error -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = CkrCoral, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.id_card_error), style = MaterialTheme.typography.bodySmall, color = CkrCoral)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MapPickerDialog(
    latitude: Double,
    longitude: Double,
    onPinMoved: (Double, Double) -> Unit,
    onDismiss: () -> Unit,
) {
    val markerState = remember(latitude, longitude) {
        MarkerState(position = LatLng(latitude, longitude))
    }
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LatLng(latitude, longitude), 16f)
    }

    // Track marker drag
    LaunchedEffect(markerState.position) {
        val pos = markerState.position
        if (pos.latitude != latitude || pos.longitude != longitude) {
            onPinMoved(pos.latitude, pos.longitude)
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.map_picker_title)) },
        text = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .clip(RoundedCornerShape(12.dp)),
            ) {
                GoogleMap(
                    modifier = Modifier.fillMaxSize(),
                    cameraPositionState = cameraPositionState,
                ) {
                    Marker(
                        state = markerState,
                        draggable = true,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.confirm))
            }
        },
    )
}

@Composable
private fun AddressValidationStatus(state: CohouseFormState) {
    when {
        state.isValidatingAddress -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = CkrLavender)
                Text(stringResource(R.string.address_validating), style = MaterialTheme.typography.bodySmall, color = CkrGray)
            }
        }
        state.addressValidationResult is AddressValidationResult.Valid -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = CkrMint, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.address_validated), style = MaterialTheme.typography.bodySmall, color = CkrMint)
            }
        }
        state.addressValidationResult is AddressValidationResult.LowConfidence -> {
            val suggested = (state.addressValidationResult as AddressValidationResult.LowConfidence).address
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Default.Warning, contentDescription = null, tint = CkrGold, modifier = Modifier.size(18.dp))
                    Text(stringResource(R.string.address_uncertain), style = MaterialTheme.typography.bodySmall, color = CkrGold)
                }
                Spacer(modifier = Modifier.height(4.dp))
                SuggestedAddressCard(suggested) { state }
            }
        }
        state.addressValidationResult is AddressValidationResult.NotFound -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = CkrCoral, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.address_not_found), style = MaterialTheme.typography.bodySmall, color = CkrCoral)
            }
        }
    }
}

@Composable
private fun SuggestedAddressCard(suggested: ValidatedAddress, stateProvider: () -> CohouseFormState) {
    Card(
        colors = CardDefaults.cardColors(containerColor = CkrLavenderLight),
        shape = RoundedCornerShape(8.dp),
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = stringResource(R.string.address_suggestion, suggested.street, suggested.postalCode, suggested.city),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}
