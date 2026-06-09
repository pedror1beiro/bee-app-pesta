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
#include <HX711_ADC.h>
#include <NimBLEDevice.h>
#include <Preferences.h>
#include "credentials.h"

// ─── Modo ─────────────────────────────────────────────────────────────────────
// Comentado = BASE  (deep sleep 10 min, sem contagem IR)
// Descomentado = PREMIUM (sempre activo, contagem IR por interrupção)
// #define PREMIUM_MODE

// ─── Pinos ────────────────────────────────────────────────────────────────────
#define DHTPIN         4
#define DHTTYPE        DHT22
#define SD_CS          5
#define PIN_SENSORES   15
#define HX711_DT       34       // input-only — OK para dados
#define HX711_SCK      32
#define IR_A_PIN       25       // Sensor A DOUT
#define IR_B_PIN       26       // Sensor B DOUT

// ─── Constantes ───────────────────────────────────────────────────────────────
#define WIFI_TIMEOUT_MS    15000
#define NTP_TIMEOUT_MS      5000
#define TZ_GMT_OFFSET          0
#define TZ_DST_OFFSET       3600
#define API_URL   "https://bee-app-pesta.up.railway.app/api/leitura"
#define SLEEP_SECS            60
#define uS_TO_S        1000000ULL
#define REPORT_MS        60000UL   // Premium: 1 min em milissegundos
#define CAL_FACTOR     94803.35f
#define HX711_SAMPLES       10
#define IR_WINDOW_MS       300UL
#ifdef PREMIUM_MODE
#  define BLE_WAIT_MS    10000
#else
#  define BLE_WAIT_MS    30000
#endif

// ─── Objectos ─────────────────────────────────────────────────────────────────
RTC_DS3231 rtc;
DHT        dht(DHTPIN, DHTTYPE);
HX711_ADC  scale(HX711_DT, HX711_SCK);

// ─── Estado global ────────────────────────────────────────────────────────────
static String g_mac;
static bool   g_rtcOk = false;
static bool   g_sdOk  = false;

// ─── Contadores IR (apenas Premium) ──────────────────────────────────────────
#ifdef PREMIUM_MODE
volatile unsigned long irATime = 0;
volatile unsigned long irBTime = 0;
volatile int g_entradas = 0;
volatile int g_saidas   = 0;

void IRAM_ATTR onIrA() {
    unsigned long now = millis();
    if (irBTime > 0 && (now - irBTime) < IR_WINDOW_MS) {
        g_entradas++;   // B antes de A → ENTRADA
        irBTime = 0; irATime = 0;
    } else {
        irATime = now;
    }
}

void IRAM_ATTR onIrB() {
    unsigned long now = millis();
    if (irATime > 0 && (now - irATime) < IR_WINDOW_MS) {
        g_saidas++;     // A antes de B → SAÍDA
        irATime = 0; irBTime = 0;
    } else {
        irBTime = now;
    }
}
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// BLE GATT SERVER
// ═══════════════════════════════════════════════════════════════════════════════

NimBLECharacteristic* pDataChar = nullptr;
volatile bool bleSyncReq = false;
volatile bool bleDone    = false;

volatile bool bleTareReq = false;

class CmdCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pChar) override {
        std::string v = pChar->getValue();
        if (v == "SYNC") bleSyncReq = true;
        else if (v == "END") bleDone = true;
        else if (v == "TARE") bleTareReq = true;
    }
};

class SrvCallbacks : public NimBLEServerCallbacks {
    void onDisconnect(NimBLEServer* pServer) override {
        bleDone = true;
        Serial.println("[BLE] Cliente desligado.");
    }
};

