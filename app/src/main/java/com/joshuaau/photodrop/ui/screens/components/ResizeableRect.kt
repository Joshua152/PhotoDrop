package com.joshuaau.photodrop.ui.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.min

@Composable
fun ResizeableRect(modifier: Modifier = Modifier, width: Int, height: Int, onSizeChanged: (Int, Int) -> Unit) {
    var widthState by remember { mutableIntStateOf(width) }
    var heightState by remember { mutableIntStateOf(height) }

    val colorPrimary = MaterialTheme.colorScheme.primary

    val density = LocalDensity.current
    var composableWidth by remember { mutableIntStateOf(0) }
    var composableHeight by remember { mutableIntStateOf(0) }
    Box(modifier = modifier
        .onGloballyPositioned { coordinates ->
            composableWidth = coordinates.size.width
            composableHeight = coordinates.size.height
        }
    ) {
        Box(
            modifier = Modifier
                .size(width = with(density) { widthState.toDp() }, height = with(density) { heightState.toDp() })
                .border(2.dp, colorPrimary)
                .align(Alignment.Center)
        )
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .offset(x = with(density) { widthState.toDp() } / 2 - 2.5.dp, y = with(density) { heightState.toDp() } / 2 - 2.5.dp)
                .size(width = 15.dp, height = 15.dp)
                .clip(CircleShape)
                .background(colorPrimary)
        )
        // Draggable area (Start event has to be within bottom right quadrant)
        Box(
            modifier = Modifier
                .fillMaxSize(0.5f)
                .align(AbsoluteAlignment.BottomRight)
                .pointerInput(Unit) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        widthState = min(max(100.dp.toPx().toInt(), widthState + 2 * dragAmount.x.toInt()), composableWidth)
                        heightState = min(max(100.dp.toPx().toInt(), heightState + 2 * dragAmount.y.toInt()), composableHeight)

                        onSizeChanged(widthState, heightState)
                    }
                }
        )
    }
}