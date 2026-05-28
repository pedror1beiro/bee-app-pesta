import { useState, useEffect, useCallback } from "react";
import { useAuth } from "./AuthContext";
import {
  LineChart, Line, AreaChart, Area,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from "recharts";

// ─── CONFIG ──────────────────────────────────────────────────────────────────
const POLL_INTERVAL = 10000;

// ─── HELPERS ─────────────────────────────────────────────────────────────────
function formatTimestamp(ts) {
  try {
    return new Date(ts).toLocaleTimeString("pt-PT", { hour: "2-digit", minute: "2-digit" });
  } catch { return ts; }
}

function getLatest(data) {
  return data.length > 0 ? data[data.length - 1] : null;
}

// ─── CUSTOM TOOLTIP ──────────────────────────────────────────────────────────
function CustomTooltip({ active, payload, label, unit = "" }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-xl p-3 text-sm">
      <p className="text-slate-500 mb-1 font-medium">{label}</p>
      {payload.map((p, i) => (
        <p key={i} style={{ color: p.color }} className="font-semibold">
          {p.name}: {typeof p.value === "number" ? p.value.toFixed(2) : p.value}{unit}
        </p>
      ))}
    </div>
  );
}

// ─── STAT BADGE ──────────────────────────────────────────────────────────────
function StatBadge({ label, value, unit, color }) {
  const colorMap = {
    red:    "bg-red-50 text-red-600 border-red-100",
    blue:   "bg-blue-50 text-blue-600 border-blue-100",
    green:  "bg-emerald-50 text-emerald-600 border-emerald-100",
    purple: "bg-purple-50 text-purple-600 border-purple-100",
    amber:  "bg-amber-50 text-amber-600 border-amber-100",
  };
  return (
    <div className={`rounded-lg border px-3 py-2 text-center ${colorMap[color] || colorMap.blue}`}>
      <p className="text-xs font-medium opacity-70">{label}</p>
      <p className="text-lg font-bold leading-tight">
        {value != null ? (typeof value === "number" ? value.toFixed(1) : value) : "—"}
        <span className="text-xs font-normal ml-0.5">{unit}</span>
      </p>
    </div>
  );
}

// ─── CARD ────────────────────────────────────────────────────────────────────
function Card({ title, icon, children, badges }) {
  return (
    <div className="bg-white rounded-2xl shadow-md border border-slate-100 flex flex-col overflow-hidden hover:shadow-lg transition-shadow duration-300">
      <div className="px-5 pt-5 pb-3 flex items-center gap-2">
        <span className="text-xl">{icon}</span>
        <h2 className="text-sm font-bold text-slate-700 tracking-wide uppercase">{title}</h2>
      </div>
      {badges && <div className="px-5 pb-3 flex flex-wrap gap-2">{badges}</div>}
      <div className="flex-1 px-2 pb-4" style={{ minHeight: 220 }}>{children}</div>
    </div>
  );
}

