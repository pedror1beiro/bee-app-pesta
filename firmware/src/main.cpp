#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>
#include <DHT.h>
#include <SPI.h>
#include <SD.h>

#define DHTPIN        4
#define DHTTYPE       DHT22
#define SD_CS         5
#define PIN_SENSORES  15

RTC_DS3231 rtc;
DHT dht(DHTPIN, DHTTYPE);

#define SLEEP_SEGUNDOS 10
#define uS_TO_S_FACTOR 1000000ULL

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("=== ESP32 Acordou ===");

  pinMode(PIN_SENSORES, OUTPUT);
  digitalWrite(PIN_SENSORES, HIGH);
  delay(100);

  // ─── RTC ──────────────────────────────────────────────────
  Wire.begin(21, 22);
  if (!rtc.begin()) {
    Serial.println("[ERRO] RTC nao encontrado!");
  } else {
    if (rtc.lostPower()) {
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
      Serial.println("[RTC] Hora actualizada para hora de compilacao");
    }
    DateTime now = rtc.now();
    Serial.print("[RTC] ");
    Serial.print(now.year());   Serial.print("/");
    Serial.print(now.month());  Serial.print("/");
    Serial.print(now.day());    Serial.print(" ");
    Serial.print(now.hour());   Serial.print(":");
    Serial.print(now.minute()); Serial.print(":");
    Serial.print(now.second()); Serial.println();
  }

  // ─── DHT22 ────────────────────────────────────────────────
  dht.begin();
  delay(2000);
  float temperatura = dht.readTemperature();
  float humidade    = dht.readHumidity();

  if (isnan(temperatura) || isnan(humidade)) {
    Serial.println("[ERRO] DHT22 falhou!");
  } else {
    Serial.print("[DHT22] Temp: ");
    Serial.print(temperatura);
    Serial.print(" C  |  Hum: ");
    Serial.print(humidade);
    Serial.println(" %");
  }

  // ─── MicroSD ──────────────────────────────────────────────
  DateTime now = rtc.now();
  if (!SD.begin(SD_CS)) {
    Serial.println("[ERRO] MicroSD nao encontrado!");
  } else {
    Serial.println("[SD] MicroSD inicializado.");

    String nomeFicheiro = "/dados.csv";

    if (!SD.exists(nomeFicheiro)) {
      File f = SD.open(nomeFicheiro, FILE_WRITE);
      if (f) {
        f.println("timestamp,temperatura,humidade,peso,entradas,saidas,bateria");
        f.close();
        Serial.println("[SD] Cabecalho CSV criado.");
      }
    }

    File f = SD.open(nomeFicheiro, FILE_APPEND);
    if (f) {
      char timestamp[20];
      sprintf(timestamp, "%04d-%02d-%02dT%02d:%02d:%02d",
              now.year(), now.month(), now.day(),
              now.hour(), now.minute(), now.second());
      f.print(timestamp);
      f.print(",");
      f.print(temperatura);
      f.print(",");
      f.print(humidade);
      f.print(",0.00,0,0,0.00");
      f.println();
      f.close();
      Serial.println("[SD] Linha escrita no CSV.");
    } else {
      Serial.println("[ERRO] Nao foi possivel abrir o ficheiro!");
    }
  }

  // ─── Desliga sensores e vai dormir ────────────────────────
  digitalWrite(PIN_SENSORES, LOW);
  Serial.print("[SLEEP] A dormir ");
  Serial.print(SLEEP_SEGUNDOS);
  Serial.println(" segundos...");
  Serial.flush();

  esp_sleep_enable_timer_wakeup(SLEEP_SEGUNDOS * uS_TO_S_FACTOR);
  esp_deep_sleep_start();
}

void loop() {
  // Nunca chega aqui
}