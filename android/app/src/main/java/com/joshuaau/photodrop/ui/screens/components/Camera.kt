package com.joshuaau.photodrop.ui.screens.components

import android.Manifest
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Log
import android.widget.Toast
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberPermissionState
import com.joshuaau.photodrop.R
import com.joshuaau.photodrop.viewmodel.BoundingBox
import com.joshuaau.photodrop.viewmodel.CameraClipState
import com.joshuaau.photodrop.viewmodel.CameraViewModel
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun CameraPreview(cameraViewModel: CameraViewModel = viewModel()) {
    val context = LocalContext.current

    val cameraViewState by cameraViewModel.cameraState.collectAsState()

    val permissionState = rememberPermissionState(Manifest.permission.CAMERA)
    LaunchedEffect(Unit) {
        if (!permissionState.hasPermission) {
            permissionState.launchPermissionRequest()
        }
    }

    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }
    val cameraProvider = cameraProviderFuture.get()
    val preview = remember { Preview.Builder().build() }
    var imageCapture by remember { mutableStateOf<ImageCapture?>(null) }

    var isCapturing by remember { mutableStateOf(false) }

    var previewWidth by remember { mutableFloatStateOf(0f) }
    var previewHeight by remember { mutableFloatStateOf(0f) }

    val colorPrimary = MaterialTheme.colorScheme.primary

    var borderWidth = 0.dp
    var showCenterDot = false
    if (
        cameraViewState.processingState == CameraClipState.PROCESSING_CLIP ||
        cameraViewState.processingState == CameraClipState.CLIPPED
    ) {
        borderWidth = 2.dp
    }

    if (cameraViewState.processingState == CameraClipState.CLIPPED) {
        borderWidth = 10.dp
        showCenterDot = true
    }

    Log.i("PHOTO", "State: ${cameraViewState.processingState}")

    if (permissionState.hasPermission) {
        Box(
            modifier = Modifier
                .border(color = colorPrimary, width = borderWidth)
                .onGloballyPositioned { coordinates ->
                    previewWidth = coordinates.size.width.toFloat()
                    previewHeight = coordinates.size.height.toFloat()
                }
        ) {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                    val previewView = PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                    }
                    cameraProviderFuture.addListener({
                        imageCapture = ImageCapture.Builder()
                            .setTargetRotation(previewView.display.rotation)
                            .build()

                        val cameraSelector = CameraSelector.Builder()
                            .requireLensFacing(CameraSelector.LENS_FACING_BACK)
                            .build()

                        preview.surfaceProvider = previewView.surfaceProvider

                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            imageCapture,
                            preview
                        )
                    }, ContextCompat.getMainExecutor(ctx))

                    previewView
                }
            )

            if (cameraViewState.processingState == CameraClipState.IDLE || cameraViewState.processingState == CameraClipState.PROCESSING_CLIP) {
                ResizeableRect(
                    modifier = Modifier.fillMaxSize(),
                    500,
                    500,
                    cameraViewModel::setBBoxSize
                )
            }

            if (showCenterDot) {
                Box(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(width = 15.dp, height = 15.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary)
                )
            }

            Button(
                onClick = {
                    val capture = imageCapture ?: return@Button
                    val captureState = cameraViewModel.cameraState.value
                    if (isCapturing || captureState.processingState !in setOf(
                            CameraClipState.IDLE, CameraClipState.CLIPPED
                        )) return@Button

                    // Keep the previous processing state until a photo is available.
                    // Use these captured values even if the UI recomposes during capture.
                    val capturePreviewWidth = previewWidth
                    val capturePreviewHeight = previewHeight
                    isCapturing = true
                    try {
                        takePicture(context, capture) { bitmap ->
                            isCapturing = false
                            if (bitmap == null) {
                                cameraViewModel.setError("Error taking picture. Please try again.")
                                return@takePicture
                            }

                            when (captureState.processingState) {
                                CameraClipState.IDLE -> {
                                    // Invert the preview's centered fill scaling in either orientation.
                                    val scale = max(
                                        capturePreviewWidth / bitmap.width,
                                        capturePreviewHeight / bitmap.height
                                    )
                                    val width = (captureState.bboxWidth / scale)
                                        .roundToInt().coerceIn(1, bitmap.width)
                                    val height = (captureState.bboxHeight / scale)
                                        .roundToInt().coerceIn(1, bitmap.height)
                                    cameraViewModel.uploadClip(
                                        bitmap,
                                        BoundingBox(
                                            (bitmap.width - width) / 2,
                                            (bitmap.height - height) / 2,
                                            width,
                                            height
                                        )
                                    )
                                }
                                CameraClipState.CLIPPED -> cameraViewModel.uploadComputerImage(bitmap)
                                else -> Unit
                            }
                        }
                    } catch (exception: Exception) {
                        isCapturing = false
                        Log.e("Camera", "Could not start capture", exception)
                        cameraViewModel.setError("Error taking picture. Please try again.")
                    }
                },
                enabled = !isCapturing && imageCapture != null &&
                    previewWidth > 0 && previewHeight > 0 &&
                    (cameraViewState.processingState == CameraClipState.CLIPPED ||
                        (cameraViewState.processingState == CameraClipState.IDLE &&
                            cameraViewState.bboxWidth > 0 && cameraViewState.bboxHeight > 0)),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 72.dp)
                    .size(64.dp),
                shape = CircleShape
            ) {
                Canvas(
                    modifier = Modifier
                ) {
                    drawCircle(color = Color.White, radius = 32.dp.toPx())
                    drawCircle(
                        color = colorPrimary,
                        radius = 28.dp.toPx(),
                        style = Stroke(
                            width = 1.dp.toPx()
                        )
                    )
                }
            }
        }
    } else {
        Box(
          modifier = Modifier.fillMaxSize()
        ) {
            Text(
                text = stringResource(R.string.camera_permission_not_granted),
                modifier = Modifier.align(Alignment.Center)
            )
        }
    }

    LaunchedEffect(cameraViewState.error) {
        cameraViewState.error?.let { message ->
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            cameraViewModel.resetError()
        }
    }
}

fun takePicture(context: Context, imageCapture: ImageCapture, onResult: (bitmap: Bitmap?) -> Unit) {
    val filename = "${System.currentTimeMillis()}.jpg"
    val file = File(context.filesDir, filename)

    val outputOptions = ImageCapture.OutputFileOptions
        .Builder(file)
        .build()

    imageCapture.takePicture(
        outputOptions,
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                val bitmap = try {
                    val decoded = requireNotNull(BitmapFactory.decodeFile(file.absolutePath)) {
                        "Could not decode captured photo"
                    }
                    val exif = ExifInterface(file.absolutePath)
                    if (exif.rotationDegrees != 0 || exif.isFlipped) {
                        val matrix = Matrix().apply {
                            if (exif.isFlipped) postScale(-1f, 1f)
                            postRotate(exif.rotationDegrees.toFloat())
                        }
                        Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                    } else {
                        decoded
                    }
                } catch (exception: Exception) {
                    Log.e("Camera", "Could not decode captured photo", exception)
                    null
                } finally {
                    file.delete()
                }
                onResult(bitmap)
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e("Camera", "Error on image capture: ${exception.message}", exception)
                file.delete()
                onResult(null)
            }
        }
    )
}
