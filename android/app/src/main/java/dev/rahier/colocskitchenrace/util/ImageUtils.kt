package dev.rahier.colocskitchenrace.util

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream

object ImageUtils {
    fun compressToJpeg(data: ByteArray, maxBytes: Int = 500_000): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return data
        var quality = 85
        var output: ByteArray
        do {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
            output = stream.toByteArray()
            quality -= 10
        } while (output.size > maxBytes && quality > 10)
        return output
    }
}
