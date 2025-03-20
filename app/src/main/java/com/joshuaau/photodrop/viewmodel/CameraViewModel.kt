package com.joshuaau.photodrop.viewmodel

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.joshuaau.photodrop.repository.APIClient
import com.joshuaau.photodrop.repository.GetClipRequest
import com.joshuaau.photodrop.repository.GetClipResponse
import com.joshuaau.photodrop.repository.ImageProcessingService
import com.joshuaau.photodrop.repository.SendImageRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import retrofit2.Response
import java.io.ByteArrayOutputStream
import java.util.UUID

enum class CameraClipState {
    IDLE,
    PROCESSING_CLIP,
    CLIPPED,
    SENDING
}

data class CameraViewState(
    val bboxWidth: Int = 0,
    val bboxHeight: Int = 0,
    val processingState: CameraClipState = CameraClipState.IDLE,
    val clip: Bitmap? = null,
    val clipOffsetXPercent: Float = 0f,
    val clipOffsetYPercent: Float = 0f,
    val fullImageWidth: Int = 0,
    val fullImageHeight: Int = 0
)

// TODO: Dependency inject the api interface
class CameraViewModel: ViewModel() {
    val apiInterface = APIClient.getClient().create(ImageProcessingService::class.java)

    private val _cameraState = MutableStateFlow<CameraViewState>(CameraViewState())
    val cameraState = _cameraState.asStateFlow()

    fun setProcessingState() {
        _cameraState.update { currentState ->
            currentState.copy(
                processingState = when (currentState.processingState) {
                    CameraClipState.IDLE -> CameraClipState.PROCESSING_CLIP
                    CameraClipState.PROCESSING_CLIP -> CameraClipState.CLIPPED
                    CameraClipState.CLIPPED -> CameraClipState.SENDING
                    CameraClipState.SENDING -> CameraClipState.IDLE
                }
            )
        }

        Log.i("PHOTO", "Processing state: ${_cameraState.value.processingState}")
    }

    fun setBBoxSize(width: Int, height: Int) {
        _cameraState.update { currentState ->
            currentState.copy(
                bboxWidth = width,
                bboxHeight = height
            )
        }
    }

    fun getClip(photo: Bitmap, bbox: String) {
        viewModelScope.launch {
            val encodedImg = bitmapToBase64(photo)

            val clipRequest = GetClipRequest(phoneImg = encodedImg, bbox = bbox)

            var response: Response<GetClipResponse>? = null
            try {
                withContext(Dispatchers.IO) {
                    response = apiInterface.getClip(clipRequest)
                }
                Log.i("PHOTO", "Sent api request $response")
            } catch (exception: Exception) {
                Log.e("PHOTO", "Error on image capture: ${exception.message}", exception)
            }

            _cameraState.update { currentState ->
                if (response == null || response.body() == null) {
                    return@update currentState
                }

                Log.i("PHOTO", "CLIPPED")
                val decodedBytes = Base64.decode(response.body()?.clip, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)

                currentState.copy(
                    clip = bitmap,
                    clipOffsetXPercent = response.body()?.offsetXPercent ?: 0f,
                    clipOffsetYPercent = response.body()?.offsetYPercent ?: 0f,
                    fullImageWidth = photo.width,
                    fullImageHeight = photo.height
                )
            }

            setProcessingState()
        }
    }

    fun sendImage(photo: Bitmap) {
        if (_cameraState.value.clip == null) {
            return
        }

        val sendImageRequest = SendImageRequest(
            id = UUID.randomUUID().toString(),
            phoneImg = bitmapToBase64(photo),
            clip = bitmapToBase64(_cameraState.value.clip!!)
        )

        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    apiInterface.sendImage(sendImageRequest)
                }

                setProcessingState()
                Log.i("PHOTO", "Sent image")
            } catch (e: Exception) {
                Log.e("PHOTO", "Error on send image: ${e.message}", e)
            }
        }
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, byteArrayOutputStream)
        val byteArray = byteArrayOutputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.DEFAULT)
    }
}