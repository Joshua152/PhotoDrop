package com.joshuaau.photodrop.ui.screens.components

import android.Manifest
import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Log
import android.widget.Toast
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.impl.utils.Exif
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberPermissionState
import com.joshuaau.photodrop.MainActivity
import com.joshuaau.photodrop.R
import com.joshuaau.photodrop.repository.ImageProcessingService
import com.joshuaau.photodrop.viewmodel.CameraClipState
import com.joshuaau.photodrop.viewmodel.CameraViewModel
import com.joshuaau.photodrop.viewmodel.CameraViewState
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

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
    val preview = Preview.Builder().build()
    var imageCapture by remember { mutableStateOf<ImageCapture?>(null) }

    var previewWidth by remember { mutableFloatStateOf(0f) }
    var previewHeight by remember { mutableFloatStateOf(0f) }

    val colorPrimary = MaterialTheme.colorScheme.primary

    var borderWidth = 0.dp
    if (
        cameraViewState.processingState == CameraClipState.PROCESSING_CLIP ||
        cameraViewState.processingState == CameraClipState.CLIPPED
    ) {
        borderWidth = 2.dp
    }

    if (cameraViewState.processingState == CameraClipState.CLIPPED) {
        borderWidth = 10.dp
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
                    val previewView = PreviewView(ctx)
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

//            TODO
//            if (cameraViewState.clip != null) {
//                val offsetXDp = with(LocalDensity.current) { (cameraViewState.clipOffsetXPercent * previewWidth).toDp() }
//                val offsetYDp = with(LocalDensity.current) { (cameraViewState.clipOffsetYPercent * previewHeight).toDp() }
//
//                print("Ofset: ${cameraViewState.clipOffsetXPercent} ${cameraViewState.clipOffsetYPercent}")
//                println("Offset: ${cameraViewState.clipOffsetXPercent} ${cameraViewState.clipOffsetYPercent} $offsetXDp $offsetYDp")
//
//                Image(
//                    modifier = Modifier.padding(start = 200.dp, top = 200.dp),
//                    bitmap = cameraViewState.clip!!.asImageBitmap(),
//                    contentDescription = "Clip"
//                )
//            }

            if (cameraViewState.processingState == CameraClipState.IDLE || cameraViewState.processingState == CameraClipState.PROCESSING_CLIP) {
                ResizeableRect(
                    modifier = Modifier.fillMaxSize(),
                    500,
                    500,
                    cameraViewModel::setBBoxSize
                )
            }

            Button(
                onClick = {
                    Toast.makeText(context, "TAKING PICTURE", Toast.LENGTH_SHORT).show()

                    cameraViewModel.setProcessingState()
                    takePicture(context, imageCapture!!) { bm ->
                        if (bm == null) {
                            Toast.makeText(context, "Error taking picture", Toast.LENGTH_SHORT).show()
                            return@takePicture

                        }

                        Toast.makeText(context, "PICTURE TAKEN", Toast.LENGTH_SHORT).show()
                        Log.i("PHOTO", "Picture taken")

                        fun clip() {
                            val ratio = bm.height / previewHeight
                            val imageUnitPreviewWidth = previewWidth * ratio

                            val imageUnitWidth =
                                ((cameraViewState.bboxWidth / previewWidth) * imageUnitPreviewWidth).toInt()
                            val imageUnitHeight =
                                ((cameraViewState.bboxHeight / previewHeight) * bm.height).toInt()

                            val offsetX = (bm.width - imageUnitWidth) / 2
                            val offsetY = (bm.height - imageUnitHeight) / 2

                            cameraViewModel.getClip(bm, "$offsetX $offsetY $imageUnitWidth $imageUnitHeight")
                        }

                        fun send() {
                            cameraViewModel.sendImage(bm)
                        }

                        Log.i("PHOTO", "Processing state: ${cameraViewState.processingState}")
                        when (cameraViewState.processingState) {
                            CameraClipState.PROCESSING_CLIP -> clip()
                            CameraClipState.SENDING -> send()
                            else -> return@takePicture
                        }
                    }
                },
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
                val filePath = file.absolutePath
                var bitmap = BitmapFactory.decodeFile(filePath)

                val exif = ExifInterface(filePath)
                val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                val rotationDegrees = when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270
                    else -> 0
                }
                if (rotationDegrees != 0) {
                    val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
                    bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                }

                onResult(bitmap)
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e("Camera", "Error on image capture: ${exception.message}", exception)
            }
        }
    )
}
