import paho.mqtt.client as mqtt
import json
import time
import random
import math

# ── YOUR HIVEMQ CREDENTIALS ──────────────────────────
BROKER   = "YOUR_HIVEMQ_BROKER_URL"
PORT     = 8883
USERNAME = "YOUR_HIVEMQ_USERNAME"
PASSWORD = "YOUR_HIVEMQ_PASSWORD"
TOPIC    = "oltc/sensors"
# ─────────────────────────────────────────────────────

# ── REAL SYSTEM PARAMETERS ───────────────────────────
TAP_VOLTAGES = [100, 102, 104, 106, 108, 110, 112, 114, 116, 118, 120, 122, 124, 126, 0]
STABLE_LOW   = 108.5
STABLE_HIGH  = 111.5
TARGET       = 110.0

# ── SIMULATION STATE ──────────────────────────────────
class OLTCSimulator:
    def __init__(self):
        self.active_tap     = 5   # TAP 6 = 110V (0-indexed)
        self.primary_voltage = 220.0
        self.bulbs_on       = 1   # number of bulbs active (0-5)
        self.temperature    = 32.0
        self.time_counter   = 0
        self.last_switch_time = 0
        self.switch_delay   = 5   # seconds between tap switches

    def simulate_primary_variation(self):
        """Primary voltage varies 200-250V like real grid"""
        # Slow sinusoidal variation mimicking real grid fluctuation
        variation = 15 * math.sin(self.time_counter * 0.02)
        noise     = random.uniform(-2, 2)
        self.primary_voltage = 220 + variation + noise
        self.primary_voltage = max(200, min(250, self.primary_voltage))

    def simulate_load_change(self):
        """Randomly switch bulbs on/off every ~30 seconds"""
        if self.time_counter % 30 == 0:
            self.bulbs_on = random.randint(0, 5)

    def get_tap_output(self, tap_index):
        """Get output voltage for a given tap with primary variation effect"""
        if TAP_VOLTAGES[tap_index] == 0:
            return 0
        # Scale tap voltage with primary variation
        ratio  = self.primary_voltage / 220.0
        output = TAP_VOLTAGES[tap_index] * ratio
        return round(output + random.uniform(-0.3, 0.3), 2)

    def control_algorithm(self, current_output):
        """Mimic Arduino tap switching algorithm"""
        now = self.time_counter
        if now - self.last_switch_time < self.switch_delay:
            return  # Minimum time between switches

        if current_output < STABLE_LOW and self.active_tap < 13:
            self.active_tap += 1
            self.last_switch_time = now
            print(f"⚡ TAP UP → TAP {self.active_tap + 1} (voltage was {current_output}V)")

        elif current_output > STABLE_HIGH and self.active_tap > 0:
            self.active_tap -= 1
            self.last_switch_time = now
            print(f"⚡ TAP DOWN → TAP {self.active_tap + 1} (voltage was {current_output}V)")

    def simulate_temperature(self, current):
        """Temperature rises with load, falls slowly when idle"""
        target_temp = 32 + (current * 6) + (self.primary_voltage - 220) * 0.1
        # Gradual temperature change (thermal inertia)
        self.temperature += (target_temp - self.temperature) * 0.05
        self.temperature += random.uniform(-0.2, 0.2)
        self.temperature = round(self.temperature, 2)

    def generate_data(self):
        self.time_counter += 1
        self.simulate_primary_variation()
        self.simulate_load_change()

        # Get current tap output
        output_voltage = self.get_tap_output(self.active_tap)

        # Run control algorithm
        self.control_algorithm(output_voltage)

        # Recalculate output after possible tap change
        output_voltage = self.get_tap_output(self.active_tap)

        # Current and power based on bulbs
        # Each bulb ~60W at 110V = ~0.55A
        base_current = self.bulbs_on * 0.55
        current      = round(base_current + random.uniform(-0.05, 0.05), 2)
        current      = max(0, current)
        power        = round(output_voltage * current, 2)

        # Temperature
        self.simulate_temperature(current)

        # All 15 tap voltages
        taps = {}
        for i in range(15):
            taps[f"T{i+1}"] = self.get_tap_output(i)

        return {
            "output_voltage": output_voltage,
            "current":        current,
            "power":          power,
            "temperature":    self.temperature,
            "active_ssr":     self.active_tap + 1,
            "taps":           taps
        }

# ── MQTT SETUP ────────────────────────────────────────
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Connected to HiveMQ successfully")
    else:
        print(f"❌ Connection failed: {rc}")

client = mqtt.Client()
client.username_pw_set(USERNAME, PASSWORD)
client.tls_set()
client.on_connect = on_connect

print("Connecting to HiveMQ...")
client.connect(BROKER, PORT)
client.loop_start()
time.sleep(2)

# ── RUN SIMULATION ────────────────────────────────────
simulator = OLTCSimulator()
print("📡 Publishing realistic OLTC data every 3 seconds... (Ctrl+C to stop)")
print("🔌 Simulating: primary variation 200-250V, 5 bulb loads, real tap switching")

while True:
    data    = simulator.generate_data()
    payload = json.dumps(data)
    client.publish(TOPIC, payload)
    print(f"📤 V={data['output_voltage']}V | I={data['current']}A | "
          f"P={data['power']}W | T={data['temperature']}°C | "
          f"TAP={data['active_ssr']} | Bulbs={simulator.bulbs_on} | "
          f"Primary={round(simulator.primary_voltage, 1)}V")
    time.sleep(3)