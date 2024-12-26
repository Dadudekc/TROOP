# Scripts/Scheduler/scheduler.py

import schedule
import time
import subprocess
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def job_fetch_data():
    logging.info("Starting data fetch job...")
    subprocess.run(["python", "../../Data_Fetchers/fetch_financial_data.py"], check=True)
    logging.info("Data fetch job completed.")

def job_backtest():
    logging.info("Starting backtest job...")
    subprocess.run(["python", "../../Backtesting/backtest_strategy.py"], check=True)
    logging.info("Backtest job completed.")

def job_ml_predictions():
    logging.info("Starting ML predictions job...")
    subprocess.run(["python", "../../MLIntegration/predict_signals.py"], check=True)
    logging.info("ML predictions job completed.")

def start_scheduler():
    schedule.every().day.at("09:00").do(job_fetch_data)
    schedule.every().day.at("18:00").do(job_backtest)
    schedule.every().day.at("19:00").do(job_ml_predictions)
    
    logging.info("Scheduler started. Waiting for jobs...")
    
    while True:
        schedule.run_pending()
        time.sleep(60)  # wait one minute

if __name__ == "__main__":
    start_scheduler()
