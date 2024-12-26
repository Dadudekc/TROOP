# Scripts/Utilities/api/financial_api.py

import requests
import os

API_KEY = os.getenv("FINANCIAL_API_KEY")
BASE_URL = "https://api.financialdata.com/v1/"

def fetch_stock_data(symbol: str):
    endpoint = f"{BASE_URL}stocks/{symbol}/data"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    response = requests.get(endpoint, headers=headers)
    response.raise_for_status()
    return response.json()

if __name__ == "__main__":
    symbol = "AAPL"
    data = fetch_stock_data(symbol)
    print(data)
