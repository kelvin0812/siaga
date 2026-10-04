#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>

Adafruit_MPU6050 mpu;

// Pin Definitions matching image_d8465e.png
const int uartTxPin = 0;   // GP0 TX
const int uartRxPin = 1;   // GP1 RX
const int trigPin = 2;     // GP2
const int echoPin = 3;     // GP3
const int flowPin = 6;     // GP6
const int relay1 = 10;     // GP10
const int relay2 = 11;     // GP11
const int relay3 = 12;     // GP12
const int soilPin = 26;    // GP26 ADC0

volatile int flowPulses = 0;

void countPulse() {
  flowPulses++;
}

void setup() {
  Serial.begin(115200); 
  
  // The Mbed core defaults to GP0 (TX) and GP1 (RX), so we just start it
  Serial1.begin(9600);

  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(soilPin, INPUT);
  
  pinMode(flowPin, INPUT);
  attachInterrupt(digitalPinToInterrupt(flowPin), countPulse, RISING);

  pinMode(relay1, OUTPUT);
  pinMode(relay2, OUTPUT);
  pinMode(relay3, OUTPUT);

  // The Mbed core defaults to GP4 (SDA) and GP5 (SCL), so we just start it
  Wire.begin();
  
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
  }
}

void loop() {
  int soilMoisture = analogRead(soilPin);

  // JSN-SR04T Ultrasonic sensor reading
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH);
  float distance_cm = duration * 0.034 / 2;

  // Flow sensor reading
  int currentPulses = flowPulses;
  flowPulses = 0; 

  // MPU6050 reading
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // Construct JSON payload
  String payload = "{";
  payload += "\"soil\":" + String(soilMoisture) + ",";
  payload += "\"dist\":" + String(distance_cm) + ",";
  payload += "\"flow\":" + String(currentPulses) + ",";
  
  // Accelerometer (m/s^2) and Gyroscope (rad/s) values
  payload += "\"accel_x\":" + String(a.acceleration.x) + ",";
  payload += "\"accel_y\":" + String(a.acceleration.y) + ",";
  payload += "\"accel_z\":" + String(a.acceleration.z) + ",";
  payload += "\"gyro_x\":" + String(g.gyro.x) + ",";
  payload += "\"gyro_y\":" + String(g.gyro.y) + ",";
  payload += "\"gyro_z\":" + String(g.gyro.z);
  payload += "}";

  Serial1.println(payload); 
  Serial.println(payload);  

  delay(1000); 
}