// ─── GRÁFICOS ────────────────────────────────────────────────────────────────
function ClimaChart({ data }) {
  return (
    <Card title="Clima Interno" icon="🌡️" badges={[
      <StatBadge key="t" label="Temperatura" value={getLatest(data)?.temperatura} unit="°C" color="red" />,
      <StatBadge key="h" label="Humidade"    value={getLatest(data)?.humidade}    unit="%"  color="blue" />,
    ]}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis yAxisId="temp" domain={["auto","auto"]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis yAxisId="hum" orientation="right" domain={[0,100]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Line yAxisId="temp" type="monotone" dataKey="temperatura" name="Temp (°C)"     stroke="#f97316" strokeWidth={2.5} dot={false} activeDot={{ r: 5 }} />
          <Line yAxisId="hum"  type="monotone" dataKey="humidade"    name="Humidade (%)"  stroke="#3b82f6" strokeWidth={2.5} dot={false} activeDot={{ r: 5 }} />
        </LineChart>
      </ResponsiveContainer>
    </Card>
  );
}

function PesoChart({ data }) {
  return (
    <Card title="Evolução do Peso" icon="⚖️" badges={[
      <StatBadge key="p" label="Peso atual" value={getLatest(data)?.peso} unit=" kg" color="green" />,
    ]}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="pesoGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%"  stopColor="#10b981" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#10b981" stopOpacity={0}   />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis domain={["auto","auto"]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip unit=" kg" />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Area type="monotone" dataKey="peso" name="Peso (kg)" stroke="#10b981" strokeWidth={2.5} fill="url(#pesoGrad)" dot={false} activeDot={{ r: 5 }} />
        </AreaChart>
      </ResponsiveContainer>
    </Card>
  );
}

function AtividadeChart({ data }) {
  const latest = getLatest(data);
  const saldo  = latest ? latest.entradas_abelhas - latest.saidas_abelhas : 0;
  return (
    <Card title="Atividade das Abelhas" icon="🐝" badges={[
      <StatBadge key="e" label="Entradas" value={latest?.entradas_abelhas} unit="" color="green" />,
      <StatBadge key="s" label="Saídas"   value={latest?.saidas_abelhas}   unit="" color="red"   />,
      <StatBadge key="b" label="Saldo"    value={saldo}                    unit="" color="amber" />,
    ]}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }} barCategoryGap="35%">
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Bar dataKey="entradas_abelhas" name="Entradas" fill="#10b981" radius={[4,4,0,0]} />
          <Bar dataKey="saidas_abelhas"   name="Saídas"   fill="#ef4444" radius={[4,4,0,0]} />
        </BarChart>
      </ResponsiveContainer>
    </Card>
  );
}

