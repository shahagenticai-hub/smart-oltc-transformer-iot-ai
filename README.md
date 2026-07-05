# Smart OLTC Transformer System with IoT Monitoring & AI/ML Intelligence

A complete end-to-end IoT and AI system built on top of a custom-designed Smart On-Load Tap Changing (OLTC) Transformer. The system maintains stable 110V secondary output despite primary voltage fluctuating between 200V to 250V, with real-time cloud monitoring, machine learning anomaly detection, predictive maintenance scoring, and a locally-hosted RAG-based AI chatbot.

---

## Project Overview

Traditional mechanical OLTCs are slow, prone to arcing, and require frequent maintenance. This project replaces mechanical switching entirely with **zero-cross detection Solid State Relays (SSRs)**, eliminating arcing and achieving millisecond-level switching precision.

On top of the hardware, a complete software stack was built providing real-time monitoring, ML-based anomaly detection, and AI-powered natural language interaction with live sensor data.

---

## System Architecture

```
ESP32 / Simulator
      ↓
HiveMQ Cloud (MQTT Broker)
      ↓
FastAPI Backend (Python)
      ↓
SQLite Database
      ↓
Flutter Mobile App + AI Chatbot (Ollama + Phi-3)
```

---

## Hardware Components

- Custom-wound 14-tap transformer (100V to 126V, 2V steps)
- Zero-cross detection SSRs for contactless, arc-free tap switching
- Arduino Mega running the core tap-switching control algorithm
- ESP32 for IoT connectivity and serial communication with Arduino
- ZMPT101B voltage sensor for accurate RMS measurement
- Current transformer (CT) for load current monitoring
- Thermistor for transformer temperature monitoring
- 20x4 LCD for local on-device display
- Circuit validated in Proteus ISIS before hardware assembly

---

## Software Stack

| Layer | Technology |
|-------|-----------|
| IoT Messaging | MQTT, HiveMQ Cloud |
| Backend | Python, FastAPI, Uvicorn |
| Database | SQLite |
| ML Anomaly Detection | scikit-learn, Isolation Forest |
| Mobile App | Flutter, Dart |
| Charts | fl_chart |
| AI Chatbot | Ollama, Phi-3, RAG |
| Hardware | Arduino C++, ESP32 |

---

## Features

**Real-Time Dashboard**
- Live voltage, current, power and temperature cards
- Active tap position display
- All 15 tap voltages with active tap highlighted
- Predictive maintenance modal

**History Tab**
- Voltage chart with stable band reference lines (108.5V to 111.5V)
- Temperature chart with configurable range
- Last 15 readings list

**Anomaly Detection**
- Rule-based detection (voltage out of range, overcurrent, high temperature)
- Isolation Forest ML model for non-linear pattern anomaly detection
- Retrains every 50 readings automatically

**Predictive Maintenance**
- Health score based on tap-switching frequency and thermal stress
- Status levels: Excellent, Good, Monitor Closely, Service Required

**AI Chatbot with RAG**
- Locally-hosted LLM using Ollama with Phi-3 model
- Live sensor data injected as context for every query
- Fully offline, zero cloud dependency, zero API cost
- Natural language answers about real-time system state

---

## Project Structure

```
smart-oltc-transformer-iot-ai/
├── backend.py          # FastAPI backend with MQTT, SQLite, ML
├── simulator.py        # Realistic OLTC data simulator
├── lib/
│   └── main.dart       # Complete Flutter app
├── pubspec.yaml        # Flutter dependencies
└── android/
    └── app/src/main/
        └── AndroidManifest.xml
```

---

## Setup and Running

### Prerequisites

- Python 3.10+
- Flutter SDK
- Ollama (for AI chatbot)
- HiveMQ Cloud account (free tier)

### Install Python dependencies

```bash
pip install fastapi uvicorn paho-mqtt scikit-learn numpy requests
```

### Configure credentials

In both `backend.py` and `simulator.py`, replace the placeholder values:

```python
BROKER   = "your-hivemq-broker-url"
USERNAME = "your-hivemq-username"
PASSWORD = "your-hivemq-password"
```

### Install and run Ollama

Download from [ollama.ai](https://ollama.ai), then:

```bash
ollama pull phi3
```

### Run the system (3 terminals)

**Terminal 1 — Simulator:**
```bash
python simulator.py
```

**Terminal 2 — Backend:**
```bash
python -m uvicorn backend:app --host 0.0.0.0 --reload --port 8000
```

**Terminal 3 — Flutter app:**
```bash
cd oltc_app
flutter run -d chrome
```

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| GET /live | Latest sensor reading |
| GET /history | Time-series data (last 24hrs) |
| GET /anomalies | All detected anomalies |
| GET /stats | Summary statistics and ML status |
| GET /maintenance | Predictive maintenance score |
| POST /chat | AI chatbot with RAG |

---

## Team

- Raja Talal Hassan
- Muhammad Bashaar Saleem
- Ali Muntazir Mahdi
- Abdul Hanan

**Institution:** Government College University Lahore
**Program:** B.Sc. Electrical Engineering (2022-2026)

---

## Tags

`IoT` `MQTT` `FastAPI` `Flutter` `MachineLearning` `IsolationForest` `RAG` `Ollama` `Phi3` `TransformerMonitoring` `OLTC` `ESP32` `Arduino` `PredictiveMaintenance` `AgenticAI`
