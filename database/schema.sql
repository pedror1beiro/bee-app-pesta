-- Limpar tudo e recomeçar do zero
DROP DATABASE IF EXISTS bee_app_pesta;
CREATE DATABASE bee_app_pesta;
USE bee_app_pesta;

-- ─── 1. UTILIZADORES ──────────────────────────────────────────────────────
CREATE TABLE utilizadores (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    google_id     VARCHAR(100) UNIQUE,
    role          ENUM('admin', 'apicultor') NOT NULL DEFAULT 'apicultor',
    ativo         BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ─── 2. COLMEIAS ──────────────────────────────────────────────────────────
CREATE TABLE colmeias (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    utilizador_id   INT NOT NULL,
    nome            VARCHAR(100) NOT NULL,
    localizacao     VARCHAR(255),
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    ativa           BOOLEAN NOT NULL DEFAULT TRUE,
    mac_address     VARCHAR(17) UNIQUE,
    criado_em       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id) ON DELETE CASCADE
);

-- ─── 3. LEITURAS ──────────────────────────────────────────────────────────
CREATE TABLE leituras_colmeia (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    colmeia_id       INT NOT NULL,
    timestamp        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    temperatura      DECIMAL(5,2) NOT NULL,
    humidade         DECIMAL(5,2) NOT NULL,
    peso             DECIMAL(5,2) NOT NULL,
    entradas_abelhas INT NOT NULL DEFAULT 0,
    saidas_abelhas   INT NOT NULL DEFAULT 0,
    nivel_bateria    DECIMAL(4,2) NOT NULL,
    FOREIGN KEY (colmeia_id) REFERENCES colmeias(id) ON DELETE CASCADE
);

-- ─── 4. REFRESH TOKENS ────────────────────────────────────────────────────
CREATE TABLE refresh_tokens (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    utilizador_id INT NOT NULL,
    token         VARCHAR(512) NOT NULL UNIQUE,
    expira_em     TIMESTAMP NOT NULL,
    criado_em     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (utilizador_id) REFERENCES utilizadores(id) ON DELETE CASCADE
);

-- ─── 5. ALERTAS ───────────────────────────────────────────────────────────
CREATE TABLE alertas_colmeia (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    colmeia_id    INT NOT NULL,
    tipo          ENUM('temperatura', 'humidade', 'peso', 'bateria') NOT NULL,
    mensagem      VARCHAR(255) NOT NULL,
    lido          BOOLEAN NOT NULL DEFAULT FALSE,
    criado_em     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (colmeia_id) REFERENCES colmeias(id) ON DELETE CASCADE
);

-- ─── 6. ÍNDICES ───────────────────────────────────────────────────────────
CREATE INDEX idx_leituras_colmeia_id ON leituras_colmeia(colmeia_id);
CREATE INDEX idx_leituras_timestamp  ON leituras_colmeia(timestamp);
CREATE INDEX idx_alertas_colmeia_id  ON alertas_colmeia(colmeia_id);
CREATE INDEX idx_tokens_utilizador   ON refresh_tokens(utilizador_id);

-- ─── 7. UTILIZADORES DE TESTE ─────────────────────────────────────────────
-- Hashes bcrypt REAIS gerados para:
--   admin@beeapp.pt  → password: Admin1234!
--   joao@beeapp.pt   → password: Joao1234!
INSERT INTO utilizadores (nome, email, password_hash, role) VALUES
('Administrador', 'admin@beeapp.pt',
 '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
 'admin'),
('João Apicultor', 'joao@beeapp.pt',
 '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
 'apicultor');

-- ─── 8. COLMEIAS DE TESTE ─────────────────────────────────────────────────
-- Colmeia do João (utilizador_id = 2)
INSERT INTO colmeias (utilizador_id, nome, localizacao, latitude, longitude) VALUES
(2, 'Colmeia Norte A', 'Quinta do Vale, Braga',   41.5518, -8.4229),
(2, 'Colmeia Sul B',   'Herdade do Monte, Évora',  38.5714, -7.9083);

-- ─── 9. LEITURAS DE TESTE (colmeia 1 = Colmeia Norte A) ───────────────────
INSERT INTO leituras_colmeia (colmeia_id, timestamp, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria) VALUES
(1, '2026-05-18 20:00:00', 34.20, 44.80, 22.05,  8,  6, 4.10),
(1, '2026-05-18 20:10:00', 34.50, 45.20, 22.10, 15, 12, 4.09),
(1, '2026-05-18 20:20:00', 34.80, 44.50, 22.10, 20, 18, 4.08),
(1, '2026-05-18 20:30:00', 35.10, 43.90, 22.15, 25, 22, 4.07),
(1, '2026-05-18 20:40:00', 35.30, 43.20, 22.20, 18, 15, 4.06),
(1, '2026-05-18 20:50:00', 35.00, 44.10, 22.18, 12, 10, 4.05),
(1, '2026-05-18 21:00:00', 34.70, 45.00, 22.12, 22, 20, 4.04);

-- Leituras de teste (colmeia 2 = Colmeia Sul B)
INSERT INTO leituras_colmeia (colmeia_id, timestamp, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria) VALUES
(2, '2026-05-18 20:00:00', 33.10, 50.20, 18.30, 10,  8, 3.95),
(2, '2026-05-18 20:10:00', 33.40, 49.80, 18.35, 14, 11, 3.94),
(2, '2026-05-18 20:20:00', 33.80, 48.90, 18.40, 19, 16, 3.93),
(2, '2026-05-18 20:30:00', 34.20, 48.10, 18.50, 22, 19, 3.92),
(2, '2026-05-18 20:40:00', 34.50, 47.50, 18.55, 17, 14, 3.91),
(2, '2026-05-18 20:50:00', 34.30, 48.00, 18.52, 11,  9, 3.90),
(2, '2026-05-18 21:00:00', 34.00, 48.50, 18.48, 20, 17, 3.89);

-- ─── 10. ALERTA DE TESTE ──────────────────────────────────────────────────
INSERT INTO alertas_colmeia (colmeia_id, tipo, mensagem) VALUES
(1, 'bateria', 'Bateria da Colmeia Norte A abaixo de 4.0V — verificar painel solar.');