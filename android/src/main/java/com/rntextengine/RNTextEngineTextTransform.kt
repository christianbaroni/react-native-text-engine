package com.rntextengine

import java.text.BreakIterator
import java.util.Locale

internal data class RNTextEngineTransformedText(
    val offsetsByOriginal: Map<Int, Int>,
    val text: String,
)

internal fun applyTextTransform(text: String, textTransform: String?): String {
    return when (textTransform) {
        "uppercase" -> text.uppercase(Locale.getDefault())
        "lowercase" -> text.lowercase(Locale.getDefault())
        "capitalize" -> {
            val wordIterator = BreakIterator.getWordInstance()
            wordIterator.setText(text)

            val result = StringBuilder(text.length)
            var start = wordIterator.first()
            var end = wordIterator.next()
            while (end != BreakIterator.DONE) {
                result.append(text.substring(start, end).replaceFirstChar { it.uppercaseChar() })
                start = end
                end = wordIterator.next()
            }
            result.toString()
        }
        else -> text
    }
}

internal fun transformText(
    text: String,
    textTransform: String?,
    boundaries: Collection<Int> = emptyList(),
): RNTextEngineTransformedText {
    val transformedText = applyTextTransform(text, textTransform)
    if (boundaries.isEmpty() || transformedText == text) {
        return RNTextEngineTransformedText(offsetsByOriginal = emptyMap(), text = transformedText)
    }

    val offsetsByOriginal = HashMap<Int, Int>(boundaries.size + 2)
    val resolvedBoundaries =
        buildSet {
            add(0)
            add(text.length)
            boundaries.forEach { boundary ->
                if (boundary in 0..text.length) add(boundary)
            }
        }.sorted()

    resolvedBoundaries.forEach { boundary ->
        offsetsByOriginal[boundary] = applyTextTransform(text.substring(0, boundary), textTransform).length
    }

    return RNTextEngineTransformedText(offsetsByOriginal = offsetsByOriginal, text = transformedText)
}
