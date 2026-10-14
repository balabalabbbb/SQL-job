import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DB_CONFIG = {
    'server': 'localhost',
    'database': 'retail_store',
    'username': 'sa',
    'password': 'Root@123456',
    'driver': '{ODBC Driver 17 for SQL Server}',
    'trust_cert': True
}

SECRET_KEY = 'retail-store-secret-key-2024'

LOG_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)
