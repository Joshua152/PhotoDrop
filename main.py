import io
import json
from typing import Annotated

import base64
import cv2 as cv
import numpy as np
from fastapi import FastAPI, Form, UploadFile, WebSocket
from PIL import Image

from imgproc import detect
from routers import computer, phone

app = FastAPI()
app.include_router(phone.router)

'''
Have web socket between backend and comp app

Endpoints:
[POST] /phone
- Upload photo captured on phone with ID
[POST] /computer
- Upload screenshot from computer with ID
'''


class PhoneData:
    def __init__(self, phone_img, clip_data):
        self.phone_img = phone_img
        self.clip_data = clip_data


computer_socket: WebSocket | None = None

phone_data = {}

'''
Use REST for phone connection instead?
'''


@app.websocket('/phone')
async def upload(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        json_data = json.loads(data)

        # Try sending over as bytes in chunks instead?
        # nparr = np.frombuffer(data, np.uint8)
        # img = cv.imdecode(nparr, cv.IMREAD_COLOR)

        # Read data from socket
        event_id = json_data['id']
        img = decode_img(json_data['img'])
        clip_data = json_data['clip']

        phone_data[event_id] = PhoneData(phone_img=img, clip_data=clip_data)

        # Notify computer
        if computer_socket:
            await computer_socket.send_text(event_id)

        cv.imshow(str(event_id), img)
        # cv.imshow(str(event_id + "1"), clip_img)
        cv.waitKey(0)

        await websocket.send_text(f"Received: {data}")


'''
Endpoint the phone client should call
ID: A UID to denote the image 
phone_img: The camera image from the phone
clip: The segmented image
'''
@app.post('/phone-upload')
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

    phone_data[id] = PhoneData(phone_img=img, clip_data=encoded_clip)

    # Notify computer
    if computer_socket:
        await computer_socket.send_text(id)


'''
Server -> [trigger] -> computer
Computer -> [ss] -> server
server -> [pos, clip] -> computer
'''
@app.websocket('/computer')
async def computer(websocket: WebSocket):
    await websocket.accept()

    global computer_socket
    computer_socket = websocket

    while True:
        data = await websocket.receive_text()
        json_data = json.loads(data)

        event_id = json_data['id']
        if event_id in phone_data:
            phone_res = phone_data[event_id]

            phone_img = phone_res.phone_img
            clip_data = phone_res.clip_data
            computer_img = decode_img(json_data['img'])

            x, y = detect.find_center(phone_img, computer_img)
            x /= computer_img.shape[1]
            y /= computer_img.shape[0]
            send = {
                'x': x,
                'y': y,
                'clip': clip_data
            }

            await websocket.send_text(json.dumps(send))


def decode_img(base64_text):
    base64_data = base64.b64decode(base64_text)
    pil_img = Image.open(io.BytesIO(base64_data))
    img = np.array(pil_img)
    img = cv.cvtColor(img, cv.COLOR_RGB2BGR)

    return img


# if __name__ == '__main__':
#     uvicorn.run(app, host='0.0.0.0', port=8000)
