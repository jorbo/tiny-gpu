import datetime
from pathlib import Path

class Logger:
    def __init__(self, level="debug"):
        folder = Path(__file__).resolve().parents[3] / "build" / "logs"
        folder.mkdir(parents=True, exist_ok=True)
        self.filename = str(folder / f"log_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.txt")
        self.level = level

    def debug(self, *messages):
        if self.level == "debug":
            self.info(*messages)

    def info(self, *messages):
        full_message = ' '.join(str(message) for message in messages)
        with open(self.filename, "a") as log_file:
            log_file.write(full_message + "\n")

logger = Logger(level="debug")
