import uuid

import cv2

from pydantic import BaseModel

from fastapi import APIRouter, HTTPException
from starlette.concurrency import run_in_threadpool
import json

from app import main
from app.remote import s3
from ..imgproc import segment


router = APIRouter(prefix='/phone', tags=['phone'])


class ClipUpload(BaseModel):
    id: str
    should_segment: bool


class ComputerPictureUpload(BaseModel):
    id: str


@router.get('/upload-urls')
async def upload_urls():
    id = uuid.uuid4()
    clip_upload_url = s3.create_presigned_upload_url(s3.get_clip_object_name(id))
    if clip_upload_url is None:
        raise HTTPException(status_code=500, detail='Failed to generate clip upload URL')
    computer_picture_upload_url = s3.create_presigned_upload_url(s3.get_computer_picture_object_name(id))
    if computer_picture_upload_url is None:
        raise HTTPException(status_code=500, detail='Failed to generate computer picture upload URL')
    return {
        'id': id,
        'clip_upload_url': clip_upload_url,
        'computer_picture_upload_url': computer_picture_upload_url,
    }


@router.post('/notify-clip-uploaded')
async def notify_clip_uploaded(clip_upload: ClipUpload):
    '''
    Send the compute a download url to get the clip ahead of time
    '''
    clip_object_key = s3.get_clip_object_name(clip_upload.id)

    if clip_upload.should_segment:
        await run_in_threadpool(_segment_uploaded_clip, clip_object_key)

    if main.computer_socket:
        clip_download_url = s3.create_presigned_download_url(clip_object_key)
        if clip_download_url is None:
            raise HTTPException(status_code=500, detail='Failed to generate clip download URL')

        send = {
            'message': 'download_clip',
            'id': clip_upload.id,
            'clip_download_url': clip_download_url,
        }

        await main.computer_socket.send_text(json.dumps(send))


@router.post('/notify-computer-picture-uploaded')
async def notify_computer_picture_uploaded(computer_picture_upload: ComputerPictureUpload):
    '''
    Send the trigger to the computer to take the screenshot with a presigned uploade url

    Need to send the computer the id so that when we get the notification from the 
    computer that it is done uploading, we can match to the phone upload

    We also assume the object has been uploaded successfully
    '''
    if main.computer_socket:
        ss_object_key = s3.get_screenshot_object_name(computer_picture_upload.id)
        ss_upload_url = s3.create_presigned_upload_url(ss_object_key)
        if ss_upload_url is None:
            raise HTTPException(status_code=500, detail='Failed to generate screenshot upload URL')

        send = {
            'message': 'screenshot',
            'id': computer_picture_upload.id,
            'ss_upload_url': ss_upload_url,
        }

        await main.computer_socket.send_text(json.dumps(send))


def _segment_uploaded_clip(clip_object_key):
    img = s3.get_image_as_cv2(clip_object_key)

    height, width = img.shape[:2]
    clip, _ = segment.segment(img, (0, 0, width, height))
    if clip.size == 0:
        raise HTTPException(status_code=422, detail='No segments found in uploaded clip')

    success, encoded_clip = cv2.imencode('.png', clip)
    if not success:
        raise HTTPException(status_code=500, detail='Failed to encode segmented clip')

    s3.put_object(clip_object_key, encoded_clip.tobytes(), content_type='image/png')
