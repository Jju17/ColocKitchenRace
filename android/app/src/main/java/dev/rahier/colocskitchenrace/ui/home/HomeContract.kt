package dev.rahier.colocskitchenrace.ui.home

import dev.rahier.colocskitchenrace.data.model.CKRGame
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.News

data class HomeState(
    val game: CKRGame? = null,
    val cohouse: Cohouse? = null,
    val coverImageData: ByteArray? = null,
    val news: List<News> = emptyList(),
    val isRegistered: Boolean = false,
    val isLoading: Boolean = false,
    // Edition
    val joinCode: String = "",
    val isJoiningEdition: Boolean = false,
    val isLeavingEdition: Boolean = false,
    val joinEditionError: String? = null,
    val joinEditionSuccess: String? = null,
    val activeEdition: CKRGame? = null,
    val activeEditionId: String? = null,
    val isLoadingEdition: Boolean = false,
) {
    val hasActiveEdition: Boolean get() = activeEditionId != null

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is HomeState) return false
        return game == other.game &&
            cohouse == other.cohouse &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            news == other.news &&
            isRegistered == other.isRegistered &&
            isLoading == other.isLoading &&
            joinCode == other.joinCode &&
            isJoiningEdition == other.isJoiningEdition &&
            isLeavingEdition == other.isLeavingEdition &&
            joinEditionError == other.joinEditionError &&
            joinEditionSuccess == other.joinEditionSuccess &&
            activeEdition == other.activeEdition &&
            activeEditionId == other.activeEditionId &&
            isLoadingEdition == other.isLoadingEdition
    }

    override fun hashCode(): Int {
        var result = game?.hashCode() ?: 0
        result = 31 * result + (cohouse?.hashCode() ?: 0)
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + news.hashCode()
        result = 31 * result + isRegistered.hashCode()
        result = 31 * result + isLoading.hashCode()
        result = 31 * result + joinCode.hashCode()
        result = 31 * result + isJoiningEdition.hashCode()
        result = 31 * result + isLeavingEdition.hashCode()
        result = 31 * result + (joinEditionError?.hashCode() ?: 0)
        result = 31 * result + (joinEditionSuccess?.hashCode() ?: 0)
        result = 31 * result + (activeEdition?.hashCode() ?: 0)
        result = 31 * result + (activeEditionId?.hashCode() ?: 0)
        result = 31 * result + isLoadingEdition.hashCode()
        return result
    }
}

sealed interface HomeIntent {
    data object Refresh : HomeIntent
    data class JoinCodeChanged(val code: String) : HomeIntent
    data object JoinEditionTapped : HomeIntent
    data object LeaveEditionTapped : HomeIntent
}
