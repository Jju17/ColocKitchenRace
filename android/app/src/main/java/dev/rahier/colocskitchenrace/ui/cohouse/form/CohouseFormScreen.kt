package dev.rahier.colocskitchenrace.ui.cohouse.form

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
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.ValidatedAddress
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.components.CKRButton
import dev.rahier.colocskitchenrace.ui.theme.*

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

    val imagePickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            val bytes = context.contentResolver.openInputStream(it)?.readBytes()
            if (bytes != null) {
                viewModel.onIntent(CohouseFormIntent.CoverImagePicked(bytes))
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

            Spacer(modifier = Modifier.height(24.dp))

            // Cover image
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
                    onClick = { imagePickerLauncher.launch("image/*") },
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

            Spacer(modifier = Modifier.height(24.dp))

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
    // Note: We can't easily call the viewModel from here without restructuring.
    // The suggestion is shown but the apply action is handled at the form level.
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
