# Scripts/Utilities/config_handling/config.py

import logging
import os

def setup_logging(log_file: str = "troop.log"):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )

def get_config_value(key: str, default=None):
    return os.getenv(key, default)

if __name__ == "__main__":
    setup_logging()
    logging.info("Logging is set up.")
