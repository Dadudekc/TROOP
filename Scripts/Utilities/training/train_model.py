# Scripts/Utilities/training/train_model.py

from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import joblib
import pandas as pd
import os

def load_data(file_path: str):
    return pd.read_csv(file_path)

def preprocess_data(data: pd.DataFrame):
    # Example preprocessing
    data = data.dropna()
    features = data[['Open', 'High', 'Low', 'Close', 'Volume']]
    target = data['Target']  # Assume 'Target' column exists
    return features, target

def train_model(features, target):
    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2)
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)
    return model, X_test, y_test

def evaluate_model(model, X_test, y_test):
    return model.score(X_test, y_test)

if __name__ == "__main__":
    data = load_data("../../Data_Fetchers/sample_data.csv")
    features, target = preprocess_data(data)
    model, X_test, y_test = train_model(features, target)
    accuracy = evaluate_model(model, X_test, y_test)
    print(f"Model Accuracy: {accuracy * 100:.2f}%")
    joblib.dump(model, "../../model_training/trading_model.pkl")
    print("Model saved successfully.")
