# Scripts/model_training/optimize_hyperparameters.py

from sklearn.model_selection import GridSearchCV
from sklearn.ensemble import RandomForestClassifier
import joblib
import pandas as pd
import os
from Utilities.config_handling.config import setup_logging
import logging

setup_logging()

def load_data(file_path: str):
    return pd.read_csv(file_path)

def preprocess_data(data: pd.DataFrame):
    data = data.dropna()
    features = data[['Open', 'High', 'Low', 'Close', 'Volume', 'SMA_50', 'SMA_200', 'RSI']]
    target = data['Target']
    return features, target

def optimize_model(features, target):
    param_grid = {
        'n_estimators': [50, 100, 200],
        'max_depth': [None, 10, 20],
        'min_samples_split': [2, 5, 10]
    }
    rf = RandomForestClassifier(random_state=42)
    grid_search = GridSearchCV(estimator=rf, param_grid=param_grid, cv=5, scoring='accuracy')
    grid_search.fit(features, target)
    logging.info(f"Best parameters: {grid_search.best_params_}")
    logging.info(f"Best score: {grid_search.best_score_}")
    return grid_search.best_estimator_

def save_model(model, save_path: str):
    joblib.dump(model, save_path)
    logging.info(f"Optimized model saved to {save_path}.")

if __name__ == "__main__":
    data_path = "../../Data_Fetchers/AAPL_data.csv"
    model_save_path = "../../model_training/trading_model_optimized.pkl"
    
    data = load_data(data_path)
    features, target = preprocess_data(data)
    optimized_model = optimize_model(features, target)
    save_model(optimized_model, model_save_path)