void runBleServer(const char* csvPath) {
    bleSyncReq = false;
    bleDone    = false;

    NimBLEDevice::init(BLE_DEVICE_NAME);
    NimBLEDevice::setMTU(512);

    NimBLEServer*  pSrv = NimBLEDevice::createServer();
    pSrv->setCallbacks(new SrvCallbacks());
    NimBLEService* pSvc = pSrv->createService("12345678-1234-1234-1234-123456789abc");

    pDataChar = pSvc->createCharacteristic(
        "12345678-1234-1234-1234-123456789abd",
        NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ);

    NimBLECharacteristic* pCmd = pSvc->createCharacteristic(
        "12345678-1234-1234-1234-123456789abe",
        NIMBLE_PROPERTY::WRITE);
    pCmd->setCallbacks(new CmdCallbacks());

    pSvc->start();
    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID("12345678-1234-1234-1234-123456789abc");
    pAdv->start();
    Serial.println("[BLE] A anunciar 'Colmeia_Smart'...");

    unsigned long t0 = millis();
    while (!bleDone && (millis() - t0 < BLE_WAIT_MS)) {
        if (bleSyncReq) {
            bleSyncReq = false;
            Serial.println("[BLE] SYNC recebido.");
            File f = SD.open(csvPath);
            if (f) {
                int n = 0;
                while (f.available()) {
                    String line = f.readStringUntil('\n');
                    line.trim();
                    if (!line.length()) continue;
                    pDataChar->setValue(line.c_str());
                    pDataChar->notify();
                    n++;
                    delay(20);
                }
                f.close();
                Serial.printf("[BLE] %d linhas enviadas.\n", n);
            } else {
                Serial.println("[BLE] Erro ao abrir CSV.");
            }
            pDataChar->setValue("END");
            pDataChar->notify();
            delay(500);
            bleDone = true;
        }
        if (bleTareReq) {
            bleTareReq = false;
            Serial.println("[BLE] TARE recebido — a tarar...");
            scale.tare();
            float offset = scale.getTareOffset();
            Preferences prefs;
            prefs.begin("hx711", false);
            prefs.putFloat("tare", offset);
            prefs.end();
            Serial.printf("[HX711] Nova tara guardada: %.1f\n", offset);
            pDataChar->setValue("TARE_OK");
            pDataChar->notify();
        }
        delay(50);
    }

    if (!bleDone) Serial.println("[BLE] Timeout sem ligação.");
    NimBLEDevice::stopAdvertising();
    NimBLEDevice::deinit(true);
    pDataChar = nullptr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

float readWeight() {
    float sum = 0;
    int   got = 0;
    unsigned long t = millis();
    while (got < HX711_SAMPLES && millis() - t < 5000) {
        if (scale.update()) {
            sum += scale.getData();
            got++;
            delay(50);
        }
    }
    if (!got) { Serial.println("[HX711] Sem leituras."); return 0.0f; }
    float w = sum / got;
    Serial.printf("[HX711] %.3f kg (%d amostras)\n", w, got);
    return w;
}

void writeCSV(const char* path, const DateTime& ts,
              float temp, float hum, float peso, int ent, int sai) {
    if (!g_sdOk) return;
    if (!SD.exists(path)) {
        File f = SD.open(path, FILE_WRITE);
        if (f) { f.println("timestamp,temperatura,humidade,peso,entradas,saidas,bateria"); f.close(); }
    }
    File f = SD.open(path, FILE_APPEND);
    if (!f) { Serial.println("[SD] Erro ao abrir ficheiro."); return; }
    char linha[96];
    snprintf(linha, sizeof(linha),
        "%04d-%02d-%02dT%02d:%02d:%02d,%.2f,%.2f,%.3f,%d,%d,0.00",
        ts.year(), ts.month(), ts.day(),
        ts.hour(), ts.minute(), ts.second(),
        temp, hum, peso, ent, sai);
    f.println(linha);
    f.close();
    Serial.printf("[SD] %s\n", linha);
}

void httpPost(float temp, float hum, float peso, int ent, int sai) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    http.begin(client, API_URL);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("x-api-key", API_KEY);
    char body[300];
    snprintf(body, sizeof(body),
        "{\"mac_address\":\"%s\","
        "\"temperatura\":%.2f,\"humidade\":%.2f,"
        "\"peso\":%.3f,"
        "\"entradas_abelhas\":%d,\"saidas_abelhas\":%d,"
        "\"nivel_bateria\":0.00}",
        g_mac.c_str(), temp, hum, peso, ent, sai);
    int code = http.POST(body);
    Serial.printf("[HTTP] %d\n", code);
    if (code != 201) Serial.println("[HTTP] " + http.getString());
    http.end();
}

