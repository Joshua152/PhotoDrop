package com.joshuaau.photodrop.repository

import android.health.connect.datatypes.units.Percentage
import com.google.gson.annotations.SerializedName
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

class SendImageRequest(
    @SerializedName("id")
    val id: String,
    @SerializedName("phone_img")
    val phoneImg: String,
    @SerializedName("clip")
    val clip: String
)

class GetClipRequest(
    @SerializedName("phone_img")
    val phoneImg: String,
    @SerializedName("bbox")
    val bbox: String
)

class GetClipResponse(
    @SerializedName("clip")
    val clip: String,
    @SerializedName("offset_x_percent")
    val offsetXPercent: Float,
    @SerializedName("offset_y_percent")
    val offsetYPercent: Float
)

interface ImageProcessingService {
    @POST("phone-upload")
    suspend fun sendImage(@Body body: SendImageRequest): Response<ResponseBody>

    @POST("phone-clip")
    suspend fun getClip(@Body body: GetClipRequest): Response<GetClipResponse>
}