# ResiliaProxy 🚀

**ResiliaProxy** is a High-Availability (HA) Local Proxy & Load Balancer setup designed to demonstrate containerized routing, passive health checks, and horizontal scaling. 

This repository includes a custom **SRE Autoscaler Daemon** that monitors container CPU usage dynamically and scales the backend count up or down between 2 and 5 instances based on live load.

---

## 🏗️ Architecture Overview

The system consists of the following components:
1. **Nginx Reverse Proxy & Load Balancer**: Bound to host port `8080`, listening for incoming traffic, routing requests using a **Round-Robin** algorithm.
2. **FastAPI Backends (Dynamically Scaled)**: Containerized instances running Python 3.9. They expose endpoint responses containing their unique container hostname to trace routing dynamically.
3. **Passive Health Checks**: Built into Nginx configuration to monitor backend nodes dynamically. If an instance fails 3 times consecutively, Nginx handles it gracefully, routes the request to healthy nodes, and refrains from sending traffic to that failed node for 10s.
4. **Local Autoscaler Daemon**: A PowerShell script (`autoscaler.ps1`) running on the host that polls Docker CPU metrics and scales the backend container pool dynamically.

```
                      [ Host Port: 8080 ]
                               │
                               ▼
                 ┌──────────────────────────┐
                 │    Nginx Load Balancer   │
                 └─────────────┬────────────┘
                               │ (Dynamic DNS Resolution & Round Robin)
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  FastAPI Node 1  │  │  FastAPI Node 2  │  │  FastAPI Node N  │
│ (Instance IP A)  │  │ (Instance IP B)  │  │ (Instance IP N)  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 📁 Repository Structure

```text
├── Dockerfile           # Builds the FastAPI container image
├── requirements.txt     # Python application dependencies
├── main.py              # FastAPI app source code
├── nginx.conf           # Nginx load-balancer configuration
├── docker-compose.yml   # Multi-container orchestration config
├── autoscaler.ps1       # SRE Autoscaler Daemon script (Windows PowerShell)
├── stress_test.ps1      # Traffic stress testing script
├── load_test.ps1        # Static load distribution test script
└── README.md            # Project documentation (this file)
```

---

## ⚡ Prerequisites

To run this project locally, ensure you have the following installed:
- **Docker Desktop** (with Compose enabled)
- **Anaconda** or **Miniconda** (for managing local Python/Conda environments)

---

## 🚀 Local Installation & Setup

### Step 1: Clone the Repository
```bash
git clone https://github.com/Ravindu-Sampath-Weerakoon/autoscale_Load_Balancer.git
cd autoscale_Load_Balancer
```

### Step 2: Set Up Local Conda Environment
Creating a local conda environment ensures you can run, debug, and format the Python code locally using identical dependency versions.
```bash
# Create the ResiliaProxy environment running Python 3.9
conda create -n resiliaproxy python=3.9 -y

# Activate the environment
conda activate resiliaproxy

# Install the dependencies
pip install -r requirements.txt
```

---

## 🎮 Hands-On Demo Guide (Auto-Scaling in Action)

To see the system scale up and down automatically under load, open **two separate PowerShell terminals** in the project directory:

### Terminal 1: Run the Autoscaler Daemon
Run the autoscaler script:
```powershell
powershell -ExecutionPolicy Bypass -File .\autoscaler.ps1
```
* **What it does:** It boots the cluster at a minimum scale of **2 web containers** and the Nginx proxy, then starts printing average CPU load metrics every 5 seconds.

---

### Terminal 2: Generate Load & Observe

#### A. Test Load Distribution (Static Verification)
Send 100 requests to check that Nginx is load-balancing requests evenly between the 2 running instances:
```powershell
powershell -ExecutionPolicy Bypass -File .\load_test.ps1
```
* **Expected Output:** 
  A clean 50% split of requests between the two running container hostnames.

#### B. Simulate a Traffic Spike (Scale Up)
Send 1,500 asynchronous requests quickly to generate a load spike:
```powershell
powershell -ExecutionPolicy Bypass -File .\stress_test.ps1
```
* **Observation:** Switch back to **Terminal 1**. As CPU load spikes above 15%, you will see the Autoscaler automatically spin up new instances (scaling from 2 ➔ 3 ➔ 4 ➔ 5 instances) and reload Nginx on the fly (`nginx -s reload`) to accommodate the traffic.

#### C. Cool Down (Scale Down)
Once the stress test in Terminal 2 completes:
* **Observation:** Wait about 15-20 seconds. The CPU load will drop back down. In **Terminal 1**, you will see the Autoscaler dynamically terminate the extra instances, scaling back down to the minimum limit of **2 instances**.

---

## 📊 Live Monitoring Commands

While running tests, you can use these commands to inspect the cluster's health:

### Docker Container Resource Stats
To view CPU %, Memory, and Network usage for all containers in real-time:
```bash
docker stats
```

### Stream Load Balancer Logs
To watch Nginx distribute incoming connections to backend IPs:
```bash
docker compose logs -f nginx
```

---

## 🛠️ Under the Hood SRE Design

### Nginx Dynamic Resolution
Nginx handles thousands of concurrent connections using an **asynchronous, event-driven, non-blocking** architecture. Rather than dedicating a thread to each open connection, a single worker process handles them using system-level multiplexing (e.g., `epoll` or `kqueue`). This keeps memory usage extremely low.

### Passive Health Checks
Passive health checking monitors server responses inline as requests are made:
* `max_fails=3`: The number of unsuccessful attempts to communicate with the server before considering it unavailable.
* `fail_timeout=10s`: The duration of time the server is marked as unavailable after failing `max_fails` times.

```nginx
upstream fastapi_backend {
    server web:8000 max_fails=3 fail_timeout=10s;
}
```

---

## 📤 Uploading to GitHub

Follow these steps to initialize git and push this project to your GitHub account:

1. **Initialize Git Repository:**
   ```bash
   git init
   ```

2. **Stage and Commit the Files:**
   ```bash
   git add .
   git commit -m "feat: complete HA proxy & autoscaling backend cluster"
   ```

3. **Set Main Branch and Remote Repository:**
   Link your local repository to your remote GitHub repository:
   ```bash
   git branch -M main
   git remote add origin https://github.com/Ravindu-Sampath-Weerakoon/autoscale_Load_Balancer.git
   ```

4. **Push to GitHub:**
   ```bash
   git push -u origin main
   ```

---

## 🛑 Tear Down
To stop the cluster and clean up all allocated Docker containers and networks:
```bash
docker compose down
```
