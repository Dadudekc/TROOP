# Scripts/Utilities/data/data_ingest.py

import pandas as pd
import os

def ingest_csv(file_path: str):
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"CSV file not found at {file_path}")
    data = pd.read_csv(file_path)
    return data

def save_to_database(data: pd.DataFrame, db_handler):
    db_handler.insert_data(data)

if __name__ == "__main__":
    from db.db_handler import DBHandler
    
    data = ingest_csv("../../Data_Fetchers/sample_data.csv")
    db = DBHandler()
    save_to_database(data, db)
    print("Data ingested and saved to database.")
