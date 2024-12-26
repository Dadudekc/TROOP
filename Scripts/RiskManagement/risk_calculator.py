# Scripts/RiskManagement/risk_calculator.py

import pandas as pd
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def calculate_max_drawdown(equity_curve: pd.Series):
    peak = equity_curve.expanding(min_periods=1).max()
    drawdown = (equity_curve - peak) / peak
    max_drawdown = drawdown.min()
    return max_drawdown

if __name__ == "__main__":
    backtest_path = "../../Backtesting/AAPL_backtest.csv"
    df = pd.read_csv(backtest_path)
    max_dd = calculate_max_drawdown(df['Portfolio_Value'])
    logging.info(f"Maximum Drawdown: {max_dd * 100:.2f}%")
    print(f"Maximum Drawdown: {max_dd * 100:.2f}%")
