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

// ─── Pinos ────────────────────────────────────────────────────────────────────
#define DHTPIN         4
#define DHTTYPE        DHT22
#define SD_CS          5
#define PIN_SENSORES   15
#define HX711_DT       34
#define HX711_SCK      32
#define IR_A_PIN       25
#define IR_B_PIN       26

// ─── Constantes ───────────────────────────────────────────────────────────────
#define WIFI_TIMEOUT_MS    15000
#define NTP_TIMEOUT_MS      5000
#define TZ_GMT_OFFSET          0
#define TZ_DST_OFFSET       3600
#define API_URL   "https://bee-app-pesta.up.railway.app/api/leitura"
#define MODO_URL  "https://bee-app-pesta.up.railway.app/api/colmeia/modo/"
#define SLEEP_SECS            60
#define uS_TO_S        1000000ULL
#define REPORT_MS        60000UL
#define CAL_FACTOR     94803.35f
#define HX711_SAMPLES       10
#define IR_WINDOW_MS       300UL
#define BLE_WAIT_MS        20000

// ─── Objectos ─────────────────────────────────────────────────────────────────
RTC_DS3231 rtc;
DHT        dht(DHTPIN, DHTTYPE);
HX711_ADC  scale(HX711_DT, HX711_SCK);

// ─── Estado global ────────────────────────────────────────────────────────────
static String g_mac;
static bool   g_rtcOk    = false;
static bool   g_sdOk     = false;
static bool   g_isPremium = false;

// ─── Contadores IR ────────────────────────────────────────────────────────────
volatile unsigned long irATime   = 0;
volatile unsigned long irBTime   = 0;
volatile int           g_entradas = 0;
volatile int           g_saidas   = 0;

void IRAM_ATTR onIrA() {
    unsigned long now = millis();
    if (irBTime > 0 && (now - irBTime) < IR_WINDOW_MS) {
        g_entradas++;
        irBTime = 0; irATime = 0;
    } else {
        irATime = now;
    }
}

