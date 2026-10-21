package com.joshuaau.photodrop.viewmodel

import android.graphics.Bitmap
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.joshuaau.photodrop.repository.APIClient
import com.joshuaau.photodrop.repository.ImageProcessingService
import com.joshuaau.photodrop.repository.NotifyClipUploadedRequest
import com.joshuaau.photodrop.repository.NotifyComputerPictureUploadedRequest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream

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
    val fullImageHeight: Int = 0,
    val error: String? = null
)

data class UploadURLs(
    val id: String,
    val clipUploadURL: String,
    val computerPictureUploadURL: String
)

class BoundingBox(
    val left: Int,
    val top: Int,
    val width: Int,
    val height: Int
)

// TODO: Dependency inject the api interface
class CameraViewModel: ViewModel() {
    val apiInterface = APIClient.getClient().create(ImageProcessingService::class.java)

    private val _cameraState = MutableStateFlow<CameraViewState>(CameraViewState())
    val cameraState = _cameraState.asStateFlow()

    private var uploadURLs: UploadURLs? = null

    fun setNextProcessingState() {
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

    fun uploadClip(photo: Bitmap, bbox: BoundingBox) {
        viewModelScope.launch {
            _cameraState.update {
                it.copy(processingState = CameraClipState.PROCESSING_CLIP, error = null)
            }
            uploadURLs = null
            try {
                val upload = getUploadURLs()
                if (upload == null) {
                    _cameraState.update {
                        it.copy(
                            processingState = CameraClipState.IDLE,
                            error = "Failed to get upload URLs"
                        )
                    }
                    return@launch
                }

                val x = bbox.left.coerceIn(0, photo.width)
                val y = bbox.top.coerceIn(0, photo.height)
                val right = (bbox.left.toLong() + bbox.width).coerceIn(0L, photo.width.toLong()).toInt()
                val bottom = (bbox.top.toLong() + bbox.height).coerceIn(0L, photo.height.toLong()).toInt()
                require(right > x && bottom > y) { "Crop must overlap the image" }
                val croppedBitmap = withContext(Dispatchers.Default) {
                    Bitmap.createBitmap(photo, x, y, right - x, bottom - y)
                }

                val success = uploadImage(croppedBitmap, upload.clipUploadURL) {
                    notifyClipUploaded(upload.id)
                }
                if (!success) {
                    return@launch
                }

                uploadURLs = upload
                _cameraState.update {
                    it.copy(
                        processingState = CameraClipState.CLIPPED,
                        clip = croppedBitmap,
                        clipOffsetXPercent = x.toFloat() / photo.width,
                        clipOffsetYPercent = y.toFloat() / photo.height,
                        fullImageWidth = photo.width,
                        fullImageHeight = photo.height
                    )
                }
            } catch (exception: CancellationException) {
                throw exception
            } catch (exception: Exception) {
                Log.e("PHOTO", "Failed to upload clip", exception)
                _cameraState.update {
                    it.copy(
                        processingState = CameraClipState.IDLE,
                        error = "Failed to upload clip. Please try again."
                    )
                }
            }
        }
    }

    fun uploadComputerImage(photo: Bitmap) {
        if (uploadURLs == null) {
            setError("Failed to get upload URLs.")
            Log.i("PHOTO", "Failed to upload URLs in uploadComputerPicture")
            return
        }

        viewModelScope.launch {
            _cameraState.update {
                it.copy(processingState = CameraClipState.SENDING, error = null)
            }

            try {
                val success = uploadImage(photo, uploadURLs!!.computerPictureUploadURL) {
                    notifyComputerImageUploaded(uploadURLs!!.id)
                }
                if (!success) {
                    return@launch
                }

                _cameraState.update {
                    it.copy(processingState = CameraClipState.IDLE)
                }
            } catch (exception: CancellationException) {
                throw exception
            } catch (exception: Exception) {
                Log.e("PHOTO", "Failed to upload computer image", exception)
                _cameraState.update {
                    it.copy(
                        processingState = CameraClipState.IDLE,
                        error = "Failed to upload computer image. Please try again."
                    )
                }
            }
        }
    }

    private suspend fun uploadImage(photoBitmap: Bitmap, uploadURL: String, notifyFn: suspend () -> Boolean): Boolean {
        val imageBody = withContext(Dispatchers.Default) {
            ByteArrayOutputStream().use { stream ->
                check(photoBitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)) {
                    "Failed to encode JPEG"
                }
                stream.toByteArray().toRequestBody("image/jpeg".toMediaType())
            }
        }

        val uploadResponse = apiInterface.uploadImage(uploadURL, imageBody)
        if (!uploadResponse.isSuccessful) {
            _cameraState.update {
                it.copy(
                    processingState = CameraClipState.IDLE,
                    error = "Image upload failed (HTTP ${uploadResponse.code()})"
                )
            }

            return false
        }

        val notifySuccess = notifyFn()
        if (!notifySuccess) {
            _cameraState.update {
                it.copy(
                    processingState = CameraClipState.IDLE,
                    error = "Failed to notify image uploaded"
                )
            }

            return false
        }
        return true
    }

    private suspend fun notifyClipUploaded(id: String): Boolean {
        val response = apiInterface.notifyClipUploaded(
            NotifyClipUploadedRequest(
                id = id,
                shouldSegment = true
            )
        )

        if (!response.isSuccessful) {
            setError("Failed to notify clip uploaded.")
            return false
        }

        return true
    }

    private suspend fun notifyComputerImageUploaded(id: String): Boolean {
        val response = apiInterface.notifyComputerPictureUploaded(
            NotifyComputerPictureUploadedRequest(
                id = id,
            )
        )

        if (!response.isSuccessful) {
            setError("Failed to notify computer picture uploaded.")
            return false
        }

        return true
    }

    fun setBBoxSize(width: Int, height: Int) {
        _cameraState.update { currentState ->
            currentState.copy(
                bboxWidth = width,
                bboxHeight = height
            )
        }
    }

    fun setError(error: String) {
        _cameraState.update { currentState ->
            currentState.copy(
                error = error
            )
        }
    }

    fun resetError() {
        _cameraState.update { currentState ->
            currentState.copy(
                error = null
            )
        }
    }

    private suspend fun getUploadURLs(): UploadURLs? {
        val response = apiInterface.getUploadUrls()
        val body = response.body()

        if (!response.isSuccessful || body == null) {
            return null
        }

        return UploadURLs(
            id = body.id,
            clipUploadURL = body.clipUploadURL,
            computerPictureUploadURL = body.computerPictureUploadURL
        )
    }
}