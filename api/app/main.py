from fastapi import FastAPI, WebSocket

from .routers import phone
from .routers import computer

app = FastAPI()
app.include_router(phone.router)
app.include_router(computer.router)

computer_socket: WebSocket | None = None
phone_data = {}

'''
Have web socket between backend and comp app

Endpoints:
[POST] /phone
- Upload photo captured on phone with ID
[POST] /computer
- Upload screenshot from computer with ID
'''

# if __name__ == '__main__':
#     uvicorn.run(app, host='0.0.0.0', port=8000)
