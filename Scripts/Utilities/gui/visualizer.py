# Scripts/Utilities/gui/visualizer.py

import matplotlib.pyplot as plt
import pandas as pd

def plot_trading_strategy(data: pd.DataFrame, strategy_signals: pd.Series):
    plt.figure(figsize=(14,7))
    plt.plot(data['Date'], data['Close'], label='Close Price')
    plt.plot(data['Date'], strategy_signals, label='Strategy Signal')
    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.title('Trading Strategy Visualization')
    plt.legend()
    plt.show()

if __name__ == "__main__":
    # Sample data
    data = pd.read_csv("../../Data_Fetchers/sample_data.csv")
    strategy_signals = pd.Series([0, 1, 0, -1, 0, 1, 0], name="Signal")
    plot_trading_strategy(data, strategy_signals)