void IRAM_ATTR onIrB() {
    unsigned long now = millis();
    if (irATime > 0 && (now - irATime) < IR_WINDOW_MS) {
        g_saidas++;
        irATime = 0; irBTime = 0;
    } else {
        irBTime = now;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLE GATT SERVER
// ═══════════════════════════════════════════════════════════════════════════════

NimBLECharacteristic* pDataChar  = nullptr;
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
    bleTareReq = false;

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
    Serial.println("[BLE] A anunciar...");

    unsigned long t0 = millis();
    while (!bleDone && (millis() - t0 < BLE_WAIT_MS)) {
        if (bleSyncReq) {
            bleSyncReq = false;
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
            }
            pDataChar->setValue("END");
            pDataChar->notify();
            delay(500);
            bleDone = true;
        }
        if (bleTareReq) {
            bleTareReq = false;
            scale.tare();
            float offset = scale.getTareOffset();
            Preferences prefs;
            prefs.begin("hx711", false);
            prefs.putFloat("tare", offset);
            prefs.end();
            Serial.printf("[HX711] Nova tara: %.1f\n", offset);
            pDataChar->setValue("TARE_OK");
            pDataChar->notify();
        }
        delay(50);
    }

    if (!bleDone) Serial.println("[BLE] Timeout.");
    NimBLEDevice::stopAdvertising();
    delay(200);
    NimBLEDevice::deinit(false);
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
        if (scale.update()) { sum += scale.getData(); got++; delay(50); }
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
    if (!f) { Serial.println("[SD] Erro."); return; }
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

// Consulta o modo na API; em caso de falha usa o valor guardado em NVS
bool fetchModo() {
    Preferences prefs;
    if (WiFi.status() != WL_CONNECTED) {
        prefs.begin("modo", false);
        bool cached = prefs.getBool("premium", false);
        prefs.end();
        Serial.printf("[MODO] Sem WiFi — NVS: %s\n", cached ? "PREMIUM" : "BASE");
        return cached;
    }

    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = String(MODO_URL) + g_mac;
    http.begin(client, url);
    http.addHeader("x-api-key", API_KEY);
    int code = http.GET();
    bool isPremium = false;

    if (code == 200) {
        String body = http.getString();
        isPremium = body.indexOf("premium") >= 0;
        prefs.begin("modo", false);
        prefs.putBool("premium", isPremium);
        prefs.end();
        Serial.printf("[MODO] API → %s\n", isPremium ? "PREMIUM" : "BASE");
    } else {
        prefs.begin("modo", false);
        isPremium = prefs.getBool("premium", false);
        prefs.end();
        Serial.printf("[MODO] HTTP %d — NVS: %s\n", code, isPremium ? "PREMIUM" : "BASE");
    }
    http.end();
    return isPremium;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELATÓRIO (partilhado entre modos)
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

    pinMode(PIN_SENSORES, OUTPUT);
    digitalWrite(PIN_SENSORES, HIGH);
    delay(100);

    Wire.begin(21, 22);
    g_rtcOk = rtc.begin();
    if (!g_rtcOk) Serial.println("[ERRO] RTC não encontrado!");
    else if (rtc.lostPower()) rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

    dht.begin();
    scale.begin();
    scale.start(2000, false);
    scale.setCalFactor(CAL_FACTOR);

    {
        Preferences prefs;
        prefs.begin("hx711", true);
        float savedTare = prefs.getFloat("tare", 0.0f);
        prefs.end();
        if (savedTare != 0.0f) {
            scale.setTareOffset(savedTare);
            Serial.printf("[HX711] Tara NVS: %.1f\n", savedTare);
        } else {
            scale.tare();
            float offset = scale.getTareOffset();
            Preferences pw;
            pw.begin("hx711", false);
            pw.putFloat("tare", offset);
            pw.end();
            Serial.printf("[HX711] Tara inicial: %.1f\n", offset);
        }
    }

    g_sdOk = SD.begin(SD_CS);
    Serial.println(g_sdOk ? "[SD] OK" : "[ERRO] MicroSD não encontrado!");

    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < WIFI_TIMEOUT_MS) delay(500);

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[WiFi] Ligado.");
        syncNtp();
    }

    // Consulta o modo (BASE ou PREMIUM) na API
    g_isPremium = fetchModo();

    if (g_isPremium) {
        pinMode(IR_A_PIN, INPUT_PULLUP);
        pinMode(IR_B_PIN, INPUT_PULLUP);
        attachInterrupt(digitalPinToInterrupt(IR_A_PIN), onIrA, FALLING);
        attachInterrupt(digitalPinToInterrupt(IR_B_PIN), onIrB, FALLING);
        Serial.println("[IR] Interrupções activas (PREMIUM).");
        doReport(0, 0);
        WiFi.mode(WIFI_STA);
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    } else {
        doReport(0, 0);
        digitalWrite(PIN_SENSORES, LOW);
        Serial.printf("[SLEEP] A dormir %d s...\n", SLEEP_SECS);
        Serial.flush();
        esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_SECS * uS_TO_S);
        esp_deep_sleep_start();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP (apenas PREMIUM — BASE nunca chega aqui)
// ═══════════════════════════════════════════════════════════════════════════════

static unsigned long g_lastReport = 0;

void loop() {
    if (!g_isPremium) { delay(1000); return; }

    scale.update();

    if (millis() - g_lastReport >= REPORT_MS) {
        g_lastReport = millis();

        noInterrupts();
        int ent = g_entradas;
        int sai = g_saidas;
        g_entradas = 0;
        g_saidas   = 0;
        interrupts();

        Serial.printf("[IR] Entradas: %d  Saídas: %d\n", ent, sai);

        unsigned long tw = millis();
        while (WiFi.status() != WL_CONNECTED && millis() - tw < WIFI_TIMEOUT_MS) delay(500);

        doReport(ent, sai);

        WiFi.mode(WIFI_STA);
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

        // Verifica se o modo mudou
        g_isPremium = fetchModo();
        if (!g_isPremium) {
            Serial.println("[MODO] Mudou para BASE — a dormir...");
            detachInterrupt(digitalPinToInterrupt(IR_A_PIN));
            detachInterrupt(digitalPinToInterrupt(IR_B_PIN));
            digitalWrite(PIN_SENSORES, LOW);
            Serial.flush();
            esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_SECS * uS_TO_S);
            esp_deep_sleep_start();
        }
    }
}
