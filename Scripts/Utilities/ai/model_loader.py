# Scripts/Utilities/ai/model_loader.py

import joblib
import os

def load_model(model_path: str):
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found at {model_path}")
    model = joblib.load(model_path)
    return model

def predict(model, data):
    return model.predict(data)

if __name__ == "__main__":
    model = load_model("../../models/trading_model.pkl")
    sample_data = [...]  # Replace with actual data
    predictions = predict(model, sample_data)
    print(predictions)
