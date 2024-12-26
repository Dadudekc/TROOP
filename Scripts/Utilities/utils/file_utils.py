# Scripts/Utilities/utils/file_utils.py

import os

def ensure_directory(path: str):
    if not os.path.exists(path):
        os.makedirs(path)

def list_files(directory: str, extension: str = ""):
    files = []
    for file in os.listdir(directory):
        if extension:
            if file.endswith(extension):
                files.append(file)
        else:
            files.append(file)
    return files

if __name__ == "__main__":
    ensure_directory("../../Logs")
    print("Directories ensured and files listed.")
