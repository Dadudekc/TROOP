# Scripts/MLIntegration/predict_signals.py

import pandas as pd
import joblib
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def load_data(file_path: str):
    return pd.read_csv(file_path)

def load_model(model_path: str):
    return joblib.load(model_path)

def generate_signals(model, features: pd.DataFrame):
    return model.predict(features)

def save_signals(df: pd.DataFrame, signals: pd.Series, save_path: str):
    df['ML_Signal'] = signals
    df.to_csv(save_path, index=False)
    logging.info(f"Signals generated and saved to {save_path}.")

if __name__ == "__main__":
    data_path = "../../Data_Processing/AAPL_processed.csv"
    model_path = "../../model_training/trading_model.pkl"
    save_path = "../../MLIntegration/AAPL_signals.csv"
    
    df = load_data(data_path)
    model = load_model(model_path)
    features = df[['Open', 'High', 'Low', 'Close', 'Volume', 'SMA_50', 'SMA_200', 'RSI']]
    signals = generate_signals(model, features)
    save_signals(df, signals, save_path)
