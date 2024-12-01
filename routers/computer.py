import json

from fastapi import APIRouter, WebSocket

from app import main
from app.imgproc import cvt, detect

router = APIRouter()


@router.websocket('/computer')
async def computer(websocket: WebSocket):
    await websocket.accept()

    main.computer_socket = websocket

    while True:
        data = await websocket.receive_text()
        json_data = json.loads(data)

        event_id = json_data['id']
        if event_id in main.phone_data:
            phone_res = main.phone_data[event_id]

            phone_img = phone_res.phone_img
            clip_data = phone_res.clip_data
            computer_img = cvt.decode_img(json_data['img'])

            x, y = detect.find_center(phone_img, computer_img)
            x /= computer_img.shape[1]
            y /= computer_img.shape[0]
            send = {
                'x': x,
                'y': y,
                'clip': clip_data
            }

            await websocket.send_text(json.dumps(send))
