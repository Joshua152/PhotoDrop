import base64

import cv2
import cv2 as cv
from typing import Annotated

from pydantic import BaseModel

from fastapi import APIRouter, Form, UploadFile
import numpy as np
import json

from app import main
from ..imgproc import segment


router = APIRouter()


class PhoneData:
    def __init__(self, phone_img, clip_data):
        self.phone_img = phone_img
        self.clip_data = clip_data


class PhoneUploadParams(BaseModel):
    id: str
    phone_img: str
    clip: str


class PhoneClipParams(BaseModel):
    phone_img: str
    bbox: str


@router.post('/phone-clip')
async def phone_clip(phone_clip_params: PhoneClipParams):
    """
    Endpoint to upload the initial clip image to run a segmentation analysis on. Returns a cropped image of the clip
    along with the offset from the top left of the bbox
    :param phone_clip_params: The expected JSON body format
        phone_img: base64 encoded camera capture
        bbox: bounding box of where to include the segmentation
    """
    # data = await phone_img.read()
    # img = np.fromstring(data, dtype=np.uint8)
    # img = cv.imdecode(img, cv.IMREAD_COLOR)

    print("Phone clip")

    img = await base64_to_cv2(phone_clip_params.phone_img)
    bbox = phone_clip_params.bbox.split(' ')
    bbox = list(map(int, bbox))

    print(img.shape, bbox)

    clip, offset = segment.segment(img, bbox)

    _, encoded_clip = cv.imencode('.png', clip)
    encoded_clip = base64.b64encode(encoded_clip).decode('ascii')

    out = {
        'clip': encoded_clip,
        'offset_x_percent': offset[0].item() / img.shape[1],
        'offset_y_percent': offset[1].item() / img.shape[0]
    }

    return out


# @router.post('/phone-clip')
# async def phone_clip(phone_img: UploadFile, bbox: Annotated[str, Form()]):
#     """
#     Endpoint to upload the initial clip image to run a segmentation analysis on. Returns a cropped image of the clip
#     along with the offset from the top left of the bbox
#     :param phone_img: The base64 encoded image
#     :param bbox: A bbox string in the format "xmin ymin xmax max"
#     :return: A json with the cropped image and the offset from the top left of the
#     """
#     data = await phone_img.read()
#     img = np.fromstring(data, dtype=np.uint8)
#     img = cv.imdecode(img, cv.IMREAD_COLOR)
#
#     bbox = bbox.split(' ')
#     bbox = list(map(int, bbox))
#     clip, offset = segment.segment(img, bbox)
#
#     _, encoded_clip = cv.imencode('.png', clip)
#     encoded_clip = base64.b64encode(encoded_clip).decode('ascii')
#
#     out = {
#         'clip': encoded_clip,
#         'offset': f'{offset[0]} {offset[1]}'
#     }
#
#     return out


# @router.post('/phone-upload')
# async def phone_upload(id: Annotated[str, Form()], phone_img: UploadFile, clip: UploadFile):
#     phone_img_contents = await phone_img.read()
#     clip_contents = await clip.read()
#
#     img = np.fromstring(phone_img_contents, dtype=np.uint8)
#     img = cv.imdecode(img, cv.IMREAD_COLOR)
#
#     clip = np.fromstring(clip_contents, dtype=np.uint8)
#     clip = cv.imdecode(clip, cv.IMREAD_COLOR)
#     _, encoded_clip = cv.imencode('.jpg', clip)
#     encoded_clip = base64.b64encode(encoded_clip).decode('ascii')
#
#     # cv.imshow("img", img)
#     # cv.imshow("clip", clip)
#     # cv.waitKey(0)
#
#     main.phone_data[id] = PhoneData(phone_img=img, clip_data=encoded_clip)
#
#     # Notify computer
#     if main.computer_socket:
#         await main.computer_socket.send_text(id)


@router.post('/phone-upload')
async def phone_upload(phone_upload_params: PhoneUploadParams):
    print("Phone upload")
    img = await base64_to_cv2(phone_upload_params.phone_img)
    main.phone_data[phone_upload_params.id] = PhoneData(phone_img=img, clip_data=phone_upload_params.clip)

    # cv2.imshow("cvt", img)
    # cv2.waitKey(0)

    # Notify computer
    if main.computer_socket:
        send = {
            'message': 'trigger',
            'id': phone_upload_params.id
        }

        await main.computer_socket.send_text(json.dumps(send))


async def base64_to_cv2(base64_str):
    img_bytes = base64.b64decode(base64_str)
    img_arr = np.frombuffer(img_bytes, dtype=np.uint8)
    img = cv.imdecode(img_arr, flags=cv2.IMREAD_COLOR)

    # cv2.imshow("cvt", img)
    # cv2.waitKey(0)

    return img
