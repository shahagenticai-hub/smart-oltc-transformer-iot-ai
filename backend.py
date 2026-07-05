import json
import sqlite3
import threading
import time
from datetime import datetime

import paho.mqtt.client as mqtt
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sklearn.ensemble import IsolationForest
import numpy as np
import requests

# ── YOUR HIVEMQ CREDENTIALS ──────────────────────────
BROKER   = "YOUR_HIVEMQ_BROKER_URL"
PORT     = 8883
USERNAME = "YOUR_HIVEMQ_USERNAME"
PASSWORD = "YOUR_HIVEMQ_PASSWORD"
TOPIC    = "oltc/sensors"
# ─────────────────────────────────────────────────────

app = FastAPI(title="OLTC Backend API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── DATABASE SETUP ────────────────────────────────────
def init_db():
    conn = sqlite3.connect("oltc_data.db")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS readings (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp   TEXT,
            output_voltage REAL,
            current     REAL,
            power       REAL,
            temperature REAL,
            active_ssr  INTEGER,
            taps        TEXT
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS anomalies (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp   TEXT,
            type        TEXT,
            value       REAL,
            message     TEXT
        )
    """)
    conn.commit()
    conn.close()
    print("✅ Database ready")

# ── LATEST READING (in memory) ────────────────────────
latest_reading = {}
readings_buffer = []  # Store readings for training

# ── ISOLATION FOREST MODEL ───────────────────────────
iso_forest = None
model_trained = False
MIN_SAMPLES_FOR_TRAINING = 50

def train_isolation_forest():
    global iso_forest, model_trained, readings_buffer
    
    if len(readings_buffer) < MIN_SAMPLES_FOR_TRAINING:
        return
    
    try:
        # Extract features: voltage, current, power, temperature
        X = np.array([
            [r["output_voltage"], r["current"], r["power"], r["temperature"]]
            for r in readings_buffer
        ])
        
        # Train Isolation Forest
        iso_forest = IsolationForest(
            contamination=0.1,  # Expect ~10% anomalies
            random_state=42,
            n_estimators=100
        )
        iso_forest.fit(X)
        model_trained = True
        print("✅ Isolation Forest trained on", len(readings_buffer), "samples")
    except Exception as e:
        print(f"❌ Training failed: {e}")

def detect_anomaly_ml(data):
    """Use Isolation Forest to detect anomalies"""
    global iso_forest, model_trained
    
    if not model_trained or iso_forest is None:
        return None
    
    try:
        X = np.array([[
            data["output_voltage"],
            data["current"],
            data["power"],
            data["temperature"]
        ]])
        
        prediction = iso_forest.predict(X)[0]
        anomaly_score = iso_forest.score_samples(X)[0]
        
        # prediction = -1 means anomaly, 1 means normal
        if prediction == -1:
            return {
                "is_anomaly": True,
                "score": float(anomaly_score),
                "message": f"ML detected anomalous pattern (score: {anomaly_score:.2f})"
            }
        return {
            "is_anomaly": False,
            "score": float(anomaly_score),
            "message": "Normal operation"
        }
    except Exception as e:
        print(f"❌ ML detection error: {e}")
        return None

# ── ANOMALY DETECTION ─────────────────────────────────
def check_anomalies(data):
    anomalies = []
    ts = datetime.now().isoformat()

    # ═══ RULE-BASED DETECTION (UNCHANGED) ═══
    if not (108.5 <= data["output_voltage"] <= 111.5):
        anomalies.append({
            "timestamp": ts,
            "type": "voltage_out_of_range",
            "value": data["output_voltage"],
            "message": f"Output voltage {data['output_voltage']}V outside stable band 108.5–111.5V"
        })

    if data["temperature"] > 65:
        anomalies.append({
            "timestamp": ts,
            "type": "high_temperature",
            "value": data["temperature"],
            "message": f"Temperature {data['temperature']}°C exceeds safe limit of 65°C"
        })

    if data["current"] > 4.5:
        anomalies.append({
            "timestamp": ts,
            "type": "overcurrent",
            "value": data["current"],
            "message": f"Current {data['current']}A exceeds safe limit of 4.5A"
        })

    # ═══ ML-BASED DETECTION (NEW) ═══
    if model_trained:
        ml_result = detect_anomaly_ml(data)
        if ml_result and ml_result["is_anomaly"]:
            anomalies.append({
                "timestamp": ts,
                "type": "ml_pattern_anomaly",
                "value": ml_result["score"],
                "message": ml_result["message"]
            })

    if anomalies:
        conn = sqlite3.connect("oltc_data.db")
        cursor = conn.cursor()
        for a in anomalies:
            cursor.execute(
                "INSERT INTO anomalies (timestamp, type, value, message) VALUES (?,?,?,?)",
                (a["timestamp"], a["type"], a["value"], a["message"])
            )
            print(f"⚠️  ANOMALY: {a['message']}")
        conn.commit()
        conn.close()

# ── MQTT SUBSCRIBER ───────────────────────────────────
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Backend connected to HiveMQ")
        client.subscribe(TOPIC)
    else:
        print(f"❌ Connection failed: {rc}")

def on_message(client, userdata, msg):
    global latest_reading, readings_buffer
    try:
        data = json.loads(msg.payload.decode())
        data["timestamp"] = datetime.now().isoformat()
        latest_reading = data

        # Add to buffer for training
        readings_buffer.append(data)
        if len(readings_buffer) > 1000:  # Keep buffer size manageable
            readings_buffer.pop(0)

        # Train model every 50 new readings
        if len(readings_buffer) % 50 == 0 and not model_trained:
            train_isolation_forest()

        # Save to database
        conn = sqlite3.connect("oltc_data.db")
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO readings 
            (timestamp, output_voltage, current, power, temperature, active_ssr, taps)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            data["timestamp"],
            data["output_voltage"],
            data["current"],
            data["power"],
            data["temperature"],
            data["active_ssr"],
            json.dumps(data["taps"])
        ))
        conn.commit()
        conn.close()

        # Check for anomalies (both rule-based and ML)
        check_anomalies(data)

        print(f"💾 Saved: V={data['output_voltage']}V | T={data['temperature']}°C | SSR={data['active_ssr']} | ML: {'trained' if model_trained else 'training...'}")

    except Exception as e:
        print(f"❌ Error processing message: {e}")

def start_mqtt():
    client = mqtt.Client()
    client.username_pw_set(USERNAME, PASSWORD)
    client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT)
    client.loop_forever()

# ── API ENDPOINTS ─────────────────────────────────────
@app.get("/live")
def get_live():
    """Latest sensor reading"""
    if not latest_reading:
        return {"status": "no data yet"}
    return latest_reading

@app.get("/history")
def get_history(hours: int = 24):
    """Last N hours of readings"""
    conn = sqlite3.connect("oltc_data.db")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT timestamp, output_voltage, current, power, temperature, active_ssr
        FROM readings
        WHERE timestamp >= datetime('now', ? || ' hours')
        ORDER BY timestamp DESC
    """, (f"-{hours}",))
    rows = cursor.fetchall()
    conn.close()

    return [
        {
            "timestamp":      r[0],
            "output_voltage": r[1],
            "current":        r[2],
            "power":          r[3],
            "temperature":    r[4],
            "active_ssr":     r[5]
        }
        for r in rows
    ]

@app.get("/anomalies")
def get_anomalies():
    """All detected anomalies (rule-based + ML)"""
    conn = sqlite3.connect("oltc_data.db")
    cursor = conn.cursor()
    cursor.execute("SELECT timestamp, type, value, message FROM anomalies ORDER BY timestamp DESC LIMIT 50")
    rows = cursor.fetchall()
    conn.close()

    return [
        {
            "timestamp": r[0],
            "type":      r[1],
            "value":     r[2],
            "message":   r[3]
        }
        for r in rows
    ]

@app.get("/stats")
def get_stats():
    """Summary statistics"""
    conn = sqlite3.connect("oltc_data.db")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 
            COUNT(*) as total_readings,
            ROUND(AVG(output_voltage), 2) as avg_voltage,
            ROUND(MAX(temperature), 2) as max_temp,
            ROUND(AVG(current), 2) as avg_current
        FROM readings
    """)
    row = cursor.fetchone()
    conn.close()

    return {
        "total_readings": row[0],
        "avg_voltage":    row[1],
        "max_temperature": row[2],
        "avg_current":    row[3],
        "ml_model_trained": model_trained,
        "ml_samples_collected": len(readings_buffer)
    }

@app.get("/maintenance")
def get_maintenance():
    """Predictive maintenance score based on tap-switching frequency and temperature"""
    conn = sqlite3.connect("oltc_data.db")
    cursor = conn.cursor()
    
    # Count tap switches in last 24 hours
    cursor.execute("""
        SELECT active_ssr FROM readings
        ORDER BY timestamp DESC LIMIT 200
    """)
    rows = cursor.fetchall()
    
    switch_count = 0
    for i in range(1, len(rows)):
        if rows[i][0] != rows[i-1][0]:
            switch_count += 1
    
    # Average and max temperature
    cursor.execute("""
        SELECT AVG(temperature), MAX(temperature) FROM readings
        ORDER BY timestamp DESC LIMIT 200
    """)
    temp_row = cursor.fetchone()
    avg_temp = temp_row[0] or 35
    max_temp = temp_row[1] or 35
    
    conn.close()
    
    # Simple weighted scoring model
    # Base life: 180 days, reduced by switching frequency and heat stress
    base_days = 180
    switch_penalty = switch_count * 1.5
    temp_penalty = max(0, (avg_temp - 40)) * 3
    heat_spike_penalty = max(0, (max_temp - 55)) * 5
    
    estimated_days = base_days - switch_penalty - temp_penalty - heat_spike_penalty
    estimated_days = max(5, round(estimated_days))
    
    # Health status
    if estimated_days > 90:
        health = "Excellent"
        color = "green"
    elif estimated_days > 45:
        health = "Good"
        color = "yellow"
    elif estimated_days > 15:
        health = "Monitor Closely"
        color = "orange"
    else:
        health = "Service Required Soon"
        color = "red"
    
    return {
        "estimated_days_to_maintenance": estimated_days,
        "health_status": health,
        "health_color": color,
        "tap_switches_recent": switch_count,
        "avg_temperature": round(avg_temp, 1),
        "max_temperature": round(max_temp, 1)
    }

@app.post("/chat")
async def chat_with_ai(request: dict):
    user_question = request.get("question", "")

    if not latest_reading:
        return {"answer": "No live data available yet. Please wait for sensor data."}

    context = f"""You are an AI assistant for a Smart OLTC (On-Load Tap Changer) Transformer monitoring system.

Current live sensor readings:
- Output Voltage: {latest_reading.get('output_voltage', 'N/A')}V
- Current: {latest_reading.get('current', 'N/A')}A
- Power: {latest_reading.get('power', 'N/A')}W
- Temperature: {latest_reading.get('temperature', 'N/A')}°C
- Active Tap: {latest_reading.get('active_ssr', 'N/A')}

Answer the user's question using this live data. Be concise (2-3 sentences max), technical but clear. If the question isn't about the system, politely redirect to system-related topics.

User question: {user_question}
"""

    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "phi3",
                "prompt": context,
                "stream": False
            },
            timeout=30
        )
        result = response.json()
        return {"answer": result.get("response", "Sorry, I couldn't process that.").strip()}
    except Exception as e:
        return {"answer": f"Error connecting to AI: {str(e)}"}

# ── STARTUP ───────────────────────────────────────────
@app.on_event("startup")
def startup():
    init_db()
    thread = threading.Thread(target=start_mqtt, daemon=True)
    thread.start()
    print("🚀 OLTC Backend API running with Isolation Forest ML")