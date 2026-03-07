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
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is HomeState) return false
        return game == other.game &&
            cohouse == other.cohouse &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            news == other.news &&
            isRegistered == other.isRegistered &&
            isLoading == other.isLoading
    }

    override fun hashCode(): Int {
        var result = game?.hashCode() ?: 0
        result = 31 * result + (cohouse?.hashCode() ?: 0)
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + news.hashCode()
        result = 31 * result + isRegistered.hashCode()
        result = 31 * result + isLoading.hashCode()
        return result
    }
}

sealed interface HomeIntent {
    data object RegisterClicked : HomeIntent
    data object ProfileClicked : HomeIntent
    data object Refresh : HomeIntent
}
