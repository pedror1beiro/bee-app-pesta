# 🐝 Colmeia Smart (BeeApp PESTA)

Sistema IoT completo de monitorização remota de colmeias: um nó ESP32 com sensores recolhe
temperatura, humidade, peso e contagem de abelhas, transmite os dados por **WiFi (HTTP)** quando
há rede e por **Bluetooth Low Energy (BLE)** quando não há, e disponibiliza-os numa **API**, num
**dashboard web** e numa **aplicação móvel**.

## Componentes

| Pasta        | Stack                              | Função                                                        |
|--------------|------------------------------------|---------------------------------------------------------------|
| [firmware/](firmware/)   | C++ / PlatformIO (ESP32)           | Recolha de sensores, datalogger em SD, envio WiFi + BLE       |
| [backend/](backend/)     | Node.js / Express 5 / MySQL        | API REST, autenticação, persistência (deploy: Railway)        |
| [frontend/](frontend/)   | React 19 / Vite / Tailwind         | Dashboard web para apicultores e admin (deploy: Vercel)       |
| [mobile/](mobile/)       | Flutter / Dart / Riverpod          | App móvel com dashboard, alertas e sincronização BLE          |
| [database/](database/)   | SQL (MySQL)                        | Schema e dados de teste                                        |

---

## 1. Firmware (ESP32)

* **Microcontrolador:** ESP32 (NodeMCU)
* **Sensores e periféricos:**
  * **DHT22** — temperatura e humidade
  * **Célula de carga + HX711** — peso da colmeia (com tara persistida em NVS)
  * **RTC DS3231** (I2C) — timestamp, sincronizado por NTP quando há WiFi
  * **MicroSD** (SPI) — datalogger offline em CSV (`/dados.csv`)
  * **2× sensores IR** — contagem de entradas/saídas de abelhas (par de barreiras)
* **Bibliotecas:** RTClib, DHT, HX711_ADC, NimBLE-Arduino (ver [platformio.ini](firmware/platformio.ini))

### Modos de operação (controlados pela API)

O ESP32 consulta o seu modo em `GET /api/colmeia/modo/:mac` ao arrancar e periodicamente
(com fallback para o último valor guardado em NVS se não houver rede):

* **BASE** — lê os sensores, grava no SD, envia por HTTP, abre o servidor BLE ~20 s e entra em
  *deep sleep* (`SLEEP_SECS = 60`). Consumo mínimo.
* **PREMIUM** — fica acordado em loop contínuo, com as interrupções IR ativas para contar
  abelhas, e reporta a cada minuto (`REPORT_MS`). Se o modo voltar a BASE, volta a dormir.

### Fluxo de cada reporte
1. Ler DHT22, peso (média de amostras HX711) e RTC.
2. Gravar linha CSV no MicroSD.
3. Se houver WiFi: `POST /api/leitura` com header `x-api-key`.
4. Desligar WiFi e abrir servidor BLE para sincronização offline.

### Parâmetros BLE
* `SERVICE_UUID`: `12345678-1234-1234-1234-123456789abc`
* `CHARACTERISTIC` (dados, NOTIFY/READ): `…abd`
* `CHARACTERISTIC` (comandos, WRITE): `…abe` — aceita `SYNC`, `END`, `TARE`

### Configurar e gravar
```bash
# 1. Criar credentials.h a partir do exemplo e preencher WiFi + API_KEY
cp firmware/src/credentials.h.example firmware/src/credentials.h

# 2. Compilar e gravar (PlatformIO)
pio run -e esp32dev -t upload

# Calibração da célula de carga (ambiente separado)
pio run -e calibrate -t upload
```

---

## 2. Backend (API REST)

Node.js + Express 5 + MySQL (`mysql2`), com `helmet`, CORS configurável, *rate limiting* nas rotas
de autenticação e validação via `express-validator`.

* **Autenticação:** email/password (bcrypt) **e** Google OAuth; JWT *access token* (15 min) +
  *refresh token* (7 dias) persistido na BD.
* **Papéis:** `admin` (vê tudo, gere utilizadores) e `apicultor` (só as suas colmeias).
* **Ingestão do ESP32:** protegida por API Key (`x-api-key`), independente do JWT.

