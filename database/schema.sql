-- Forçar a criação da base de dados
CREATE DATABASE IF NOT EXISTS bee_app_pesta;

-- Mudar o foco para a base de dados criada
USE bee_app_pesta;

-- Criar a tabela de telemetria
CREATE TABLE IF NOT EXISTS leituras_colmeia (
    id INT AUTO_INCREMENT PRIMARY KEY,
    colmeia_id INT NOT NULL DEFAULT 1,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    temperatura DECIMAL(5,2) NOT NULL,
    humidade DECIMAL(5,2) NOT NULL,
    peso DECIMAL(5,2) NOT NULL,
    entradas_abelhas INT NOT NULL DEFAULT 0,
    saidas_abelhas INT NOT NULL DEFAULT 0,
    nivel_bateria DECIMAL(4,2) NOT NULL
);