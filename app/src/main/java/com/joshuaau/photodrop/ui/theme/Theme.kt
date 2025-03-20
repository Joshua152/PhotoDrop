package com.joshuaau.photodrop.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
        primary = Yellow80,
        secondary = Gray80,
        tertiary = Green80,
        onPrimary = Yellow20,
        onSecondary = Gray20,
        onTertiary = Green20,
        primaryContainer = Yellow30,
        secondaryContainer = Gray30,
        tertiaryContainer = Green30,
        onPrimaryContainer = Color.Black,
        onSecondaryContainer = Color.Black,
        onTertiaryContainer = Color.Black,
        surface = Black6,
        onSurface = Black90,
        error = Red80,
        onError = Red20,
        errorContainer = Red30,
        onErrorContainer = Red90
)

private val LightColorScheme = lightColorScheme(
        primary = Yellow40,
        secondary = Gray40,
        tertiary = Green40,
        onPrimary = Color.White,
        onSecondary = Color.White,
        onTertiary = Color.White,
        primaryContainer = Yellow90,
        secondaryContainer = Gray90,
        tertiaryContainer = Green90,
        onPrimaryContainer = Color.Black,
        onSecondaryContainer = Color.Black,
        onTertiaryContainer = Color.Black,
        surface = Beige98,
        onSurface = Black10,
        error = Red40,
        onError = Color.White,
        errorContainer = Red90,
        onErrorContainer = Color.White

        /* Other default colors to override
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color(0xFF1C1B1F),
    onSurface = Color(0xFF1C1B1F),
    */
)

@Composable
fun PhotoDropTheme(
        darkTheme: Boolean = isSystemInDarkTheme(),
        // Dynamic color is available on Android 12+
        dynamicColor: Boolean = true,
        content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = darkTheme
        }
    }

    MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            content = content
    )
}