### Endpoints principais
| Método | Rota                                   | Auth        | Descrição                              |
|--------|----------------------------------------|-------------|----------------------------------------|
| POST   | `/api/auth/registar`                   | —           | Criar conta                            |
| POST   | `/api/auth/login`                      | —           | Login email/password                   |
| POST   | `/api/auth/google`                     | —           | Login/registo Google OAuth             |
| POST   | `/api/auth/refresh`                    | —           | Renovar access token                   |
| POST   | `/api/auth/logout`                     | —           | Invalidar refresh token                |
| GET    | `/api/colmeias`                        | JWT         | Listar colmeias                        |
| POST   | `/api/colmeias`                        | JWT         | Criar colmeia                          |
| DELETE | `/api/colmeias/:id`                    | JWT         | Eliminar colmeia                       |
| POST   | `/api/leitura`                         | API Key     | Ingestão de leitura (ESP32 via WiFi)   |
| POST   | `/api/colmeias/:id/leituras`           | JWT         | Sincronização em lote (BLE → app)      |
| GET    | `/api/dados/:colmeia_id`               | JWT         | Últimas 20 leituras                    |
| GET    | `/api/colmeias/:id/resumo`             | JWT         | Totais acumulados (saldo de abelhas)   |
| GET    | `/api/colmeias/:id/historico`          | JWT         | Histórico paginado                     |
| GET    | `/api/colmeias/:id/historico/export`   | JWT         | Exportar histórico em CSV              |
| GET    | `/api/alertas`                         | JWT         | Listar alertas                         |
| PATCH  | `/api/alertas/:id/lido`                | JWT         | Marcar alerta como lido                |
| GET    | `/api/colmeia/modo/:mac`               | API Key     | ESP32 consulta o modo (base/premium)   |
| PUT    | `/api/colmeias/:id/modo`               | JWT         | Definir modo da colmeia                |
| GET    | `/api/admin/utilizadores`              | JWT (admin) | Listar utilizadores                    |
| PATCH  | `/api/admin/utilizadores/:id/ativar`   | JWT (admin) | Ativar/desativar utilizador            |
| GET    | `/health`                              | —           | Health check                           |

### Variáveis de ambiente (`.env`)
```
# Base de dados (aceita prefixos MYSQL* do Railway ou DB_*)
MYSQLHOST / DB_HOST
MYSQLPORT / DB_PORT
MYSQLUSER / DB_USER
MYSQLPASSWORD / DB_PASSWORD
MYSQLDATABASE / DB_NAME

JWT_SECRET
JWT_REFRESH_SECRET
GOOGLE_CLIENT_ID
ESP32_API_KEY
FRONTEND_URL        # origem extra permitida no CORS
PORT                # default 3000
```

### Executar
```bash
cd backend
npm install
npm run dev    # nodemon
# ou: npm start
```

---

## 3. Frontend (Dashboard Web)

React 19 + Vite + Tailwind, com gráficos `recharts` e login Google (`@react-oauth/google`).
Permite ao apicultor visualizar leituras, gráficos e alertas das suas colmeias; o admin gere
utilizadores. Deploy em Vercel (`https://bee-app-pesta.vercel.app`).

```bash
cd frontend
npm install
npm run dev      # servidor de desenvolvimento Vite
npm run build    # build de produção
```

---

## 4. Aplicação Móvel (Flutter)

Flutter + Riverpod (estado), Dio (HTTP), `flutter_secure_storage` (tokens), `hive_flutter`
(fila offline), `fl_chart` (gráficos), `flutter_blue_plus` (BLE) e `connectivity_plus`.

**Funcionalidades:** autenticação, lista e detalhe de colmeias, gráficos por métrica, alertas,
definições (incl. modo base/premium) e **sincronização BLE** — lê o CSV do ESP32 por BLE e
envia em lote para a API através de `POST /api/colmeias/:id/leituras`.

```bash
cd mobile
flutter pub get
flutter run      # requer emulador ou dispositivo físico
```

---

## 5. Base de Dados

Schema em [database/schema.sql](database/schema.sql) (MySQL). Tabelas:
`utilizadores`, `colmeias`, `leituras_colmeia`, `refresh_tokens`, `alertas_colmeia`.
Inclui utilizadores e leituras de teste.

> O backend executa uma migração automática ao arrancar (adiciona a coluna `modo` à tabela
> `colmeias` se ainda não existir).

```bash
mysql -u root -p < database/schema.sql
```

---

## Arquitetura (resumo)

```
                 WiFi / HTTP (x-api-key)
   ESP32 ─────────────────────────────────────►  Backend (Express + MySQL)
     │                                               ▲          ▲
     │ BLE (offline)                            JWT  │          │ JWT
     ▼                                               │          │
  App Móvel  ──── sync em lote ─────────────────────┘     Dashboard Web
```
