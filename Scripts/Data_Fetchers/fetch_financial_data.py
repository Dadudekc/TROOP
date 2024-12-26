# Scripts/Data_Fetchers/fetch_financial_data.py

from Utilities.api.financial_api import fetch_stock_data
from Utilities.config_handling.config import setup_logging
import logging
import pandas as pd

setup_logging()

def fetch_and_save(symbol: str, save_path: str):
    try:
        data = fetch_stock_data(symbol)
        df = pd.DataFrame(data['prices'])
        df.to_csv(save_path, index=False)
        logging.info(f"Successfully fetched and saved data for {symbol} to {save_path}.")
    except Exception as e:
        logging.error(f"Failed to fetch data for {symbol}: {e}")

if __name__ == "__main__":
    symbols = ["AAPL", "GOOGL", "MSFT"]
    for symbol in symbols:
        save_path = f"../../Data_Fetchers/{symbol}_data.csv"
        fetch_and_save(symbol, save_path)
