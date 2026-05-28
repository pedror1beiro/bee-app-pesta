require('dotenv').config();
const express    = require('express');
const mysql      = require('mysql2/promise');
const cors       = require('cors');
const bcrypt     = require('bcrypt');
const jwt        = require('jsonwebtoken');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const { OAuth2Client } = require('google-auth-library');
const { body, validationResult } = require('express-validator');

const app    = express();
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Necessário para rate limiting correcto atrás do proxy do Railway
app.set('trust proxy', 1);

// ─── MIDDLEWARES ─────────────────────────────────────────────────────────────
app.use(helmet());
app.use(express.json());

const origens = ['http://localhost:5173', 'https://bee-app-pesta.vercel.app'];
if (process.env.FRONTEND_URL) origens.push(process.env.FRONTEND_URL);
app.use(cors({ origin: origens, credentials: true }));

const limiteAuth = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    message: { erro: 'Demasiadas tentativas. Tenta novamente em 15 minutos.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// ─── LIGAÇÃO À BASE DE DADOS ──────────────────────────────────────────────────
const db = mysql.createPool({
    host:     process.env.MYSQLHOST     || process.env.DB_HOST,
    port:     process.env.MYSQLPORT     || process.env.DB_PORT     || 3306,
    user:     process.env.MYSQLUSER     || process.env.DB_USER,
    password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD,
    database: process.env.MYSQLDATABASE || process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
});

// Teste de ligação ao arrancar
(async () => {
    try {
        await db.query('SELECT 1');
        console.log('✅ Ligação segura à base de dados estabelecida com sucesso!');
    } catch (err) {
        console.error('❌ Erro crítico: Não foi possível ligar ao MySQL:', err.message);
    }
})();

// ─── HELPERS JWT ──────────────────────────────────────────────────────────────
function gerarAccessToken(utilizador) {
    return jwt.sign(
        { id: utilizador.id, email: utilizador.email, role: utilizador.role },
        process.env.JWT_SECRET,
        { expiresIn: '15m' }
    );
}

function gerarRefreshToken(utilizador) {
    return jwt.sign(
        { id: utilizador.id },
        process.env.JWT_REFRESH_SECRET,
        { expiresIn: '7d' }
    );
}

// ─── MIDDLEWARE DE AUTENTICAÇÃO ───────────────────────────────────────────────
function autenticar(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>
    if (!token) return res.status(401).json({ erro: 'Token de acesso em falta.' });

    jwt.verify(token, process.env.JWT_SECRET, (err, utilizador) => {
        if (err) return res.status(403).json({ erro: 'Token inválido ou expirado.' });
        req.utilizador = utilizador;
        next();
    });
}

// Middleware para verificar se é admin
function apenasAdmin(req, res, next) {
    if (req.utilizador.role !== 'admin') {
        return res.status(403).json({ erro: 'Acesso restrito a administradores.' });
    }
    next();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROTAS DE AUTENTICAÇÃO
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * POST /api/auth/registar
 * Criar nova conta com email + password
 */
app.post('/api/auth/registar', limiteAuth, [
    body('nome').trim().notEmpty().withMessage('Nome é obrigatório.'),
    body('email').isEmail().withMessage('Email inválido.'),
    body('password').isLength({ min: 8 }).withMessage('Password deve ter pelo menos 8 caracteres.'),
], async (req, res) => {
    const erros = validationResult(req);
    if (!erros.isEmpty()) return res.status(400).json({ erros: erros.array() });

    const { nome, email, password } = req.body;

    try {
        // Verificar se o email já existe
        const [existente] = await db.query('SELECT id FROM utilizadores WHERE email = ?', [email]);
        if (existente.length > 0) {
            return res.status(409).json({ erro: 'Este email já está registado.' });
        }

        // Encriptar password
        const password_hash = await bcrypt.hash(password, 10);

        // Inserir utilizador
        const [result] = await db.query(
            'INSERT INTO utilizadores (nome, email, password_hash, role) VALUES (?, ?, ?, ?)',
            [nome, email, password_hash, 'apicultor']
        );

        res.status(201).json({
            mensagem: 'Conta criada com sucesso!',
            utilizador: { id: result.insertId, nome, email, role: 'apicultor' }
        });
    } catch (err) {
        console.error('Erro ao registar:', err);
        res.status(500).json({ erro: 'Erro interno ao criar conta.' });
    }
});

/**
 * POST /api/auth/login
 * Login com email + password → devolve access token + refresh token
 */
app.post('/api/auth/login', limiteAuth, [
    body('email').isEmail().withMessage('Email inválido.'),
    body('password').notEmpty().withMessage('Password é obrigatória.'),
], async (req, res) => {
    const erros = validationResult(req);
    if (!erros.isEmpty()) return res.status(400).json({ erros: erros.array() });

    const { email, password } = req.body;

    try {
        const [rows] = await db.query('SELECT * FROM utilizadores WHERE email = ? AND ativo = TRUE', [email]);
        if (rows.length === 0) {
            return res.status(401).json({ erro: 'Credenciais inválidas.' });
        }

        const utilizador = rows[0];

        // Verificar se tem password (pode ser conta Google sem password)
        if (!utilizador.password_hash) {
            return res.status(401).json({ erro: 'Esta conta usa login com Google. Por favor usa o botão "Entrar com Google".' });
        }

        const passwordCorreta = await bcrypt.compare(password, utilizador.password_hash);
        if (!passwordCorreta) {
            return res.status(401).json({ erro: 'Credenciais inválidas.' });
        }

        const accessToken  = gerarAccessToken(utilizador);
        const refreshToken = gerarRefreshToken(utilizador);

        // Guardar refresh token na BD
        const expiraEm = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await db.query(
            'INSERT INTO refresh_tokens (utilizador_id, token, expira_em) VALUES (?, ?, ?)',
            [utilizador.id, refreshToken, expiraEm]
        );

        res.json({
            accessToken,
            refreshToken,
            utilizador: {
                id:    utilizador.id,
                nome:  utilizador.nome,
                email: utilizador.email,
                role:  utilizador.role
            }
        });
    } catch (err) {
        console.error('Erro ao fazer login:', err);
        res.status(500).json({ erro: 'Erro interno ao fazer login.' });
    }
});

/**
 * POST /api/auth/google
 * Login / Registo com Google OAuth (envia o idToken do frontend)
 */
app.post('/api/auth/google', limiteAuth, async (req, res) => {
    const { idToken } = req.body;
    if (!idToken) return res.status(400).json({ erro: 'Token Google em falta.' });

    try {
        // Verificar token com Google
        const ticket = await client.verifyIdToken({
            idToken,
            audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        const { sub: google_id, email, name: nome } = payload;

        // Verificar se já existe
        let [rows] = await db.query('SELECT * FROM utilizadores WHERE google_id = ? OR email = ?', [google_id, email]);
        let utilizador;

        if (rows.length > 0) {
            utilizador = rows[0];
            // Associar google_id se ainda não estiver associado
            if (!utilizador.google_id) {
                await db.query('UPDATE utilizadores SET google_id = ? WHERE id = ?', [google_id, utilizador.id]);
            }
        } else {
            // Criar novo utilizador
            const [result] = await db.query(
                'INSERT INTO utilizadores (nome, email, google_id, role) VALUES (?, ?, ?, ?)',
                [nome, email, google_id, 'apicultor']
            );
            utilizador = { id: result.insertId, nome, email, role: 'apicultor' };
        }

        const accessToken  = gerarAccessToken(utilizador);
        const refreshToken = gerarRefreshToken(utilizador);

        const expiraEm = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await db.query(
            'INSERT INTO refresh_tokens (utilizador_id, token, expira_em) VALUES (?, ?, ?)',
            [utilizador.id, refreshToken, expiraEm]
        );

        res.json({
            accessToken,
            refreshToken,
            utilizador: {
                id:    utilizador.id,
                nome:  utilizador.nome,
                email: utilizador.email,
                role:  utilizador.role
            }
        });
    } catch (err) {
        console.error('Erro no login Google:', err);
        res.status(401).json({ erro: 'Token Google inválido.' });
    }
});

/**
 * POST /api/auth/refresh
 * Renovar access token com refresh token
 */
app.post('/api/auth/refresh', limiteAuth, async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(401).json({ erro: 'Refresh token em falta.' });

    try {
        const [rows] = await db.query(
            'SELECT * FROM refresh_tokens WHERE token = ? AND expira_em > NOW()',
            [refreshToken]
        );
        if (rows.length === 0) return res.status(403).json({ erro: 'Refresh token inválido ou expirado.' });

        let decoded;
        try {
            decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
        } catch {
            return res.status(403).json({ erro: 'Refresh token inválido.' });
        }

        const [userRows] = await db.query('SELECT * FROM utilizadores WHERE id = ?', [decoded.id]);
        if (userRows.length === 0) return res.status(403).json({ erro: 'Utilizador não encontrado.' });

        res.json({ accessToken: gerarAccessToken(userRows[0]) });
    } catch (err) {
        console.error('Erro ao renovar token:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

/**
 * POST /api/auth/logout
 * Invalidar refresh token
 */
app.post('/api/auth/logout', async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ erro: 'Refresh token em falta.' });

    try {
        await db.query('DELETE FROM refresh_tokens WHERE token = ?', [refreshToken]);
        res.json({ mensagem: 'Sessão terminada com sucesso.' });
    } catch (err) {
        console.error('Erro ao fazer logout:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ROTAS DE COLMEIAS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * GET /api/colmeias
 * Lista as colmeias do utilizador autenticado (admin vê todas)
 */
app.get('/api/colmeias', autenticar, async (req, res) => {
    try {
        let rows;
        if (req.utilizador.role === 'admin') {
            [rows] = await db.query(`
                SELECT c.*, u.nome AS nome_apicultor, u.email AS email_apicultor
                FROM colmeias c
                JOIN utilizadores u ON c.utilizador_id = u.id
                ORDER BY c.criado_em DESC
            `);
        } else {
            [rows] = await db.query(
                'SELECT * FROM colmeias WHERE utilizador_id = ? ORDER BY criado_em DESC',
                [req.utilizador.id]
            );
        }
        res.json(rows);
    } catch (err) {
        console.error('Erro ao listar colmeias:', err);
        res.status(500).json({ erro: 'Erro interno ao listar colmeias.' });
    }
});

/**
 * POST /api/colmeias
 * Criar nova colmeia (associada ao utilizador autenticado)
 */
app.post('/api/colmeias', autenticar, [
    body('nome').trim().notEmpty().withMessage('Nome da colmeia é obrigatório.'),
], async (req, res) => {
    const erros = validationResult(req);
    if (!erros.isEmpty()) return res.status(400).json({ erros: erros.array() });

    const { nome, localizacao, latitude, longitude, mac_address } = req.body;
    const utilizador_id = req.utilizador.id;

    try {
        const [result] = await db.query(
            'INSERT INTO colmeias (utilizador_id, nome, localizacao, latitude, longitude, mac_address) VALUES (?, ?, ?, ?, ?, ?)',
            [utilizador_id, nome, localizacao || null, latitude || null, longitude || null, mac_address ? mac_address.toUpperCase() : null]
        );
        res.status(201).json({
            mensagem: 'Colmeia criada com sucesso!',
            colmeia: { id: result.insertId, utilizador_id, nome, localizacao, latitude, longitude, mac_address: mac_address || null }
        });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ erro: 'Este MAC address já está associado a outra colmeia.' });
        }
        console.error('Erro ao criar colmeia:', err);
        res.status(500).json({ erro: 'Erro interno ao criar colmeia.' });
    }
});

/**
 * DELETE /api/colmeias/:id
 * Eliminar colmeia (apenas o dono ou admin)
 */
app.delete('/api/colmeias/:id', autenticar, async (req, res) => {
    const { id } = req.params;
    try {
        const [rows] = await db.query('SELECT * FROM colmeias WHERE id = ?', [id]);
        if (rows.length === 0) return res.status(404).json({ erro: 'Colmeia não encontrada.' });

        const colmeia = rows[0];
        if (colmeia.utilizador_id !== req.utilizador.id && req.utilizador.role !== 'admin') {
            return res.status(403).json({ erro: 'Sem permissão para eliminar esta colmeia.' });
        }

        await db.query('DELETE FROM colmeias WHERE id = ?', [id]);
        res.json({ mensagem: 'Colmeia eliminada com sucesso.' });
    } catch (err) {
        console.error('Erro ao eliminar colmeia:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ROTAS DE TELEMETRIA (DADOS ESP32)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * POST /api/leitura
 * Receção de dados do ESP32 — protegido por API Key
 * O ESP32 deve enviar o header: x-api-key: <ESP32_API_KEY>
 */
app.post('/api/leitura', async (req, res) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.ESP32_API_KEY) {
        return res.status(401).json({ erro: 'API Key inválida.' });
    }

    const { mac_address, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria } = req.body;

    if (!mac_address) {
        return res.status(400).json({ erro: 'mac_address em falta no corpo do pedido.' });
    }

    try {
        const [colmeiaRows] = await db.query(
            'SELECT id FROM colmeias WHERE mac_address = ?',
            [mac_address.toUpperCase()]
        );
        if (colmeiaRows.length === 0) {
            return res.status(404).json({ erro: 'MAC address não registado. Associa este ESP32 a uma colmeia no website.' });
        }
        const id_colmeia = colmeiaRows[0].id;

        await db.query(
            `INSERT INTO leituras_colmeia
             (colmeia_id, temperatura, humidade, peso, entradas_abelhas, saidas_abelhas, nivel_bateria)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [id_colmeia, temperatura, humidade, peso ?? 0, entradas_abelhas ?? 0, saidas_abelhas ?? 0, nivel_bateria ?? 0]
        );
        res.status(201).json({ mensagem: `Dados da colmeia ${id_colmeia} registados com sucesso.` });
    } catch (err) {
        console.error('Erro ao inserir dados:', err);
        res.status(500).json({ erro: 'Erro interno ao gravar os dados de telemetria.' });
    }
});

/**
 * GET /api/dados/:colmeia_id
 * Leitura dos últimos 20 registos — protegido (só o dono ou admin)
 */
app.get('/api/dados/:colmeia_id', autenticar, async (req, res) => {
    const id_colmeia = req.params.colmeia_id;

    try {
        // Verificar se a colmeia pertence ao utilizador (ou é admin)
        const [colmeia] = await db.query('SELECT * FROM colmeias WHERE id = ?', [id_colmeia]);
        if (colmeia.length === 0) return res.status(404).json({ erro: 'Colmeia não encontrada.' });

        if (colmeia[0].utilizador_id !== req.utilizador.id && req.utilizador.role !== 'admin') {
            return res.status(403).json({ erro: 'Sem permissão para aceder a esta colmeia.' });
        }

        const [results] = await db.query(
            'SELECT * FROM leituras_colmeia WHERE colmeia_id = ? ORDER BY timestamp DESC LIMIT 20',
            [id_colmeia]
        );

        res.json(results.reverse());
    } catch (err) {
        console.error('Erro ao consultar dados:', err);
        res.status(500).json({ erro: 'Erro interno ao processar a consulta.' });
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ROTAS DE ALERTAS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * GET /api/alertas
 * Lista alertas das colmeias do utilizador
 */
app.get('/api/alertas', autenticar, async (req, res) => {
    try {
        let rows;
        if (req.utilizador.role === 'admin') {
            [rows] = await db.query('SELECT * FROM alertas_colmeia ORDER BY criado_em DESC LIMIT 50');
        } else {
            [rows] = await db.query(`
                SELECT a.* FROM alertas_colmeia a
                JOIN colmeias c ON a.colmeia_id = c.id
                WHERE c.utilizador_id = ?
                ORDER BY a.criado_em DESC LIMIT 50
            `, [req.utilizador.id]);
        }
        res.json(rows);
    } catch (err) {
        console.error('Erro ao listar alertas:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

/**
 * PATCH /api/alertas/:id/lido
 * Marcar alerta como lido
 */
app.patch('/api/alertas/:id/lido', autenticar, async (req, res) => {
    try {
        const [rows] = await db.query(`
            SELECT a.id FROM alertas_colmeia a
            JOIN colmeias c ON a.colmeia_id = c.id
            WHERE a.id = ? AND (c.utilizador_id = ? OR ? = 'admin')
        `, [req.params.id, req.utilizador.id, req.utilizador.role]);

        if (rows.length === 0) {
            return res.status(403).json({ erro: 'Sem permissão para alterar este alerta.' });
        }

        await db.query('UPDATE alertas_colmeia SET lido = TRUE WHERE id = ?', [req.params.id]);
        res.json({ mensagem: 'Alerta marcado como lido.' });
    } catch (err) {
        console.error('Erro ao atualizar alerta:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// ROTAS DE ADMINISTRAÇÃO
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * GET /api/admin/utilizadores
 * Lista todos os utilizadores (apenas admin)
 */
app.get('/api/admin/utilizadores', autenticar, apenasAdmin, async (req, res) => {
    try {
        const [rows] = await db.query(
            'SELECT id, nome, email, role, ativo, criado_em FROM utilizadores ORDER BY criado_em DESC'
        );
        res.json(rows);
    } catch (err) {
        console.error('Erro ao listar utilizadores:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

/**
 * PATCH /api/admin/utilizadores/:id/ativar
 * Ativar/desativar utilizador (apenas admin)
 */
app.patch('/api/admin/utilizadores/:id/ativar', autenticar, apenasAdmin, async (req, res) => {
    const ativo = req.body.ativo === true || req.body.ativo === 1;
    try {
        await db.query('UPDATE utilizadores SET ativo = ? WHERE id = ?', [ativo, req.params.id]);
        res.json({ mensagem: `Utilizador ${ativo ? 'ativado' : 'desativado'} com sucesso.` });
    } catch (err) {
        console.error('Erro ao atualizar utilizador:', err);
        res.status(500).json({ erro: 'Erro interno.' });
    }
});

// ─── HEALTH CHECK ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// ─── INICIALIZAÇÃO DO SERVIDOR ────────────────────────────────────────────────
const PORTA = process.env.PORT || 3000;
app.listen(PORTA, () => {
    console.log(`🍯 Servidor IoT BeeApp ativo na porta ${PORTA}`);
});