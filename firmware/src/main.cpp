#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>
#include <DHT.h>
#include <SPI.h>
#include <SD.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include <NimBLEDevice.h>
#include "credentials.h"

// ─── Pinos ────────────────────────────────────────────────────
#define DHTPIN        4
#define DHTTYPE       DHT22
#define SD_CS         5
#define PIN_SENSORES  15

// ─── WiFi / NTP ───────────────────────────────────────────────
#define WIFI_TIMEOUT_MS  15000
#define NTP_TIMEOUT_MS    5000
// Portugal: UTC+0 (WET) + 1h DST verão (WEST)
#define TZ_GMT_OFFSET    0
#define TZ_DST_OFFSET    3600

// ─── API ──────────────────────────────────────────────────────
#define API_URL  "https://bee-app-pesta.up.railway.app/api/leitura"

// ─── Deep Sleep ───────────────────────────────────────────────
#define SLEEP_SEGUNDOS  600
#define uS_TO_S_FACTOR  1000000ULL

// ─── BLE GATT ─────────────────────────────────────────────────
#define BLE_DEVICE_NAME  "Colmeia_Smart"
#define BLE_SVC_UUID     "12345678-1234-1234-1234-123456789abc"
#define BLE_CHAR_DATA    "12345678-1234-1234-1234-123456789abd"
#define BLE_CHAR_CMD     "12345678-1234-1234-1234-123456789abe"
#define BLE_WAIT_MS      30000   // 30s à espera de ligação

// ─── Globais ──────────────────────────────────────────────────
RTC_DS3231 rtc;
DHT dht(DHTPIN, DHTTYPE);

NimBLECharacteristic* pDataChar   = nullptr;
volatile bool         bleSyncReq  = false;
volatile bool         bleDone     = false;

// ─── Callbacks BLE ────────────────────────────────────────────

class CmdCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pChar) override {
        std::string v = pChar->getValue();
        if (v == "SYNC") bleSyncReq = true;
        else if (v == "END") bleDone = true;
    }
};

class SrvCallbacks : public NimBLEServerCallbacks {
    void onDisconnect(NimBLEServer* pServer) override {
        bleDone = true;
        Serial.println("[BLE] Cliente desligado.");
    }
};

// ─── Servidor GATT ────────────────────────────────────────────

void runBleServer(const char* csvPath) {
    bleSyncReq = false;
    bleDone    = false;

    NimBLEDevice::init(BLE_DEVICE_NAME);
    NimBLEDevice::setMTU(512);

    NimBLEServer* pSrv = NimBLEDevice::createServer();
    pSrv->setCallbacks(new SrvCallbacks());

    NimBLEService* pSvc = pSrv->createService(BLE_SVC_UUID);

    pDataChar = pSvc->createCharacteristic(
        BLE_CHAR_DATA,
        NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ
    );

    NimBLECharacteristic* pCmdChar = pSvc->createCharacteristic(
        BLE_CHAR_CMD,
        NIMBLE_PROPERTY::WRITE
    );
    pCmdChar->setCallbacks(new CmdCallbacks());

    pSvc->start();

    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID(BLE_SVC_UUID);
    pAdv->start();

    Serial.println("[BLE] A anunciar 'Colmeia_Smart'...");

    unsigned long t0 = millis();

    while (!bleDone && (millis() - t0 < BLE_WAIT_MS)) {
        if (bleSyncReq) {
            bleSyncReq = false;
            Serial.println("[BLE] SYNC recebido. A enviar CSV...");

            File f = SD.open(csvPath);
            if (f) {
                int n = 0;
                while (f.available()) {
                    String line = f.readStringUntil('\n');
                    line.trim();
                    if (line.length() == 0) continue;
                    pDataChar->setValue(line.c_str());
                    pDataChar->notify();
                    n++;
                    delay(20);   // evita saturar o buffer BLE
                }
                f.close();
                Serial.printf("[BLE] %d linhas enviadas.\n", n);
            } else {
                Serial.println("[BLE] Erro ao abrir CSV.");
            }

            // Marcador de fim
            pDataChar->setValue("END");
            pDataChar->notify();
            delay(500);
            bleDone = true;
        }
        delay(50);
    }

    if (!bleDone) Serial.println("[BLE] Timeout — sem ligação BLE.");
    else          Serial.println("[BLE] Sincronização concluída.");

    NimBLEDevice::stopAdvertising();
    NimBLEDevice::deinit(true);
    pDataChar = nullptr;
}

