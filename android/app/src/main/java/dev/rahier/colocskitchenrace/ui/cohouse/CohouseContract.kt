package dev.rahier.colocskitchenrace.ui.cohouse

import dev.rahier.colocskitchenrace.data.model.Cohouse

data class CohouseState(
    val cohouse: Cohouse? = null,
    val coverImageData: ByteArray? = null,
    val joinCode: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is CohouseState) return false
        return cohouse == other.cohouse &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            joinCode == other.joinCode &&
            isLoading == other.isLoading &&
            error == other.error
    }

    override fun hashCode(): Int {
        var result = cohouse?.hashCode() ?: 0
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + joinCode.hashCode()
        result = 31 * result + isLoading.hashCode()
        result = 31 * result + (error?.hashCode() ?: 0)
        return result
    }
}

sealed interface CohouseIntent {
    data class JoinCodeChanged(val code: String) : CohouseIntent
    data object JoinClicked : CohouseIntent
    data object CreateClicked : CohouseIntent
    data object QuitClicked : CohouseIntent
    data object EditClicked : CohouseIntent
    data object Refresh : CohouseIntent
}
