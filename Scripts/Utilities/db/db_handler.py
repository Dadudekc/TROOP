# Scripts/Utilities/db/db_handler.py

import pyodbc
import os

class DBHandler:
    def __init__(self):
        self.server = os.getenv("DB_SERVER")
        self.database = os.getenv("DB_NAME")
        self.username = os.getenv("DB_USERNAME")
        self.password = os.getenv("DB_PASSWORD")
        self.connection = self.connect()

    def connect(self):
        conn_str = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={self.server};"
            f"DATABASE={self.database};"
            f"UID={self.username};"
            f"PWD={self.password}"
        )
        return pyodbc.connect(conn_str)

    def insert_data(self, data):
        cursor = self.connection.cursor()
        for index, row in data.iterrows():
            cursor.execute(
                "INSERT INTO FinancialData (Symbol, Date, Open, High, Low, Close, Volume) VALUES (?, ?, ?, ?, ?, ?, ?)",
                row['Symbol'], row['Date'], row['Open'], row['High'], row['Low'], row['Close'], row['Volume']
            )
        self.connection.commit()

    def fetch_data(self, query: str):
        cursor = self.connection.cursor()
        cursor.execute(query)
        columns = [column[0] for column in cursor.description]
        results = cursor.fetchall()
        return [dict(zip(columns, row)) for row in results]

if __name__ == "__main__":
    db = DBHandler()
    sample_query = "SELECT TOP 5 * FROM FinancialData"
    results = db.fetch_data(sample_query)
    for record in results:
        print(record)
