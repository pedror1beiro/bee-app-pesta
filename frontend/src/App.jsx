import { useState, useEffect, useCallback } from "react";
import {
  LineChart, Line, AreaChart, Area,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from "recharts";

// ─── CONFIG ────────────────────────────────────────────────────────────────
const API_URL = "http://localhost:3000/api/dados/1";
const POLL_INTERVAL = 10000; // 10 segundos

// ─── HELPERS ───────────────────────────────────────────────────────────────
function formatTimestamp(ts) {
  try {
    const d = new Date(ts);
    return d.toLocaleTimeString("pt-PT", { hour: "2-digit", minute: "2-digit" });
  } catch {
    return ts;
  }
}

function getLatest(data) {
  return data.length > 0 ? data[data.length - 1] : null;
}

// ─── CUSTOM TOOLTIP ────────────────────────────────────────────────────────
function CustomTooltip({ active, payload, label, unit = "" }) {
  if (!active || !payload || !payload.length) return null;
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-xl p-3 text-sm">
      <p className="text-slate-500 mb-1 font-medium">{label}</p>
      {payload.map((p, i) => (
        <p key={i} style={{ color: p.color }} className="font-semibold">
          {p.name}: {typeof p.value === "number" ? p.value.toFixed(2) : p.value}
          {unit}
        </p>
      ))}
    </div>
  );
}

// ─── STAT BADGE ────────────────────────────────────────────────────────────
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
        {value !== null && value !== undefined ? (typeof value === "number" ? value.toFixed(1) : value) : "—"}
        <span className="text-xs font-normal ml-0.5">{unit}</span>
      </p>
    </div>
  );
}

// ─── CARD ──────────────────────────────────────────────────────────────────
function Card({ title, icon, children, badges }) {
  return (
    <div className="bg-white rounded-2xl shadow-md border border-slate-100 flex flex-col overflow-hidden hover:shadow-lg transition-shadow duration-300">
      <div className="px-5 pt-5 pb-3 flex items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="text-xl">{icon}</span>
          <h2 className="text-sm font-bold text-slate-700 tracking-wide uppercase">{title}</h2>
        </div>
      </div>
      {badges && (
        <div className="px-5 pb-3 flex flex-wrap gap-2">
          {badges}
        </div>
      )}
      <div className="flex-1 px-2 pb-4" style={{ minHeight: 220 }}>
        {children}
      </div>
    </div>
  );
}

// ─── CLIMA INTERNO ─────────────────────────────────────────────────────────
function ClimaChart({ data }) {
  return (
    <Card
      title="Clima Interno"
      icon="🌡️"
      badges={[
        <StatBadge key="t" label="Temperatura" value={getLatest(data)?.temperatura} unit="°C" color="red" />,
        <StatBadge key="h" label="Humidade" value={getLatest(data)?.humidade} unit="%" color="blue" />,
      ]}
    >
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis yAxisId="temp" domain={["auto", "auto"]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis yAxisId="hum" orientation="right" domain={[0, 100]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Line yAxisId="temp" type="monotone" dataKey="temperatura" name="Temp (°C)" stroke="#f97316" strokeWidth={2.5} dot={false} activeDot={{ r: 5 }} />
          <Line yAxisId="hum" type="monotone" dataKey="humidade" name="Humidade (%)" stroke="#3b82f6" strokeWidth={2.5} dot={false} activeDot={{ r: 5 }} />
        </LineChart>
      </ResponsiveContainer>
    </Card>
  );
}

// ─── PESO ──────────────────────────────────────────────────────────────────
function PesoChart({ data }) {
  return (
    <Card
      title="Evolução do Peso"
      icon="⚖️"
      badges={[
        <StatBadge key="p" label="Peso atual" value={getLatest(data)?.peso} unit=" kg" color="green" />,
      ]}
    >
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="pesoGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis domain={["auto", "auto"]} tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip unit=" kg" />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Area type="monotone" dataKey="peso" name="Peso (kg)" stroke="#10b981" strokeWidth={2.5} fill="url(#pesoGrad)" dot={false} activeDot={{ r: 5 }} />
        </AreaChart>
      </ResponsiveContainer>
    </Card>
  );
}

// ─── ATIVIDADE ─────────────────────────────────────────────────────────────
function AtividadeChart({ data }) {
  const latest = getLatest(data);
  const saldo = latest ? latest.entradas_abelhas - latest.saidas_abelhas : 0;
  return (
    <Card
      title="Atividade das Abelhas"
      icon="🐝"
      badges={[
        <StatBadge key="e" label="Entradas" value={latest?.entradas_abelhas} unit="" color="green" />,
        <StatBadge key="s" label="Saídas" value={latest?.saidas_abelhas} unit="" color="red" />,
        <StatBadge key="b" label="Saldo" value={saldo} unit="" color="amber" />,
      ]}
    >
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }} barCategoryGap="35%">
          <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
          <XAxis dataKey="hora" tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <YAxis tick={{ fontSize: 11, fill: "#94a3b8" }} tickLine={false} axisLine={false} />
          <Tooltip content={<CustomTooltip />} />
          <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
          <Bar dataKey="entradas_abelhas" name="Entradas" fill="#10b981" radius={[4, 4, 0, 0]} />
          <Bar dataKey="saidas_abelhas" name="Saídas" fill="#ef4444" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </Card>
  );
}

