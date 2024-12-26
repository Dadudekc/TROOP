# Scripts/Data_Processing/apply_indicators.py

import pandas as pd
import talib
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def load_data(file_path: str):
    return pd.read_csv(file_path)

def add_technical_indicators(df: pd.DataFrame):
    df['SMA_50'] = talib.SMA(df['Close'], timeperiod=50)
    df['SMA_200'] = talib.SMA(df['Close'], timeperiod=200)
    df['RSI'] = talib.RSI(df['Close'], timeperiod=14)
    return df

def save_processed_data(df: pd.DataFrame, save_path: str):
    df.to_csv(save_path, index=False)
    logging.info(f"Processed data saved to {save_path}.")

if __name__ == "__main__":
    file_path = "../../Data_Fetchers/AAPL_data.csv"
    save_path = "../../Data_Processing/AAPL_processed.csv"
    df = load_data(file_path)
    df = add_technical_indicators(df)
    save_processed_data(df, save_path)
