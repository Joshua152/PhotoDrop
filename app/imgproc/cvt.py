import base64
import io
import numpy as np
import cv2 as cv
from PIL import Image

def decode_img(base64_text):
    base64_data = base64.b64decode(base64_text)
    pil_img = Image.open(io.BytesIO(base64_data))
    img = np.array(pil_img)
    img = cv.cvtColor(img, cv.COLOR_RGB2BGR)

    return img
