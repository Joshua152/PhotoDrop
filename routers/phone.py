import base64
import cv2 as cv
from typing import Annotated

from fastapi import APIRouter, Form, UploadFile
import numpy as np

from app import main

router = APIRouter()


class PhoneData:
    def __init__(self, phone_img, clip_data):
        self.phone_img = phone_img
        self.clip_data = clip_data


@router.post('/phone-upload')
async def phone_upload(id: Annotated[str, Form()], phone_img: UploadFile, clip: UploadFile):
    phone_img_contents = await phone_img.read()
    clip_contents = await clip.read()

    img = np.fromstring(phone_img_contents, dtype=np.uint8)
    img = cv.imdecode(img, cv.IMREAD_COLOR)

    clip = np.fromstring(clip_contents, dtype=np.uint8)
    clip = cv.imdecode(clip, cv.IMREAD_COLOR)
    _, encoded_clip = cv.imencode('.jpg', clip)
    encoded_clip = base64.b64encode(encoded_clip).decode('ascii')

    # cv.imshow("img", img)
    # cv.imshow("clip", clip)
    # cv.waitKey(0)

    main.phone_data[id] = PhoneData(phone_img=img, clip_data=encoded_clip)

    # Notify computer
    if main.computer_socket:
        await main.computer_socket.send_text(id)

