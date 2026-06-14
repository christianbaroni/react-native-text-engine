package com.rntextengine

internal data class RNTextEngineNodeStyleInput(
    val hasAllowFontScaling: Boolean,
    val allowFontScaling: Boolean,
    val colorString: String?,
    val fontFamily: String?,
    val fontSize: Double,
    val fontStyle: String?,
    val fontWeight: String?,
    val hasLetterSpacing: Boolean,
    val letterSpacing: Double,
    val lineHeight: Double,
    val hasTabularNumbers: Boolean,
    val tabularNumbers: Boolean,
)

internal data class RNTextEngineResolvedStyleSnapshot(
    val allowFontScaling: Boolean,
    val colorString: String?,
    val fontFamily: String?,
    val fontSize: Double,
    val fontStyle: String?,
    val fontWeight: String?,
    val letterSpacing: Double,
    val lineHeight: Double,
    val tabularNumbers: Boolean,
)

internal fun resolveTextViewNodeStyle(
    parent: RNTextEngineResolvedStyleSnapshot?,
    input: RNTextEngineNodeStyleInput,
): RNTextEngineResolvedStyleSnapshot {
    val inherited =
        parent
            ?: RNTextEngineResolvedStyleSnapshot(
                allowFontScaling = input.allowFontScaling,
                colorString = input.colorString,
                fontFamily = input.fontFamily,
                fontSize = if (input.fontSize > 0) input.fontSize else 14.0,
                fontStyle = input.fontStyle,
                fontWeight = input.fontWeight,
                letterSpacing = input.letterSpacing,
                lineHeight = input.lineHeight,
                tabularNumbers = input.tabularNumbers,
            )

    var next = inherited
    if (parent == null || input.hasAllowFontScaling) next = next.copy(allowFontScaling = input.allowFontScaling)
    if (input.colorString != null) next = next.copy(colorString = input.colorString)
    if (!input.fontFamily.isNullOrEmpty()) next = next.copy(fontFamily = input.fontFamily)
    if (input.fontSize > 0) next = next.copy(fontSize = input.fontSize)
    if (!input.fontStyle.isNullOrEmpty()) next = next.copy(fontStyle = input.fontStyle)
    if (!input.fontWeight.isNullOrEmpty()) next = next.copy(fontWeight = input.fontWeight)
    if (parent == null || input.hasLetterSpacing) next = next.copy(letterSpacing = input.letterSpacing)
    if (input.lineHeight > 0.0) next = next.copy(lineHeight = input.lineHeight)
    if (parent == null || input.hasTabularNumbers) next = next.copy(tabularNumbers = input.tabularNumbers)
    return next
}

internal fun validateTextViewChildren(
    children: Iterable<Any?>,
    isTextViewChild: (Any?) -> Boolean,
    describeChild: (Any?) -> String,
): Boolean {
    var hasNested = false
    for (child in children) {
        if (!isTextViewChild(child)) {
            throw IllegalStateException(
                "RNTextEngine: TextView nested children must resolve to TextView nodes. Found `${describeChild(child)}`."
            )
        }
        hasNested = true
    }
    return hasNested
}
