import json
import threading
import psutil
import time
import jwt
import datetime
import aiohttp
from aiohttp import web
import weakref
import keyring
import sqlite3
import requests
import queue
import configparser
import os


class ConfigManager:
    config_file = os.path.join(os.path.dirname(__file__), "config.ini")
    config = configparser.ConfigParser()

    @staticmethod
    def initialize():
        if not os.path.exists(ConfigManager.config_file):
            ConfigManager.create_default_config()
        ConfigManager.config.read(ConfigManager.config_file)


    @staticmethod
    def create_default_config():
        ConfigManager.config['network'] = {
            'network_port': '8081' 
        }
        ConfigManager.config['thresholds'] = {
            'cpu_temp': '80',
            'cpu_usage': '90',
            'mem_usage': '90'
        }
        with open(ConfigManager.config_file, 'w') as configfile:
            ConfigManager.config.write(configfile)

    @staticmethod
    def get(section, option):
        return ConfigManager.config.get(section, option)
    @staticmethod
    def get_int(section, option):
        return int(ConfigManager.config.get(section, option))

class FCMTokens:
    _db_path = "fcm_tokens.db"  

    @staticmethod
    def _get_connection():
        return sqlite3.connect(FCMTokens._db_path)

    @staticmethod
    def _init_db():
        with FCMTokens._get_connection() as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS fcm_tokens (
                    token TEXT PRIMARY KEY
                )
            ''')
            conn.commit()

    @staticmethod
    def add_token(token):
        FCMTokens._init_db()
        with FCMTokens._get_connection() as conn:
            try:
                conn.execute('INSERT OR IGNORE INTO fcm_tokens (token) VALUES (?)', (token,))
                conn.commit()
            except sqlite3.Error as e:
                print(f"Error adding fcm_token: {e}")

    @staticmethod
    def remove_token(token):
        FCMTokens._init_db()
        with FCMTokens._get_connection() as conn:
            try:
                conn.execute('DELETE FROM fcm_tokens WHERE token = ?', (token,))
                conn.commit()
            except sqlite3.Error as e:
                print(f"Error removing fcm_token: {e}")

    @staticmethod
    def get_tokens():
        FCMTokens._init_db()
        with FCMTokens._get_connection() as conn:
            try:
                cursor = conn.execute('SELECT token FROM fcm_tokens')
                return {row[0] for row in cursor.fetchall()}
            except sqlite3.Error as e:
                print(f"Error fetching fcm_tokens: {e}")
                return set()

class Notify:
    _uri = "https://fcm-server-nbbp.onrender.com/send-notification"
    _notification_queue = queue.Queue()

    @staticmethod
    def _notification_service():
        while True:
            payload = Notify._notification_queue.get()
            if payload is None: 
                break
            Notify._send_notification(payload)

    @staticmethod
    def _send_notification(payload):
        tokens = FCMTokens.get_tokens()
        headers = {
            "Content-Type": "application/json"
        }
        
        for token in tokens:
            payload['token'] = token
            try:
                response = requests.post(Notify._uri, data=json.dumps(payload), headers=headers)
            except Exception as e:
                print(f"Error sending notification: {e}")

    @staticmethod
    def _enqueue_notification(payload):
        Notify._notification_queue.put(payload)

    @staticmethod
    def send_cpu_temp_warning(curr_temp):
        payload = {
            "title": "CPU Temperature Warning",
            "body": f"The current CPU temperature is {curr_temp}°C, which is too high!"
        }
        Notify._enqueue_notification(payload)

    @staticmethod
    def send_cpu_usage_warning(curr_load):
        payload = {
            "title": "CPU Load Warning",
            "body": f"The current CPU load is {curr_load}%, which is too high!"
        }
        Notify._enqueue_notification(payload)

    @staticmethod
    def send_mem_usage_warning(curr_usage):
        payload = {
            "title": "Memory Usage Warning",
            "body": f"The current memory usage is {curr_usage}%, which is too high!"
        }
        Notify._enqueue_notification(payload)

    @staticmethod
    def start_service():
        notification_thread = threading.Thread(target=Notify._notification_service, daemon=True)
        notification_thread.start()

    @staticmethod
    def stop_service():
        Notify._notification_queue.put(None)  
        
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
            self.cpu_data_lock = threading.Lock() 
            self.cpu_temp_threshold = ConfigManager.get_int('thresholds', 'cpu_temp')
            self.cpu_usage_threshold = ConfigManager.get_int('thresholds', 'cpu_usage')
            self.cpu_core_loads = []

            self.mem_used = 0
            self.mem_total = 0
            self.mem_data_lock = threading.Lock()
            self.mem_usage_threshold = ConfigManager.get_int('thresholds', 'mem_usage')

            self.interface_name = self.get_first_active_interface()
            self.down_speed = 0
            self.up_speed = 0
            self.net_data_lock = threading.Lock()


            self.event_flag = threading.Event()
            self.initialized = True
           

    #CPU
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
    #MAIN CPU DATA UPDATING FUNCTION (Threaded)
    def update_cpu_data(self):
        cpu_temp_warning = False
        cpu_usage_warning = False
        while not self.event_flag.is_set():
            cpu_core_loads = psutil.cpu_percent(percpu=True, interval=1) 
            cpu_usage = round((sum(cpu_core_loads) / len(cpu_core_loads)), 2)
            cpu_temp = self.get_cpu_temp()


            with self.cpu_data_lock:
                self.cpu_usage = cpu_usage
                self.cpu_temp = cpu_temp
                self.cpu_core_loads = cpu_core_loads

            # CPU temperature warning
            if not cpu_temp_warning and cpu_temp > self.cpu_temp_threshold:
                Notify.send_cpu_temp_warning(cpu_temp)
                cpu_temp_warning = True
            if cpu_temp_warning and cpu_temp < self.cpu_temp_threshold:
                cpu_temp_warning = False

            # CPU usage warning
            if not cpu_usage_warning and cpu_usage > self.cpu_usage_threshold:
                Notify.send_cpu_usage_warning(cpu_usage)
                cpu_usage_warning = True
            if cpu_usage_warning and cpu_usage < self.cpu_usage_threshold:
                cpu_usage_warning = False

            time.sleep(0.1)  


    #MEMORY
    #MAIN MEMORY DATA UPDATING FUNCTION (Threaded)
    def update_mem_data(self):
        mem_usage_warning = False
        while not self.event_flag.is_set():
            mem = psutil.virtual_memory()
            mem_used = mem.percent
            mem_total = round((mem.total / (1024**3)), 2)

            with self.mem_data_lock:
                self.mem_used = mem_used
                self.mem_total = mem_total

            # Memory usage warning
            if not mem_usage_warning and mem_used > self.mem_usage_threshold:
                Notify.send_mem_usage_warning(mem_used)
                mem_usage_warning = True
            if mem_usage_warning and mem_used < self.mem_usage_threshold:
                mem_usage_warning = False

            time.sleep(0.1)  # Adjust this as needed
    
    #NETWORK
    def get_first_active_interface(self):
        net_counters = psutil.net_io_counters(pernic=True)
        for iface, counters in net_counters.items():
            if (iface != 'lo') and (counters.bytes_recv > 0 or counters.bytes_sent > 0):
                return iface
        return "Interface name not available"
    #MAIN NET DATA UPDATING FUNCTION(Threaded)
    def update_net_data(self):
        if self.interface_name is None:
            return

        while not self.event_flag.is_set():
            net_start = psutil.net_io_counters(pernic=True).get(self.interface_name)
            time.sleep(1)
            net_end = psutil.net_io_counters(pernic=True).get(self.interface_name)

            if not net_start or not net_end:
                continue  #Interface not active

            down_speed = round((net_end.bytes_recv - net_start.bytes_recv), 2)  # B/s
            up_speed = round((net_end.bytes_sent - net_start.bytes_sent), 2)

            with self.net_data_lock:
                self.down_speed = down_speed
                self.up_speed = up_speed



    #GLOBAL
    def stop_updating(self):
        self.event_flag.set()
    #RETURNING GET_UPDATE DATA
    def get_update(self):
        with self.cpu_data_lock:
            cpu_usage = self.cpu_usage
            cpu_temp = self.cpu_temp
            cpu_core_loads = self.cpu_core_loads
        with self.mem_data_lock:
            mem_used = self.mem_used
            mem_total = self.mem_total
        with self.net_data_lock:
            up_speed = self.up_speed
            down_speed = self.down_speed
        
        uptime = (datetime.datetime.now() - datetime.datetime.fromtimestamp(psutil.boot_time())).total_seconds()
        data = {
            "timestamp": time.time(),
            "uptime": uptime,
            "cpu_usage": cpu_usage,
            "cpu_temp": cpu_temp,
            "mem_used": mem_used,
            "mem_total": mem_total,
            "interface_name": self.interface_name,
            "up_speed": up_speed,
            "down_speed": down_speed,
            "cpu_core_loads": self.cpu_core_loads
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
        data = await request.post()

        if 'password' not in data:
            return web.Response(text='Password not provided', status=400)

        input_password = data['password']

        stored_password = keyring.get_password("server_status", "default")

        #Add FCM token if exists
        if input_password == stored_password and 'fcm_token' in data:
            if data['fcm_token'] != '':
                fcm_token = data['fcm_token']
                FCMTokens.add_token(fcm_token)

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

async def logout(request):
    data = await request.post()

    if 'fcm_token' not in data:
        return web.Response(text='Token not provided', status=400)
    
    fcm_token = data['fcm_token']
    FCMTokens.remove_token(fcm_token)
    
    return web.Response(text='Logout successful', status=200)

async def ping(request):
    return web.Response(text="pong")  




async def global_shutdown_async(app):
    for ws in set(app['websockets']):
        await ws.close(code=aiohttp.WSCloseCode.GOING_AWAY)
    shared_data = SharedData()
    shared_data.stop_updating()
    Notify.stop_service()

def create_app():
    #Init config file connection
    ConfigManager.initialize()
    #Start Notify thread
    Notify.start_service()
    #Init fcm_tokens db
    FCMTokens._init_db()
    # Start CPU data update in a separate thread
    shared_data = SharedData()
    cpu_thread = threading.Thread(target=shared_data.update_cpu_data, daemon=True)
    cpu_thread.start()
    #Start MEM data update in a separate thread
    mem_thread = threading.Thread(target=shared_data.update_mem_data, daemon=True)
    mem_thread.start()
    #Start NET data update in a separate thread
    net_thread = threading.Thread(target=shared_data.update_net_data, daemon=True)
    net_thread.start()
    
   


    # Prepare app
    app = web.Application()
    app['websockets'] = weakref.WeakSet()

    app.router.add_get("/auth", check_token)
    app.router.add_get("/ping", ping)
    app.router.add_post("/login", login)
    app.router.add_post("/logout", logout)
    app.router.add_get('/ws', websocket_handler)
    app.on_shutdown.append(global_shutdown_async)

    return app


#RUNNING USING gunicorn:
# gunicorn -w 1 -k aiohttp.GunicornWebWorker -b 0.0.0.0:8080 server_status:app

app = create_app()