void syncNtp() {
    configTime(TZ_GMT_OFFSET, TZ_DST_OFFSET, "pool.ntp.org", "time.google.com");
    struct tm ti;
    if (g_rtcOk && getLocalTime(&ti, NTP_TIMEOUT_MS)) {
        rtc.adjust(DateTime(ti.tm_year + 1900, ti.tm_mon + 1, ti.tm_mday,
                            ti.tm_hour, ti.tm_min, ti.tm_sec));
        Serial.println("[NTP] RTC sincronizado.");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEITURA + RELATÓRIO (reutilizado em ambos os modos)
// ═══════════════════════════════════════════════════════════════════════════════

void doReport(int entradas, int saidas) {
    float temperatura = dht.readTemperature();
    float humidade    = dht.readHumidity();
    if (isnan(temperatura)) temperatura = 0.0f;
    if (isnan(humidade))    humidade    = 0.0f;
    Serial.printf("[DHT22] %.1f°C  %.1f%%\n", temperatura, humidade);

    float peso = readWeight();

    DateTime now(2000, 1, 1, 0, 0, 0);
    if (g_rtcOk) {
        now = rtc.now();
        Serial.printf("[RTC] %04d/%02d/%02d %02d:%02d:%02d\n",
            now.year(), now.month(), now.day(),
            now.hour(), now.minute(), now.second());
    }

    writeCSV("/dados.csv", now, temperatura, humidade, peso, entradas, saidas);

    if (WiFi.status() == WL_CONNECTED) {
        httpPost(temperatura, humidade, peso, entradas, saidas);
    } else {
        Serial.println("[WiFi] Sem ligação — só SD.");
    }

    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    if (g_sdOk) runBleServer("/dados.csv");
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("=== ESP32 Acordou ===");

    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    g_mac = WiFi.macAddress();
    Serial.print("[WiFi] MAC: "); Serial.println(g_mac);

    // ── Alimentação dos sensores ──────────────────────────────
    pinMode(PIN_SENSORES, OUTPUT);
    digitalWrite(PIN_SENSORES, HIGH);
    delay(100);

    // ── RTC ──────────────────────────────────────────────────
    Wire.begin(21, 22);
    g_rtcOk = rtc.begin();
    if (!g_rtcOk) Serial.println("[ERRO] RTC não encontrado!");
    else if (rtc.lostPower()) rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

    // ── DHT22 + HX711 (2 s warmup partilhado) ────────────────
    dht.begin();
    scale.begin();
    scale.start(2000, false);       // sem auto-tara — usa tara guardada em NVS
    scale.setCalFactor(CAL_FACTOR);

    Preferences prefs;
    prefs.begin("hx711", true);     // read-only
    float savedTare = prefs.getFloat("tare", 0.0f);
    prefs.end();
    if (savedTare != 0.0f) {
        scale.setTareOffset(savedTare);
        Serial.printf("[HX711] Tara NVS: %.1f\n", savedTare);
    } else {
        scale.tare();             // primeira vez: tara e guarda
        float offset = scale.getTareOffset();
        prefs.begin("hx711", false);
        prefs.putFloat("tare", offset);
        prefs.end();
        Serial.printf("[HX711] Tara inicial guardada: %.1f\n", offset);
    }

    // ── MicroSD ───────────────────────────────────────────────
    g_sdOk = SD.begin(SD_CS);
    Serial.println(g_sdOk ? "[SD] OK" : "[ERRO] MicroSD não encontrado!");

    // ── Aguarda WiFi + NTP ────────────────────────────────────
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < WIFI_TIMEOUT_MS) delay(500);

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[WiFi] Ligado.");
        syncNtp();
    }

#ifdef PREMIUM_MODE
    // ── Modo Premium: interrupções IR + loop activo ──────────
    pinMode(IR_A_PIN, INPUT_PULLUP);
    pinMode(IR_B_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(IR_A_PIN), onIrA, FALLING);
    attachInterrupt(digitalPinToInterrupt(IR_B_PIN), onIrB, FALLING);
    Serial.println("[IR] Interrupções activas (modo Premium).");

    // Primeiro relatório imediato
    doReport(0, 0);

    // Reconecta WiFi para o loop
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
#else
    // ── Modo Base: lê, escreve, dorme ────────────────────────
    doReport(0, 0);     // contadores IR = 0 (ESP32 estava a dormir)

    digitalWrite(PIN_SENSORES, LOW);
    Serial.printf("[SLEEP] A dormir %d s...\n", SLEEP_SECS);
    Serial.flush();
    esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_SECS * uS_TO_S);
    esp_deep_sleep_start();
#endif
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP (apenas no modo Premium)
// ═══════════════════════════════════════════════════════════════════════════════

#ifdef PREMIUM_MODE
static unsigned long g_lastReport = 0;

void loop() {
    scale.update();   // mantém buffer HX711 actualizado

    if (millis() - g_lastReport >= REPORT_MS) {
        g_lastReport = millis();

        // Captura atómica dos contadores IR
        noInterrupts();
        int ent = g_entradas;
        int sai = g_saidas;
        g_entradas = 0;
        g_saidas   = 0;
        interrupts();

        Serial.printf("[IR] Entradas: %d  Saídas: %d\n", ent, sai);
        doReport(ent, sai);

        // Reconecta WiFi após BLE
        WiFi.mode(WIFI_STA);
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    }
}
#else
void loop() {}
#endif
