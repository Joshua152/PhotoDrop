### Order to call functions
1. **/phone/upload-urls** to retrieve the S3 upload URLs for the clip and phone image
2. **/phone/notify-clip-uploaded** to notify the server when the phone has uploaded the clip
3. **/phone/notify-computer-picture-uploaded** to notify the server when the phone image has been uploaded
4. **/computer/calculate-clip-location** after the computer has uploaded the screenshot to get the final location

---
The server will send a web socket message of the following format after step (2):
```json
{
    'message': 'download_clip',
    'id': clip_upload.id,
    'clip_download_url': clip_download_url,
}
```
The computer should immediately download the clip and store the `id`

After step (3), the server will send a presigned upload URL to the computer to upload their screenshot. The computer should upload as soon as possible.