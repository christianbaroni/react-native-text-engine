package com.rntextengine

import android.graphics.Color
import androidx.core.graphics.toColorInt

internal object RNTextEngineColorParser {
    fun parse(value: String?): Int? {
        if (value.isNullOrBlank()) return null

        val normalized = value.trim()
        parseRgbFunction(normalized)?.let { return it }
        return runCatching { normalized.toColorInt() }.getOrNull()
    }

    private fun parseRgbFunction(value: String): Int? {
        val openParen = value.indexOf('(')
        val closeParen = value.lastIndexOf(')')
        if (openParen <= 0 || closeParen <= openParen) return null

        val name = value.substring(0, openParen).trim().lowercase()
        if (name != "rgb" && name != "rgba") return null

        val body = value.substring(openParen + 1, closeParen)
        val parts = body.split(',')
        if (parts.size != 3 && parts.size != 4) return null

        val red = parts[0].trim().toFloatOrNull()?.coerceIn(0f, 255f)?.toInt() ?: return null
        val green = parts[1].trim().toFloatOrNull()?.coerceIn(0f, 255f)?.toInt() ?: return null
        val blue = parts[2].trim().toFloatOrNull()?.coerceIn(0f, 255f)?.toInt() ?: return null
        val alpha =
            if (parts.size == 4) {
                parts[3].trim().toFloatOrNull()?.coerceIn(0f, 1f)?.times(255f)?.toInt() ?: return null
            } else {
                255
            }

        return Color.argb(alpha, red, green, blue)
    }
}
