require('dotenv').config(); // Carregamento das variáveis de ambiente a partir do ficheiro .env
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();

// Middlewares de controlo e parsing do servidor
app.use(express.json());
app.use(cors()); // Permite o acesso à API por parte de clientes externos (Dashboard Web e Aplicação Móvel)

// Configuração da ligação à base de dados MySQL com parâmetros parametrizados via ambiente
const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,       
    password: process.env.DB_PASSWORD, 
    database: process.env.DB_NAME
});

// Inicialização e verificação da ligação ao servidor MySQL
db.connect(err => {
    if (err) {
        console.error('Erro crítico: Não foi possível estabelecer ligação ao MySQL:', err.message);
        return;
    }
    console.log('Ligação segura à base de dados bee_app_pesta estabelecida com sucesso!');
});

/**
 * ROTA POST: Receção de Dados de Telemetria (Injetados pelo módulo ESP32)
 * URL: http://localhost:3000/api/leitura
 */
app.post('/api/leitura', (req, res) => {
    const { colmeia_id, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria } = req.body;
    
    const query = `INSERT INTO leituras_colmeia 
    (colmeia_id, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria) 
    VALUES (?, ?, ?, ?, ?, ?, ?)`;

    // Atribuição de um ID por defeito (ID 1) caso o dispositivo IoT não envie um identificador na trama de dados
    const id_colmeia = colmeia_id || 1;

    db.query(
        query, 
        [id_colmeia, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria], 
        (err, result) => {
            if (err) {
                console.error('Erro ao inserir dados no MySQL:', err);
                return res.status(500).send('Erro interno ao gravar os dados de telemetria.');
            }
            res.status(201).send(`[Sucesso] Dados da colmeia ${id_colmeia} registados em tempo real.`);
        }
    );
});

/**
 * ROTA GET: Envio de Dados Históricos (Consumidos pelas interfaces de visualização)
 * URL Exemplo: http://localhost:3000/api/dados/1 (Leitura dos dados da colmeia de teste de bancada)
 * URL Exemplo: http://localhost:3000/api/dados/2 (Leitura dos dados da colmeia de campo do apicultor)
 */
app.get('/api/dados/:colmeia_id', (req, res) => {
    const id_colmeia = req.params.colmeia_id;
    
    // Consulta estruturada para extrair os últimos 20 registos da colmeia selecionada
    const query = 'SELECT * FROM leituras_colmeia WHERE colmeia_id = ? ORDER BY timestamp DESC LIMIT 20';
    
    db.query(query, [id_colmeia], (err, results) => {
        if (err) {
            console.error('Erro ao consultar dados no MySQL:', err);
            return res.status(500).send('Erro interno ao processar a consulta.');
        }
        
        // Inversão da ordenação do array para garantir uma sequência cronológica ascendente
        // Este procedimento assegura a correta renderização linear dos gráficos da esquerda para a direita
        res.json(results.reverse());
    });
});

// Inicialização do Servidor HTTP na porta definida no ambiente ou na porta padrão 3000
const PORTA = process.env.PORT || 3000;
app.listen(PORTA, () => {
    console.log(`Servidor IoT ativo e escutando na porta ${PORTA}`);
});