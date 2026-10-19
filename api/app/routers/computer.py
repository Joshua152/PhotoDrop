import json

from fastapi import APIRouter, HTTPException, WebSocket

from pydantic import BaseModel

from app import main
from app.imgproc import cvt, detect

router = APIRouter()


class ComputerUploadParams(BaseModel):
    id: str
    img: str


@router.websocket('/computer')
async def computer(websocket: WebSocket):
    await websocket.accept()

    main.computer_socket = websocket

    while True:
        # Need to keep the connection open
        await websocket.receive_text()

@router.post('/computer-send')
async def computer_send(params: ComputerUploadParams):
    if params.id not in main.phone_data:
        raise HTTPException(status_code=400, detail='Event ID not found')
    
    phone_res = main.phone_data[params.id]

    phone_img = phone_res.phone_img
    clip_data = phone_res.clip_data
    computer_img = cvt.decode_img(params.img)

    x, y = detect.find_center(phone_img, computer_img)
    x /= computer_img.shape[1]
    y /= computer_img.shape[0]
    send = {
        'x': x,
        'y': y,
        'clip': clip_data
    }

    return send