function BateriaChart({ data }) {
  const latest = getLatest(data);
  const volt   = latest?.nivel_bateria;
  const pct    = volt ? Math.min(100, Math.max(0, ((volt - 3.0) / (4.2 - 3.0)) * 100)).toFixed(0) : null;
  return (
    <Card title="Diagnóstico de Energia" icon="🔋" badges={[
      <StatBadge key="v" label="Voltagem"   value={volt} unit=" V" color="purple" />,
      <StatBadge key="p" label="Estimativa" value={pct}  unit="%" color={pct >= 60 ? "green" : pct >= 30 ? "amber" : "red"} />,
    ]}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="bateriaGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%"   stopColor="#a855f7" />
              <stop offset="100%" stopColor="#eab308" />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis domain={[3.0, 4.3]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip unit=" V" />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Line type="monotone" dataKey="nivel_bateria" name="Voltagem (V)" stroke="url(#bateriaGrad)" strokeWidth={2.5} dot={false} activeDot={{ r: 5 }} />
        </LineChart>
      </ResponsiveContainer>
    </Card>
  );
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
function Header({ status, lastUpdate, utilizador, colmeia, onLogout }) {
  const [menuAberto, setMenuAberto] = useState(false);

  const statusConfig = {
    online:  { dot: "bg-emerald-400 animate-pulse", label: "Online · A Atualizar", text: "text-emerald-600", bg: "bg-emerald-50 border-emerald-100" },
    loading: { dot: "bg-amber-400 animate-pulse",   label: "A carregar...",         text: "text-amber-600",   bg: "bg-amber-50 border-amber-100"   },
    error:   { dot: "bg-red-400",                   label: "Sem ligação",           text: "text-red-600",     bg: "bg-red-50 border-red-100"        },
  };
  const s = statusConfig[status] || statusConfig.loading;

  return (
    <header className="bg-white border-b border-slate-100 shadow-sm sticky top-0 z-20">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 py-4 flex items-center justify-between gap-3">
        {/* Logo + título */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-400 flex items-center justify-center shadow-md text-xl">🍯</div>
          <div>
            <h1 className="text-lg font-extrabold text-slate-800 leading-tight tracking-tight">
              Monitorização de Colmeias
              <span className="ml-2 text-xs font-semibold bg-slate-100 text-slate-500 rounded-full px-2 py-0.5 align-middle">IoT</span>
            </h1>
            <p className="text-xs text-slate-400 font-medium">
              {colmeia ? `${colmeia} · ` : ""}Sistema em Tempo Real
            </p>
          </div>
        </div>

        {/* Direita */}
        <div className="flex items-center gap-3">
          {lastUpdate && (
            <span className="hidden sm:block text-xs text-slate-400">
              Atualizado: <span className="font-semibold text-slate-500">{lastUpdate}</span>
            </span>
          )}
          <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-xs font-semibold ${s.bg} ${s.text}`}>
            <span className={`w-2 h-2 rounded-full ${s.dot}`}></span>
            <span className="hidden sm:block">{s.label}</span>
          </div>

          {/* Menu do utilizador */}
          <div className="relative">
            <button
              onClick={() => setMenuAberto(m => !m)}
              className="flex items-center gap-2 px-3 py-2 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 transition-all"
            >
              <div className="w-6 h-6 rounded-full bg-amber-400 flex items-center justify-center text-xs font-bold text-white">
                {utilizador?.nome?.[0]?.toUpperCase() || "U"}
              </div>
              <span className="hidden sm:block text-sm font-semibold text-slate-700 max-w-[100px] truncate">
                {utilizador?.nome}
              </span>
              <span className="text-slate-400 text-xs">▾</span>
            </button>

            {menuAberto && (
              <div className="absolute right-0 mt-2 w-52 bg-white rounded-xl shadow-xl border border-slate-100 py-2 z-30">
                <div className="px-4 py-2 border-b border-slate-100">
                  <p className="text-sm font-bold text-slate-800 truncate">{utilizador?.nome}</p>
                  <p className="text-xs text-slate-400 truncate">{utilizador?.email}</p>
                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full mt-1 inline-block
                    ${utilizador?.role === "admin" ? "bg-purple-100 text-purple-600" : "bg-amber-100 text-amber-600"}`}>
                    {utilizador?.role === "admin" ? "Administrador" : "Apicultor"}
                  </span>
                </div>
                <button
                  onClick={() => { setMenuAberto(false); onLogout(); }}
                  className="w-full text-left px-4 py-2 text-sm text-red-500 hover:bg-red-50 transition-colors"
                >
                  🚪 Terminar sessão
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}

// ─── SELECTOR DE COLMEIA ──────────────────────────────────────────────────────
function SelectorColmeia({ colmeias, colmeiaAtiva, onChange, onNova }) {
  return (
    <div className="flex items-center gap-3 flex-wrap">
      <div className="flex bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
        {colmeias.map(c => (
          <button
            key={c.id}
            onClick={() => onChange(c)}
            className={`px-4 py-2 text-sm font-semibold transition-all duration-200
              ${colmeiaAtiva?.id === c.id
                ? "bg-amber-500 text-white"
                : "text-slate-600 hover:bg-amber-50"
              }`}
          >
            🐝 {c.nome}
          </button>
        ))}
      </div>
      <button
        onClick={onNova}
        className="px-4 py-2 rounded-xl border-2 border-dashed border-amber-300 text-amber-600
                   text-sm font-semibold hover:bg-amber-50 transition-all"
      >
        + Nova colmeia
      </button>
    </div>
  );
}

// ─── MODAL NOVA COLMEIA ───────────────────────────────────────────────────────
const MAC_REGEX = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;

function ModalNovaColmeia({ onFechar, onCriar }) {
  const [nome,        setNome]        = useState("");
  const [localizacao, setLocalizacao] = useState("");
  const [mac,         setMac]         = useState("");
  const [macErro,     setMacErro]     = useState("");
  const [loading,     setLoading]     = useState(false);

  function handleMacChange(e) {
    const val = e.target.value.toUpperCase();
    setMac(val);
    if (val && !MAC_REGEX.test(val)) {
      setMacErro("Formato inválido. Usa XX:XX:XX:XX:XX:XX");
    } else {
      setMacErro("");
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!nome.trim()) return;
    if (mac && !MAC_REGEX.test(mac)) return;
    setLoading(true);
    await onCriar({ nome, localizacao, mac_address: mac || null });
    setLoading(false);
    onFechar();
  }

  return (
    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <h2 className="text-lg font-bold text-slate-800 mb-4">🐝 Nova Colmeia</h2>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div>
            <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nome</label>
            <input
              value={nome}
              onChange={e => setNome(e.target.value)}
              placeholder="Ex: Colmeia Norte A"
              className="w-full mt-1 px-4 py-3 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
            />
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Localização (opcional)</label>
            <input
              value={localizacao}
              onChange={e => setLocalizacao(e.target.value)}
              placeholder="Ex: Quinta do Vale, Braga"
              className="w-full mt-1 px-4 py-3 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-amber-400"
            />
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              MAC Address do ESP32 (opcional)
            </label>
            <input
              value={mac}
              onChange={handleMacChange}
              placeholder="Ex: 28:05:A5:74:07:8C"
              maxLength={17}
              className={`w-full mt-1 px-4 py-3 rounded-xl border text-sm font-mono focus:outline-none focus:ring-2 focus:ring-amber-400
                ${macErro ? "border-red-300 bg-red-50" : "border-slate-200"}`}
            />
            {macErro && <p className="text-xs text-red-500 mt-1">{macErro}</p>}
            <p className="text-xs text-slate-400 mt-1">
              Encontras o MAC no monitor série do ESP32 ao arrancar.
            </p>
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onFechar}
              className="flex-1 py-3 rounded-xl border border-slate-200 text-slate-600 font-semibold text-sm hover:bg-slate-50">
              Cancelar
            </button>
            <button type="submit" disabled={loading || !!macErro}
              className="flex-1 py-3 rounded-xl bg-amber-500 hover:bg-amber-600 text-white font-bold text-sm disabled:opacity-50">
              {loading ? "A criar..." : "Criar colmeia"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ─── SKELETON ────────────────────────────────────────────────────────────────
function Skeleton() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="bg-white rounded-2xl shadow-md border border-slate-100 p-5 animate-pulse">
          <div className="h-4 w-32 bg-slate-100 rounded mb-4" />
          <div className="flex gap-2 mb-4">
            <div className="h-12 w-24 bg-slate-100 rounded-lg" />
            <div className="h-12 w-24 bg-slate-100 rounded-lg" />
          </div>
          <div className="h-48 bg-slate-50 rounded-xl" />
        </div>
      ))}
    </div>
  );
}

