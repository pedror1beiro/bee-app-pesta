#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>
#include <DHT.h>
#include <SPI.h>
#include <SD.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "credentials.h"

// ─── Pinos ────────────────────────────────────────────────────
#define DHTPIN        4
#define DHTTYPE       DHT22
#define SD_CS         5
#define PIN_SENSORES  15

// ─── WiFi ─────────────────────────────────────────────────────
#define WIFI_TIMEOUT_MS 15000

// ─── API ──────────────────────────────────────────────────────
#define API_URL  "https://bee-app-pesta.up.railway.app/api/leitura"

// ─── Deep Sleep ───────────────────────────────────────────────
#define SLEEP_SEGUNDOS  600          // 10 minutos
#define uS_TO_S_FACTOR  1000000ULL

RTC_DS3231 rtc;
DHT dht(DHTPIN, DHTTYPE);

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("=== ESP32 Acordou ===");

    // Inicia WiFi cedo para ligar em paralelo com os sensores
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    String mac = WiFi.macAddress();
    Serial.print("[WiFi] MAC: ");
    Serial.println(mac);

    // ─── Liga alimentação dos sensores ─────────────────────────
    pinMode(PIN_SENSORES, OUTPUT);
    digitalWrite(PIN_SENSORES, HIGH);
    delay(100);

    // ─── RTC ───────────────────────────────────────────────────
    DateTime now(2000, 1, 1, 0, 0, 0);   // fallback se RTC falhar
    Wire.begin(21, 22);
    if (!rtc.begin()) {
        Serial.println("[ERRO] RTC não encontrado!");
    } else {
        if (rtc.lostPower()) {
            rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
            Serial.println("[RTC] Hora actualizada para hora de compilação");
        }
        now = rtc.now();
        Serial.printf("[RTC] %04d/%02d/%02d %02d:%02d:%02d\n",
            now.year(), now.month(), now.day(),
            now.hour(), now.minute(), now.second());
    }

    // ─── DHT22 ─────────────────────────────────────────────────
    dht.begin();
    delay(2000);    // tempo de estabilização do sensor
    float temperatura = dht.readTemperature();
    float humidade    = dht.readHumidity();

    if (isnan(temperatura) || isnan(humidade)) {
        Serial.println("[ERRO] DHT22 falhou!");
        temperatura = 0.0f;
        humidade    = 0.0f;
    } else {
        Serial.printf("[DHT22] Temp: %.1f C  |  Hum: %.1f %%\n", temperatura, humidade);
    }

    // ─── MicroSD ───────────────────────────────────────────────
    if (!SD.begin(SD_CS)) {
        Serial.println("[ERRO] MicroSD não encontrado!");
    } else {
        Serial.println("[SD] MicroSD inicializado.");

        const char* nomeFicheiro = "/dados.csv";

        if (!SD.exists(nomeFicheiro)) {
            File f = SD.open(nomeFicheiro, FILE_WRITE);
            if (f) {
                f.println("timestamp,temperatura,humidade,peso,entradas,saidas,bateria");
                f.close();
                Serial.println("[SD] Cabeçalho CSV criado.");
            }
        }

        File f = SD.open(nomeFicheiro, FILE_APPEND);
        if (f) {
            char linha[80];
            snprintf(linha, sizeof(linha),
                "%04d-%02d-%02dT%02d:%02d:%02d,%.2f,%.2f,0.00,0,0,0.00",
                now.year(), now.month(), now.day(),
                now.hour(), now.minute(), now.second(),
                temperatura, humidade);
            f.println(linha);
            f.close();
            Serial.println("[SD] Linha escrita no CSV.");
        } else {
            Serial.println("[ERRO] Não foi possível abrir o ficheiro!");
        }
    }

    // ─── WiFi + HTTP POST ──────────────────────────────────────
    // O WiFi começou a ligar no início do setup(); normalmente já
    // está pronto aqui porque a leitura do DHT22 demora ~2s.
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < WIFI_TIMEOUT_MS) {
        delay(500);
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[WiFi] Ligado.");

        WiFiClientSecure client;
        client.setInsecure();   // sem verificação de certificado (protótipo)

        HTTPClient http;
        http.begin(client, API_URL);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("x-api-key", API_KEY);

        char body[256];
        snprintf(body, sizeof(body),
            "{\"mac_address\":\"%s\","
            "\"temperatura\":%.2f,"
            "\"humidade\":%.2f,"
            "\"peso\":0.00,"
            "\"entradas_abelhas\":0,"
            "\"saidas_abelhas\":0,"
            "\"nivel_bateria\":0.00}",
            mac.c_str(), temperatura, humidade);

        int httpCode = http.POST(body);
        Serial.printf("[HTTP] Resposta: %d\n", httpCode);
        if (httpCode == 201) {
            Serial.println("[HTTP] Dados enviados com sucesso.");
        } else {
            Serial.println("[HTTP] " + http.getString());
        }
        http.end();
    } else {
        Serial.println("[WiFi] Sem ligação — dados guardados apenas no SD.");
    }

    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);

    // ─── Desliga sensores e vai dormir ─────────────────────────
    digitalWrite(PIN_SENSORES, LOW);
    Serial.printf("[SLEEP] A dormir %d segundos...\n", SLEEP_SEGUNDOS);
    Serial.flush();

    esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_SEGUNDOS * uS_TO_S_FACTOR);
    esp_deep_sleep_start();
}

void loop() {
    // Nunca chega aqui — o ESP32 reinicia após Deep Sleep
}
