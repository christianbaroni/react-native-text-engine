package com.rntextengine

import com.facebook.react.uimanager.PixelUtil
import com.facebook.yoga.YogaMeasureMode
import kotlin.math.max
import kotlin.math.min

internal data class RNTextEngineAutoSizeMeasurement(
    val heightPx: Float,
    val widthPx: Float,
)

private fun layoutDpFromPixels(pixels: Float): Double {
    val density = PixelUtil.getDisplayMetricDensity().toDouble()
    if (density <= 0.0) return max(0.0, pixels.toDouble())
    return max(0.0, pixels.toDouble()) / density
}

private fun pixelsFromLayoutDp(dp: Double): Float {
    return (dp * PixelUtil.getDisplayMetricDensity().toDouble()).toFloat()
}

internal fun measurePreparedAutoSizeText(
    handle: Long,
    widthPx: Float,
    widthMode: YogaMeasureMode,
    heightPx: Float,
    heightMode: YogaMeasureMode,
    numberOfLines: Int,
    ellipsizeMode: String?,
    anchorToCapHeight: Boolean,
): RNTextEngineAutoSizeMeasurement {
    val hasExactWidth = widthMode == YogaMeasureMode.EXACTLY
    val hasExactHeight = heightMode == YogaMeasureMode.EXACTLY
    if (hasExactWidth && hasExactHeight) {
        return RNTextEngineAutoSizeMeasurement(heightPx = heightPx, widthPx = widthPx)
    }

    val maxLines = if (numberOfLines > 0) numberOfLines else 0
    val constrainedWidthDp =
        when (widthMode) {
            YogaMeasureMode.EXACTLY, YogaMeasureMode.AT_MOST -> layoutDpFromPixels(widthPx)
            YogaMeasureMode.UNDEFINED -> RNTextEngineBindings.measurePreparedWidth(handle)
        }
    // AT_MOST must ask the real constrained layout owner directly. Pre-shrinking through an
    // intrinsic-width estimate can return a host width narrower than the actual maxWidth contract
    // and trigger premature middle ellipsis on text that fits.
    val layoutWidthDp =
        when (widthMode) {
            YogaMeasureMode.EXACTLY -> constrainedWidthDp
            YogaMeasureMode.AT_MOST, YogaMeasureMode.UNDEFINED -> constrainedWidthDp
        }
    val layout = RNTextEngineBindings.layout(handle, layoutWidthDp, maxLines, ellipsizeMode, anchorToCapHeight)

    val measuredWidthDp =
        when (widthMode) {
            YogaMeasureMode.EXACTLY -> constrainedWidthDp
            YogaMeasureMode.AT_MOST -> min(layout.getOrElse(0) { 0.0 }, constrainedWidthDp)
            YogaMeasureMode.UNDEFINED -> layout.getOrElse(0) { 0.0 }
        }
    val measuredWidthPx = pixelsFromLayoutDp(measuredWidthDp)

    val rawHeightPx = pixelsFromLayoutDp(layout.getOrElse(1) { 0.0 })
    val measuredHeightPx =
        when (heightMode) {
            YogaMeasureMode.EXACTLY -> heightPx
            YogaMeasureMode.AT_MOST -> min(rawHeightPx, heightPx)
            YogaMeasureMode.UNDEFINED -> rawHeightPx
        }

    return RNTextEngineAutoSizeMeasurement(heightPx = measuredHeightPx, widthPx = measuredWidthPx)
}
