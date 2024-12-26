# Scripts/GUI/trading_dashboard.py

import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
from Utilities.db.db_handler import DBHandler

def main():
    st.title("TROOP Trading Dashboard")
    
    menu = ["Home", "View Data", "Run Backtest", "ML Predictions", "Risk Management"]
    choice = st.sidebar.selectbox("Menu", menu)
    
    db = DBHandler()
    
    if choice == "Home":
        st.subheader("Welcome to TROOP Trading Dashboard")
        st.write("Use the sidebar to navigate through different functionalities.")
    
    elif choice == "View Data":
        st.subheader("View Financial Data")
        symbol = st.text_input("Enter Stock Symbol", "AAPL")
        query = f"SELECT TOP 100 * FROM FinancialData WHERE Symbol = '{symbol}' ORDER BY Date DESC"
        data = db.fetch_data(query)
        df = pd.DataFrame(data)
        st.dataframe(df)
        
        if st.button("Show Close Price"):
            plt.figure(figsize=(10,5))
            plt.plot(pd.to_datetime(df['Date']), df['Close'], label='Close Price')
            plt.xlabel('Date')
            plt.ylabel('Close Price')
            plt.title(f'{symbol} Close Price Over Time')
            plt.legend()
            st.pyplot(plt)
    
    elif choice == "Run Backtest":
        st.subheader("Run Backtest on Strategy")
        symbol = st.text_input("Enter Stock Symbol for Backtesting", "AAPL")
        if st.button("Run Backtest"):
            backtest_script = "../../Backtesting/backtest_strategy.py"
            result = os.system(f"python {backtest_script} ../../Data_Processing/{symbol}_processed.csv ../../Backtesting/{symbol}_backtest.csv")
            if result == 0:
                st.success("Backtest completed successfully!")
                backtest_data = pd.read_csv(f"../../Backtesting/{symbol}_backtest.csv")
                st.line_chart(backtest_data[['Date', 'Portfolio_Value']].set_index('Date'))
            else:
                st.error("Backtest failed. Check logs for details.")
    
    elif choice == "ML Predictions":
        st.subheader("Machine Learning Predictions")
        symbol = st.text_input("Enter Stock Symbol for Predictions", "AAPL")
        if st.button("Generate Signals"):
            ml_script = "../../MLIntegration/predict_signals.py"
            result = os.system(f"python {ml_script} ../../Data_Processing/{symbol}_processed.csv ../../model_training/trading_model.pkl ../../MLIntegration/{symbol}_signals.csv")
            if result == 0:
                st.success("ML Signals generated successfully!")
                signals_data = pd.read_csv(f"../../MLIntegration/{symbol}_signals.csv")
                st.line_chart(signals_data[['Date', 'ML_Signal']].set_index('Date'))
            else:
                st.error("ML Predictions failed. Check logs for details.")
    
    elif choice == "Risk Management":
        st.subheader("Risk Management Tools")
        st.write("Coming soon!")

if __name__ == "__main__":
    main()
