# Smart Hive - PoC

Sistema IoT de monitorização remota de colmeias com registo local e transmissão Bluetooth Low Energy (BLE).

## 1. Arquitetura de Hardware
* **Microcontrolador:** ESP32 (NodeMCU)
* **Sensores:** * SHT30 (Temperatura e Humidade)
  * Célula de Carga + Módulo HX711 (Peso)
* **Periféricos:** * RTC DS3231 via I2C (Timestamp)
  * Módulo MicroSD via SPI (Datalogger offline)
* **Alimentação:** 2x Baterias 18650 (Li-ion) + Gestor de Carga TP4056

## 2. Firmware (ESP32)
* **Linguagem:** C++ (Arduino Core)
* **Fluxo de Execução:** 1. Acordar de *Deep Sleep*.
  2. Ler sensores e RTC.
  3. Gravar string (formato CSV) no SD.
  4. Iniciar Servidor BLE e aguardar emparelhamento (timeout de 10s).
  5. Transmitir dados via notificação.
  6. Entrar em *Deep Sleep* (~20 µA).
* **Parâmetros BLE:**
  * `SERVICE_UUID`: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
  * `CHARACTERISTIC_UUID`: beb5483e-36e1-4688-b7f5-ea07361b26a8

## 3. Aplicação Mobile
* **Framework:** Flutter (Dart)
* **Comunicação:** Cliente BLE assíncrono.
* **Interface:** Parsing do payload recebido em tempo real para atualização da Dashboard e estado de diagnóstico do hardware.

## 4. Executar Aplicação Localmente
```bash
# Obter dependências
flutter pub get

# Compilar e executar (Requer Emulador ou Dispositivo Físico configurado)
flutter run