// ─── BATERIA ───────────────────────────────────────────────────────────────
function BateriaChart({ data }) {
  const latest = getLatest(data);
  const volt = latest?.nivel_bateria;
  const pct = volt ? Math.min(100, Math.max(0, ((volt - 3.0) / (4.2 - 3.0)) * 100)).toFixed(0) : null;
  const bateriaColor = pct >= 60 ? "green" : pct >= 30 ? "amber" : "red";
  return (
    <Card
      title="Diagnóstico de Energia"
      icon="🔋"
      badges={[
        <StatBadge key="v" label="Voltagem" value={volt} unit=" V" color="purple" />,
        <StatBadge key="p" label="Estimativa" value={pct} unit="%" color={bateriaColor} />,
      ]}
    >
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 5, right: 16, left: -10, bottom: 0 }}>
          <defs>
            <linearGradient id="bateriaGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#a855f7" />
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

// ─── HEADER ────────────────────────────────────────────────────────────────
function Header({ status, lastUpdate, colmeiaId }) {
  const statusConfig = {
    online:     { dot: "bg-emerald-400 animate-pulse", label: "Online · A Atualizar", text: "text-emerald-600", bg: "bg-emerald-50 border-emerald-100" },
    loading:    { dot: "bg-amber-400 animate-pulse",   label: "A carregar...",        text: "text-amber-600",   bg: "bg-amber-50 border-amber-100"   },
    error:      { dot: "bg-red-400",                   label: "Sem ligação",          text: "text-red-600",     bg: "bg-red-50 border-red-100"        },
  };
  const s = statusConfig[status] || statusConfig.loading;

  return (
    <header className="bg-white border-b border-slate-100 shadow-sm sticky top-0 z-20">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-400 flex items-center justify-center shadow-md text-xl">🍯</div>
          <div>
            <h1 className="text-lg font-extrabold text-slate-800 leading-tight tracking-tight">
              Monitorização de Colmeias
              <span className="ml-2 text-xs font-semibold bg-slate-100 text-slate-500 rounded-full px-2 py-0.5 align-middle">IoT</span>
            </h1>
            <p className="text-xs text-slate-400 font-medium">Colmeia #{colmeiaId} · Sistema de Monitorização em Tempo Real</p>
          </div>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {lastUpdate && (
            <span className="text-xs text-slate-400">
              Atualizado: <span className="font-semibold text-slate-500">{lastUpdate}</span>
            </span>
          )}
          <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border text-xs font-semibold ${s.bg} ${s.text}`}>
            <span className={`w-2 h-2 rounded-full ${s.dot}`}></span>
            {s.label}
          </div>
        </div>
      </div>
    </header>
  );
}

// ─── ERROR BANNER ──────────────────────────────────────────────────────────
function ErrorBanner({ message }) {
  if (!message) return null;
  return (
    <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 flex items-start gap-3 text-sm text-red-700">
      <span className="text-lg mt-0.5">⚠️</span>
      <div>
        <p className="font-semibold">Erro de ligação</p>
        <p className="text-red-500">{message}</p>
        <p className="text-red-400 text-xs mt-1">A tentar novamente automaticamente em 10 segundos...</p>
      </div>
    </div>
  );
}

// ─── SKELETON ──────────────────────────────────────────────────────────────
function Skeleton() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="bg-white rounded-2xl shadow-md border border-slate-100 p-5 animate-pulse">
          <div className="h-4 w-32 bg-slate-100 rounded mb-4"></div>
          <div className="flex gap-2 mb-4">
            <div className="h-12 w-24 bg-slate-100 rounded-lg"></div>
            <div className="h-12 w-24 bg-slate-100 rounded-lg"></div>
          </div>
          <div className="h-48 bg-slate-50 rounded-xl"></div>
        </div>
      ))}
    </div>
  );
}

// ─── DASHBOARD (MAIN) ──────────────────────────────────────────────────────
export default function Dashboard() {
  const [data, setData] = useState([]);
  const [status, setStatus] = useState("loading");
  const [error, setError] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(null);

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch(API_URL);
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      const json = await res.json();

      // Normaliza e mapeia os dados
      const mapped = json.map((item) => ({
        ...item,
        hora: formatTimestamp(item.timestamp),
      }));

      setData(mapped);
      setStatus("online");
      setError(null);
      setLastUpdate(new Date().toLocaleTimeString("pt-PT"));
    } catch (err) {
      setStatus("error");
      setError(err.message || "Não foi possível ligar ao servidor.");
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, POLL_INTERVAL);
    return () => clearInterval(interval);
  }, [fetchData]);

  return (
    <div className="min-h-screen bg-slate-50 font-sans">
      <Header status={status} lastUpdate={lastUpdate} colmeiaId={1} />

      <main className="max-w-screen-xl mx-auto px-4 sm:px-6 py-6 space-y-5">
        {/* Erro */}
        <ErrorBanner message={error} />

        {/* Skeleton enquanto carrega pela primeira vez */}
        {data.length === 0 && status === "loading" && <Skeleton />}

        {/* Sem dados (mas sem erro) */}
        {data.length === 0 && status !== "loading" && !error && (
          <div className="text-center py-20 text-slate-400">
            <p className="text-5xl mb-4">📭</p>
            <p className="font-semibold">Nenhum dado recebido ainda.</p>
            <p className="text-sm">Verifica se o backend está em execução em <code className="bg-slate-100 px-1 rounded">localhost:3000</code></p>
          </div>
        )}

        {/* Gráficos */}
        {data.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <ClimaChart data={data} />
            <PesoChart data={data} />
            <AtividadeChart data={data} />
            <BateriaChart data={data} />
          </div>
        )}

        {/* Rodapé */}
        <footer className="text-center text-xs text-slate-300 pt-4 pb-2">
          Sistema de Monitorização de Colmeias · Polling a cada {POLL_INTERVAL / 1000}s ·{" "}
          <span className="font-medium">{data.length}</span> registos carregados
        </footer>
      </main>
    </div>
  );
}
