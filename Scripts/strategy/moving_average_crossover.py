# Scripts/strategy/moving_average_crossover.py

import pandas as pd
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def generate_signals(df: pd.DataFrame):
    df['Signal'] = 0
    df.loc[df['SMA_50'] > df['SMA_200'], 'Signal'] = 1
    df.loc[df['SMA_50'] < df['SMA_200'], 'Signal'] = -1
    return df

if __name__ == "__main__":
    data_path = "../../Data_Processing/AAPL_processed.csv"
    save_path = "../../strategy/AAPL_strategy_signals.csv"
    
    df = pd.read_csv(data_path)
    df = generate_signals(df)
    df.to_csv(save_path, index=False)
    logging.info(f"Strategy signals saved to {save_path}.")