// ─── Setup ────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("=== ESP32 Acordou ===");

    // WiFi inicia cedo para ligar em paralelo com os sensores
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    String mac = WiFi.macAddress();
    Serial.print("[WiFi] MAC: ");
    Serial.println(mac);

    // ─── Liga alimentação dos sensores ─────────────────────────
    pinMode(PIN_SENSORES, OUTPUT);
    digitalWrite(PIN_SENSORES, HIGH);
    delay(100);

    // ─── RTC ───────────────────────────────────────────────────
    Wire.begin(21, 22);
    bool rtcOk = rtc.begin();
    if (!rtcOk) Serial.println("[ERRO] RTC não encontrado!");

    // ─── DHT22 (2s warmup — WiFi liga em paralelo) ─────────────
    dht.begin();
    delay(2000);
    float temperatura = dht.readTemperature();
    float humidade    = dht.readHumidity();

    if (isnan(temperatura) || isnan(humidade)) {
        Serial.println("[ERRO] DHT22 falhou!");
        temperatura = 0.0f;
        humidade    = 0.0f;
    } else {
        Serial.printf("[DHT22] Temp: %.1f C  |  Hum: %.1f %%\n", temperatura, humidade);
    }

    // ─── Aguarda WiFi ──────────────────────────────────────────
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < WIFI_TIMEOUT_MS) {
        delay(500);
    }
    bool wifiOk = (WiFi.status() == WL_CONNECTED);

    // ─── NTP → actualiza RTC ───────────────────────────────────
    if (wifiOk && rtcOk) {
        configTime(TZ_GMT_OFFSET, TZ_DST_OFFSET, "pool.ntp.org", "time.google.com");
        struct tm timeinfo;
        if (getLocalTime(&timeinfo, NTP_TIMEOUT_MS)) {
            rtc.adjust(DateTime(
                timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
                timeinfo.tm_hour,        timeinfo.tm_min,      timeinfo.tm_sec
            ));
            Serial.println("[NTP] RTC sincronizado.");
        } else {
            Serial.println("[NTP] Timeout — a usar hora do RTC.");
        }
    } else if (rtcOk && rtc.lostPower()) {
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
        Serial.println("[RTC] Sem NTP — a usar hora de compilação.");
    }

    // ─── Lê RTC ───────────────────────────────────────────────
    DateTime now(2000, 1, 1, 0, 0, 0);
    if (rtcOk) {
        now = rtc.now();
        Serial.printf("[RTC] %04d/%02d/%02d %02d:%02d:%02d\n",
            now.year(), now.month(), now.day(),
            now.hour(), now.minute(), now.second());
    }

    // ─── MicroSD ───────────────────────────────────────────────
    const char* csvPath = "/dados.csv";
    bool sdOk = SD.begin(SD_CS);

    if (!sdOk) {
        Serial.println("[ERRO] MicroSD não encontrado!");
    } else {
        Serial.println("[SD] MicroSD inicializado.");

        if (!SD.exists(csvPath)) {
            File f = SD.open(csvPath, FILE_WRITE);
            if (f) {
                f.println("timestamp,temperatura,humidade,peso,entradas,saidas,bateria");
                f.close();
                Serial.println("[SD] Cabeçalho CSV criado.");
            }
        }

        File f = SD.open(csvPath, FILE_APPEND);
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
            Serial.println("[ERRO] Não foi possível abrir o ficheiro CSV!");
        }
    }

    // ─── HTTP POST ─────────────────────────────────────────────
    if (wifiOk) {
        Serial.println("[WiFi] Ligado.");

        WiFiClientSecure client;
        client.setInsecure();

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

    // ─── Desliga WiFi antes do BLE ─────────────────────────────
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);

    // ─── Servidor BLE GATT (30s para sync via app) ─────────────
    // O utilizador pode ligar a app e fazer sync dos dados do SD
    if (sdOk) {
        runBleServer(csvPath);
    }

    // ─── Desliga sensores e dorme ──────────────────────────────
    digitalWrite(PIN_SENSORES, LOW);
    Serial.printf("[SLEEP] A dormir %d segundos...\n", SLEEP_SEGUNDOS);
    Serial.flush();

    esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_SEGUNDOS * uS_TO_S_FACTOR);
    esp_deep_sleep_start();
}

void loop() {
    // Nunca chega aqui — o ESP32 reinicia após Deep Sleep
}
