package com.joshuaau.photodrop.repository

import com.google.gson.annotations.SerializedName
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Url

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

class GetUploadURLsResponse(
    @SerializedName("id")
    val id: String,
    @SerializedName("clip_upload_url")
    val clipUploadURL: String,
    @SerializedName("computer_picture_upload_url")
    val computerPictureUploadURL: String
)

class NotifyClipUploadedRequest(
    @SerializedName("id")
    val id: String,
    @SerializedName("should_segment")
    val shouldSegment: Boolean
)

class NotifyComputerPictureUploadedRequest(
    @SerializedName("id")
    val id: String
)

interface ImageProcessingService {
    @PUT
    suspend fun uploadImage(@Url url: String, @Body image: RequestBody): Response<Unit>

    @POST("phone-upload")
    suspend fun sendImage(@Body body: SendImageRequest): Response<ResponseBody>

    @POST("phone-clip")
    suspend fun getClip(@Body body: GetClipRequest): Response<GetClipResponse>

    @GET("phone/upload-urls")
    suspend fun getUploadUrls(): Response<GetUploadURLsResponse>

    @POST("phone/notify-clip-uploaded")
    suspend fun notifyClipUploaded(@Body body: NotifyClipUploadedRequest): Response<ResponseBody>

    @POST("/phone/notify-computer-picture-uploaded")
    suspend fun notifyComputerPictureUploaded(@Body body: NotifyComputerPictureUploadedRequest): Response<ResponseBody>
}