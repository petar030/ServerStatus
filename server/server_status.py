import asyncio
import json
import signal
import socket
import sys
import websockets
import threading
import random
import psutil
import time
import jwt
import datetime
import aiohttp
from aiohttp import web
import weakref
import keyring


import websockets.exceptions

class SharedData:

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(SharedData, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        if not hasattr(self, 'initialized'):
            self.cpu_usage = 0
            self.cpu_temp = 0
            self.mem_used = 0
            self.mem_total = 0
            self.cpu_data_lock = threading.Lock()  # Replaced asyncio.Lock with threading.Lock
            self.event_flag = threading.Event()
            self.initialized = True

    #HELPER TEMP FUNCTION
    def get_cpu_temp(self):
        temperatures = psutil.sensors_temperatures()
        total_temp = 0
        temp_count = 0

        for sensor, temps in temperatures.items():
            if 'temp' in sensor or 'therm' in sensor or 'cpu' in sensor.lower():
                for temp in temps:
                    total_temp += temp.current
                    temp_count += 1

        if temp_count > 0:
            return round(total_temp / temp_count, 1)
        else:
            return -1

    #MAIN CPU DATA UPDATING FUNCTION (This function will now run in a separate thread)
    def update_cpu_data(self):
        while not self.event_flag.is_set():
            with self.cpu_data_lock:
                self.cpu_usage = psutil.cpu_percent(1)
                self.cpu_temp = self.get_cpu_temp()
                mem = psutil.virtual_memory()
                self.mem_used = mem.percent
                self.mem_total = round((mem.total / (1024**3)), 2)
                #print(f"CPU Usage: {self.cpu_usage}%, CPU Temp: {self.cpu_temp}°C, Mem Used: {self.mem_used}%, Mem Total: {self.mem_total}GB")

            time.sleep(0.3)  # Sleep for 0.3 seconds to control update rate

    def stop_updating(self):
        self.event_flag.set()

    #RETURNING RECORDED DATA
    def get_update(self):
        with self.cpu_data_lock:
            cpu_usage = self.cpu_usage
            cpu_temp = self.cpu_temp
            mem_used = self.mem_used
            mem_total = self.mem_total
        data = {
            "timestamp": time.time(),
            "cpu_usage": cpu_usage,
            "cpu_temp": cpu_temp,
            "mem_used": mem_used,
            "mem_total": mem_total
        }
        return json.dumps(data)

class JWTManager:
    SECRET_KEY = 'tajni_kljuc'

    @staticmethod
    def make_access_token():
        expiration_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=3)
        payload = {
            'token_type': 'access',
            'exp': expiration_time,
            'iat': datetime.datetime.now(datetime.timezone.utc),
        }
        return jwt.encode(payload, JWTManager.SECRET_KEY, algorithm='HS256')

    @staticmethod
    def make_refresh_token():
        expiration_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=7)
        payload = {
            'token_type': 'refresh',
            'exp': expiration_time,
            'iat': datetime.datetime.now(datetime.timezone.utc),
        }
        return jwt.encode(payload, JWTManager.SECRET_KEY, algorithm='HS256')

    @staticmethod
    def authorize(token):
        try:
            decoded_token = jwt.decode(token, JWTManager.SECRET_KEY, algorithms=['HS256'])

            if 'token_type' in decoded_token:
                if decoded_token['token_type'] == 'access':
                    return "ACCESS"
                elif decoded_token['token_type'] == 'refresh':
                    return "REFRESH"
            return "NOT"

        except jwt.ExpiredSignatureError:
            return "NOT"
        except jwt.InvalidTokenError:
            return "NOT"


#WEBSOCKET

async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    shared_data = SharedData()
    request.app['websockets'].add(ws)
    authorized = 'NOT'
    try:
        async for msg in ws:

            if not msg.type == aiohttp.WSMsgType.TEXT:
                continue

            #AUTHORIZATION
            if authorized == 'NOT' or authorized == 'REFRESH':
                    authorized = JWTManager.authorize(msg.data)
                    # print(msg.data)
                    # print(authorized)
                    if authorized == 'ACCESS':
                        await ws.send_str("SUCCESSFUL")
                    else:
                        await ws.send_str("AUTHORIZE")
                        continue

            #COMMUNICATION
            if msg.data == "GET_UPDATE":
                data = shared_data.get_update()
                await ws.send_str(data)
    finally:
        request.app['websockets'].discard(ws)
        await ws.close()
    return ws

#HTTP
async def check_token(request):
    token = request.headers.get("Authorization")

    if not token:
        return web.Response(status=401, text="Token missing")

    token = token.split(" ")[1]

    token_type = JWTManager.authorize(token)

    if token_type == "ACCESS":
        return web.Response(text="Valid Access Token")
    elif token_type == "REFRESH":
        # Ako je refresh token validan, vraćamo nove tokene
        new_access_token = JWTManager.make_access_token()
        new_refresh_token = JWTManager.make_refresh_token()
        return web.json_response({
            "access_token": new_access_token,
            "refresh_token": new_refresh_token
        })
    else:
        return web.Response(status=401, text="Invalid or expired token")

async def login(request):
    try:
        # Uzimamo form data iz POST zahteva
        data = await request.post()

        # Proveravamo da li je prosleđena lozinka
        if 'password' not in data:
            return web.Response(text='Password not provided', status=400)

        input_password = data['password']

        # Dobijamo lozinku iz keyring-a
        stored_password = keyring.get_password("server_status", "default")

        # Proveravamo da li je lozinka ispravna
        if input_password == stored_password:
            new_access_token = JWTManager.make_access_token()
            new_refresh_token = JWTManager.make_refresh_token()
            return web.json_response({
                "access_token": new_access_token,
                 "refresh_token": new_refresh_token
            })
        else:
            return web.Response(text='Invalid password', status=401)

    except Exception as e:
        return web.Response(text=str(e), status=500)

async def global_shutdown_async(app):
    for ws in set(app['websockets']):
        await ws.close(code=aiohttp.WSCloseCode.GOING_AWAY)
    shared_data = SharedData()
    shared_data.stop_updating()

def create_app():
    # Start CPU data update in a separate thread
    shared_data = SharedData()
    cpu_thread = threading.Thread(target=shared_data.update_cpu_data, daemon=True)
    cpu_thread.start()

    # Prepare app
    app = web.Application()
    app['websockets'] = weakref.WeakSet()

    app.router.add_get("/auth", check_token)
    app.router.add_post("/login", login)
    app.router.add_get('/ws', websocket_handler)
    app.on_shutdown.append(global_shutdown_async)

    return app

app = create_app()


if __name__ == "__main__":

    # Start CPU data update in a separate thread
    shared_data = SharedData()
    cpu_thread = threading.Thread(target=shared_data.update_cpu_data, daemon=True)
    cpu_thread.start()


    # GET IP
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.connect(("8.8.8.8", 53))
        MY_IP = s.getsockname()[0]
    print("My ip: " + MY_IP)


    

    # Start aiohttp websocket server
    app.router.add_get("/auth", check_token)
    app.router.add_post("/login", login)
    app.router.add_get('/ws', websocket_handler)
    app.on_shutdown.append(global_shutdown_async)
    web.run_app(app, host=MY_IP, port=8080)


