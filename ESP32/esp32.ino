#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <LoRa.h>

// ================= Wi-Fi =================
const char* ssid     = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// ================= Supabase =================
const char* supabase_url = "https://oqsdoubmzzkfgcvvsbfb.supabase.co/rest/v1/sensor_table";
const char* supabase_key = "YOUR_SUPABASE_ANON_KEY";

// ================= Pico UART (Serial1) =================
#define RXpico 32
#define TXpico 33

// ================= GSM (Serial2) =================
#define RXD2 16
#define TXD2 17
HardwareSerial& sim900a = Serial2;
const String RECIPIENT_NUMBER = "+60XXXXXXXXXX";
const unsigned long SMS_COOLDOWN_MS = 5UL * 60UL * 1000UL; // min gap between SMS
unsigned long lastSmsTime = 0;
bool gsmReady = false;

// ================= LoRa (custom VSPI) =================
#define SCK_PIN   5
#define MISO_PIN  19
#define MOSI_PIN  27
#define SS_PIN    18
#define RST_PIN   14
#define DIO0_PIN  26
#define LORA_FREQ 433E6          // change to match your module/band
SPIClass customSPI(VSPI);
bool loraReady = false;

// ---------------------------------------------------------------
// GSM helpers
// ---------------------------------------------------------------
String sendCommand(const String& cmd, unsigned int timeout = 2000) {
  String response = "";
  sim900a.println(cmd);
  unsigned long start = millis();
  while (millis() - start < timeout) {
    while (sim900a.available()) response += (char)sim900a.read();
  }
  return response;
}

bool initGSM() {
  if (sendCommand("AT").indexOf("OK") == -1) return false;

  bool simOk = false;
  for (int i = 0; i < 3 && !simOk; i++) {
    simOk = sendCommand("AT+CPIN?").indexOf("READY") != -1;
    if (!simOk) delay(1000);
  }
  if (!simOk) return false;

  for (int i = 0; i < 15; i++) {
    String r = sendCommand("AT+CREG?");
    if (r.indexOf(",1") != -1 || r.indexOf(",5") != -1) {
      sendCommand("AT+CMGF=1", 1000); // SMS text mode
      return true;
    }
    delay(2000);
  }
  return false;
}

bool sendSMS(const String& text) {
  if (!gsmReady) return false;
  if (millis() - lastSmsTime < SMS_COOLDOWN_MS && lastSmsTime != 0) {
    Serial.println("SMS skipped (cooldown).");
    return false;
  }

  sim900a.print("AT+CMGS=\"");
  sim900a.print(RECIPIENT_NUMBER);
  sim900a.println("\"");
  delay(1000);
  sim900a.print(text);
  delay(200);
  sim900a.write(26); // Ctrl+Z

  String resp = "";
  unsigned long start = millis();
  while (millis() - start < 15000) {
    while (sim900a.available()) resp += (char)sim900a.read();
    if (resp.indexOf("+CMGS:") != -1) {
      lastSmsTime = millis();
      Serial.println("SMS sent.");
      return true;
    }
    if (resp.indexOf("ERROR") != -1) break;
  }
  Serial.println("SMS failed: " + resp);
  return false;
}

// ---------------------------------------------------------------
// LoRa helpers
// ---------------------------------------------------------------
bool initLoRa() {
  customSPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);
  LoRa.setSPI(customSPI);
  LoRa.setPins(SS_PIN, RST_PIN, DIO0_PIN);
  if (!LoRa.begin(LORA_FREQ)) return false;
  LoRa.receive(); // stay in RX mode by default
  return true;
}

bool sendLoRa(const String& payload) {
  if (!loraReady) return false;
    if (payload.length() > 250) {
      Serial.println("LoRa packet too large. Not sending.");
      return false;
    }

    LoRa.beginPacket();
    LoRa.print(payload);
    bool ok = LoRa.endPacket();

    LoRa.receive();

    return ok;
  }

// ---------------------------------------------------------------
// Wi-Fi / Supabase
// ---------------------------------------------------------------
void connectWiFi(unsigned long timeoutMs = 15000) {
  WiFi.begin(ssid, password);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(WiFi.status() == WL_CONNECTED ? "\nWi-Fi connected." : "\nWi-Fi not available.");
}

bool sendToSupabase(const String& jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    return false;
  }

  HTTPClient http;
  http.begin(supabase_url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", String("Bearer ") + supabase_key);
  http.addHeader("Prefer", "return=minimal");

  int code = http.POST(jsonPayload);
  http.end();

  Serial.print("Supabase HTTP code: ");
  Serial.println(code);
  return code >= 200 && code < 300; // 201 = created
}

// ---------------------------------------------------------------
// Alert detection -- ADJUST to match your Pico's JSON
// ---------------------------------------------------------------
bool isHighRisk(const String& payload) {
  return payload.indexOf("Warning") != -1 || payload.indexOf("Evacuate") != -1;
}

// ---------------------------------------------------------------
// Setup / loop
// ---------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial1.begin(9600, SERIAL_8N1, RXpico, TXpico);   // Pico
  sim900a.begin(9600, SERIAL_8N1, RXD2, TXD2);       // GSM

  Serial.print("Connecting to Wi-Fi");
  connectWiFi();

  loraReady = initLoRa();
  Serial.println(loraReady ? "LoRa ready." : "LoRa init FAILED.");

  Serial.println("Initialising GSM (can take ~30 s)...");
  delay(5000); // short boot wait; increase to 20000 if AT check fails
  gsmReady = initGSM();
  Serial.println(gsmReady ? "GSM ready." : "GSM init FAILED.");

  Serial.println("ESP32 ready. Listening for Pico data...");
}

void loop() {
  // 1) Data from the Pico
  if (Serial1.available()) {
    String data = Serial1.readStringUntil('\n');
    data.trim();

    if (data.length() > 0) {
      Serial.println("Data from Pico: " + data);

      bool delivered = sendToSupabase(data);      // primary: Wi-Fi -> cloud
      if (!delivered) {
        delivered = sendLoRa(data);               // fallback: LoRa
      }
      if (!delivered) Serial.println("No uplink available for this reading.");

      if (isHighRisk(data)) {
        sendSMS("SIAGA ALERT: " + data.substring(0, 120));
      }
    }
  }

  // 2) Packets from other nodes -> forward to cloud if we have Wi-Fi
  if (loraReady) {
    int packetSize = LoRa.parsePacket();
    if (packetSize) {
      String rx = "";
      while (LoRa.available()) rx += (char)LoRa.read();
      Serial.println("LoRa RX (RSSI " + String(LoRa.packetRssi()) + "): " + rx);
      bool delivered = sendToSupabase(rx);

      if (!delivered) {
        Serial.println("LoRa data could not be uploaded to Supabase.");
      }

      if (isHighRisk(rx)) {
        sendSMS("SIAGA ALERT (via LoRa): " + rx.substring(0, 110));
      }
    }
  }

  // 3) Occasional Wi-Fi recovery
  static unsigned long lastWifiTry = 0;
  if (WiFi.status() != WL_CONNECTED && millis() - lastWifiTry > 30000) {
    lastWifiTry = millis();
    WiFi.reconnect();
  }
}