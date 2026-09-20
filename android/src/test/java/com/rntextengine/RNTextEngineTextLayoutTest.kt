package com.rntextengine

import android.content.Context
import android.text.Layout
import android.text.TextPaint
import android.view.Gravity
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 35])
class RNTextEngineTextLayoutTest {
    @Test
    fun staticLayoutsUseTheSameAlignmentAsNativeGravity() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        for ((alignment, gravity) in listOf(
            "left" to Gravity.LEFT,
            "right" to Gravity.RIGHT,
            "center" to Gravity.CENTER_HORIZONTAL,
            null to Gravity.START,
            "auto" to Gravity.START,
            "justify" to Gravity.START,
        )) {
            val reference = TextView(context).apply {
                text = "שלום"
                textAlignment = View.TEXT_ALIGNMENT_GRAVITY
                this.gravity = Gravity.TOP or gravity
                measure(View.MeasureSpec.makeMeasureSpec(360, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(120, View.MeasureSpec.EXACTLY))
            }
            val layout = buildStaticLayoutCompat(
                text = reference.text,
                paint = TextPaint(reference.paint),
                widthPx = 360,
                includeFontPadding = false,
                breakStrategy = Layout.BREAK_STRATEGY_HIGH_QUALITY,
                hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
                maxLines = Int.MAX_VALUE,
                ellipsize = null,
                alignment = resolveLayoutAlignment(alignment),
            )
            assertSame(alignment, reference.layout.alignment, layout.alignment)
        }
    }
}
