import time

from fastapi import APIRouter, WebSocket

from pydantic import BaseModel

from app import main
from app.imgproc import detect
from app.remote import s3


router = APIRouter(prefix='/computer', tags=['computer'])


class ComputerScreenshot(BaseModel):
    id: str


@router.websocket('')
async def computer(websocket: WebSocket):
    await websocket.accept()

    main.computer_socket = websocket

    while True:
        # Need to keep the connection open
        await websocket.receive_text()


@router.post('/calculate-clip-location')
def calculate_clip_location(params: ComputerScreenshot):
    '''
    Need to get the corresponding phone upload picture
    Also need to download the just uploaded computer screnshot
    Then, find the center and return
    '''
    phone_img_key = s3.get_computer_picture_object_name(params.id)
    ss_img_key = s3.get_screenshot_object_name(params.id)

    t1 = time.perf_counter()

    phone_img = s3.get_image_as_cv2(phone_img_key)

    t2 = time.perf_counter()
    print(f'Phone download: {t2-t1}')

    ss_img = s3.get_image_as_cv2(ss_img_key)

    t3 = time.perf_counter()
    print(f'SS download: {t3-t2}')

    x, y = detect.find_center(phone_img, ss_img)
    x /= ss_img.shape[1]
    y /= ss_img.shape[0]
    send = {
        'message': 'clip_location',
        'x': x,
        'y': y,
    }

    t4 = time.perf_counter()
    print(f'Find center: {t4-t3}')

    # delete the old objects now
    s3.delete_folder('your-bucket-name', f'{params.id}/')  

    return send