// ─── DASHBOARD PRINCIPAL ──────────────────────────────────────────────────────
export default function Dashboard({ utilizador, onLogout }) {
  const { apiFetch } = useAuth();

  const [colmeias,      setColmeias]      = useState([]);
  const [colmeiaAtiva,  setColmeiaAtiva]  = useState(null);
  const [data,          setData]          = useState([]);
  const [status,        setStatus]        = useState("loading");
  const [lastUpdate,    setLastUpdate]    = useState(null);
  const [erro,          setErro]          = useState(null);
  const [modalAberto,   setModalAberto]   = useState(false);

  // Carregar lista de colmeias
  useEffect(() => {
    async function carregarColmeias() {
      try {
        const res  = await apiFetch("/api/colmeias");
        const json = await res.json();
        setColmeias(json);
        if (json.length > 0) setColmeiaAtiva(json[0]);
      } catch (err) {
        setErro("Não foi possível carregar as colmeias.");
      }
    }
    carregarColmeias();
  }, [apiFetch]);

  // Carregar dados da colmeia ativa (com polling)
  const fetchDados = useCallback(async () => {
    if (!colmeiaAtiva) return;
    try {
      const res  = await apiFetch(`/api/dados/${colmeiaAtiva.id}`);
      const json = await res.json();
      setData(json.map(item => ({ ...item, hora: formatTimestamp(item.timestamp) })));
      setStatus("online");
      setErro(null);
      setLastUpdate(new Date().toLocaleTimeString("pt-PT"));
    } catch (err) {
      setStatus("error");
      setErro("Não foi possível obter dados da colmeia.");
    }
  }, [apiFetch, colmeiaAtiva]);

  useEffect(() => {
    setStatus("loading");
    setData([]);
    fetchDados();
    const interval = setInterval(fetchDados, POLL_INTERVAL);
    return () => clearInterval(interval);
  }, [fetchDados]);

  // Criar nova colmeia
  async function criarColmeia(dados) {
    try {
      const res  = await apiFetch("/api/colmeias", {
        method: "POST",
        body: JSON.stringify(dados),
      });
      const json = await res.json();
      const nova = json.colmeia;
      setColmeias(prev => [...prev, nova]);
      setColmeiaAtiva(nova);
    } catch (err) {
      alert("Erro ao criar colmeia.");
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 font-sans">
      <Header
        status={status}
        lastUpdate={lastUpdate}
        utilizador={utilizador}
        colmeia={colmeiaAtiva?.nome}
        onLogout={onLogout}
      />

      <main className="max-w-screen-xl mx-auto px-4 sm:px-6 py-6 space-y-5">

        {/* Selector de colmeias */}
        {colmeias.length > 0 && (
          <SelectorColmeia
            colmeias={colmeias}
            colmeiaAtiva={colmeiaAtiva}
            onChange={c => { setColmeiaAtiva(c); setData([]); }}
            onNova={() => setModalAberto(true)}
          />
        )}

        {/* Sem colmeias */}
        {colmeias.length === 0 && status !== "loading" && (
          <div className="text-center py-20">
            <p className="text-5xl mb-4">🐝</p>
            <p className="font-semibold text-slate-600 mb-2">Ainda não tens colmeias registadas.</p>
            <button
              onClick={() => setModalAberto(true)}
              className="px-6 py-3 rounded-xl bg-amber-500 text-white font-bold hover:bg-amber-600 transition-all"
            >
              + Adicionar primeira colmeia
            </button>
          </div>
        )}

        {/* Erro */}
        {erro && (
          <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 flex items-start gap-3 text-sm text-red-700">
            <span className="text-lg">⚠️</span>
            <div>
              <p className="font-semibold">Erro</p>
              <p className="text-red-500">{erro}</p>
            </div>
          </div>
        )}

        {/* Skeleton */}
        {data.length === 0 && status === "loading" && colmeiaAtiva && <Skeleton />}

        {/* Sem dados */}
        {data.length === 0 && status !== "loading" && colmeiaAtiva && !erro && (
          <div className="text-center py-20 text-slate-400">
            <p className="text-5xl mb-4">📭</p>
            <p className="font-semibold">Nenhum dado recebido ainda para esta colmeia.</p>
            <p className="text-sm mt-1">O ESP32 ainda não enviou leituras.</p>
          </div>
        )}

        {/* Gráficos */}
        {data.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <ClimaChart    data={data} />
            <PesoChart     data={data} />
            <AtividadeChart data={data} />
            <BateriaChart  data={data} />
          </div>
        )}

        {/* Rodapé */}
        <footer className="text-center text-xs text-slate-300 pt-4 pb-2">
          BeeApp IoT · Polling a cada {POLL_INTERVAL / 1000}s ·{" "}
          <span className="font-medium">{data.length}</span> registos ·{" "}
          {utilizador?.role === "admin" && <span className="text-purple-400 font-semibold">Modo Admin</span>}
        </footer>
      </main>

      {/* Modal nova colmeia */}
      {modalAberto && (
        <ModalNovaColmeia
          onFechar={() => setModalAberto(false)}
          onCriar={criarColmeia}
        />
      )}
    </div>
  );
}
