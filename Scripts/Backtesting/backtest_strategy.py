# Scripts/Backtesting/backtest_strategy.py

import pandas as pd
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def load_data(file_path: str):
    return pd.read_csv(file_path)

def backtest(df: pd.DataFrame):
    initial_capital = 100000
    positions = 0
    cash = initial_capital
    portfolio_value = []
    
    for index, row in df.iterrows():
        if row['SMA_50'] > row['SMA_200'] and row['RSI'] < 30 and positions == 0:
            positions = cash / row['Close']
            cash = 0
            logging.info(f"Bought at {row['Close']} on {row['Date']}")
        elif row['SMA_50'] < row['SMA_200'] and row['RSI'] > 70 and positions > 0:
            cash = positions * row['Close']
            positions = 0
            logging.info(f"Sold at {row['Close']} on {row['Date']}")
        portfolio_value.append(cash + positions * row['Close'])
    
    df['Portfolio_Value'] = portfolio_value
    final_value = portfolio_value[-1]
    logging.info(f"Final Portfolio Value: {final_value}")
    return df

def save_backtest_results(df: pd.DataFrame, save_path: str):
    df.to_csv(save_path, index=False)
    logging.info(f"Backtest results saved to {save_path}.")

if __name__ == "__main__":
    file_path = "../../Data_Processing/AAPL_processed.csv"
    save_path = "../../Backtesting/AAPL_backtest.csv"
    df = load_data(file_path)
    df = backtest(df)
    save_backtest_results(df, save_path)
