import socket
from fastapi import FastAPI

app = FastAPI(title="ResiliaProxy Backend Service")

@app.get("/")
def read_root():
    return {
        "status": "success",
        "message": "Welcome to ResiliaProxy Load Balanced Backend Service!",
        "hostname": socket.gethostname()
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}
