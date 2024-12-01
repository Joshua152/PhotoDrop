import json
import cv2 as cv
from fastapi import APIRouter, FastAPI, WebSocket

from src import main
from src.imgproc import cvt

router = APIRouter()


class PhoneData:
    def __init__(self, phone_img, clip_data):
        self.phone_img = phone_img
        self.clip_data = clip_data


@router.websocket('/phone')
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
        img = cvt.decode_img(json_data['img'])
        clip_data = json_data['clip']

        main.phone_data[event_id] = PhoneData(phone_img=img, clip_data=clip_data)

        # Notify computer
        if main.computer_socket:
            await main.computer_socket.send_text(event_id)

        cv.imshow(str(event_id), img)
        # cv.imshow(str(event_id + "1"), clip_img)
        cv.waitKey(0)

        await websocket.send_text(f"Received: {data}")
