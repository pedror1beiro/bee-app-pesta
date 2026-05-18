import { useState } from "react";
import { useAuth } from "./AuthContext";

// ─── ÍCONES SVG INLINE ────────────────────────────────────────────────────────
function IconGoogle() {
  return (
    <svg viewBox="0 0 24 24" className="w-5 h-5" xmlns="http://www.w3.org/2000/svg">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  );
}

function IconBee() {
  return <span className="text-4xl select-none">🍯</span>;
}

// ─── INPUT FIELD ──────────────────────────────────────────────────────────────
function InputField({ label, type = "text", value, onChange, placeholder, autoComplete }) {
  const [showPass, setShowPass] = useState(false);
  const isPassword = type === "password";

  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-semibold text-amber-900/70 uppercase tracking-widest">
        {label}
      </label>
      <div className="relative">
        <input
          type={isPassword && showPass ? "text" : type}
          value={value}
          onChange={onChange}
          placeholder={placeholder}
          autoComplete={autoComplete}
          className="w-full px-4 py-3 rounded-xl border border-amber-200 bg-amber-50/50
                     text-slate-800 placeholder-slate-400 text-sm
                     focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent
                     transition-all duration-200"
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setShowPass(p => !p)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-amber-600 transition-colors"
          >
            {showPass ? "🙈" : "👁️"}
          </button>
        )}
      </div>
    </div>
  );
}

// ─── ALERTA DE ERRO/SUCESSO ───────────────────────────────────────────────────
function Alerta({ tipo, mensagem }) {
  if (!mensagem) return null;
  const estilos = {
    erro:   "bg-red-50 border-red-200 text-red-700",
    sucesso: "bg-emerald-50 border-emerald-200 text-emerald-700",
  };
  const icons = { erro: "⚠️", sucesso: "✅" };
  return (
    <div className={`flex items-start gap-2 p-3 rounded-xl border text-sm ${estilos[tipo]}`}>
      <span>{icons[tipo]}</span>
      <p>{mensagem}</p>
    </div>
  );
}

// ─── SEPARADOR ────────────────────────────────────────────────────────────────
function Separador({ texto }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex-1 h-px bg-amber-200" />
      <span className="text-xs text-amber-400 font-medium">{texto}</span>
      <div className="flex-1 h-px bg-amber-200" />
    </div>
  );
}

// ─── FORMULÁRIO DE LOGIN ──────────────────────────────────────────────────────
function FormLogin({ onSucesso, onMudarModo }) {
  const { login, loginGoogle } = useAuth();
  const [email,    setEmail]    = useState("");
  const [password, setPassword] = useState("");
  const [loading,  setLoading]  = useState(false);
  const [erro,     setErro]     = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setErro("");
    setLoading(true);
    try {
      const user = await login(email, password);
      onSucesso(user);
    } catch (err) {
      setErro(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Alerta tipo="erro" mensagem={erro} />

      <InputField
        label="Email"
        type="email"
        value={email}
        onChange={e => setEmail(e.target.value)}
        placeholder="apicultor@exemplo.pt"
        autoComplete="email"
      />
      <InputField
        label="Password"
        type="password"
        value={password}
        onChange={e => setPassword(e.target.value)}
        placeholder="••••••••"
        autoComplete="current-password"
      />

      <button
        type="submit"
        disabled={loading}
        className="w-full py-3 rounded-xl bg-amber-500 hover:bg-amber-600 
                   text-white font-bold text-sm tracking-wide
                   transition-all duration-200 shadow-md hover:shadow-lg
                   disabled:opacity-50 disabled:cursor-not-allowed
                   active:scale-[0.98]"
      >
        {loading ? "A entrar..." : "Entrar"}
      </button>

      <Separador texto="ou continua com" />

      <button
        type="button"
        onClick={() => setErro("Google OAuth: configura o GOOGLE_CLIENT_ID no .env e instala @react-oauth/google")}
        className="w-full py-3 rounded-xl border border-amber-200 bg-white
                   hover:bg-amber-50 text-slate-700 font-semibold text-sm
                   flex items-center justify-center gap-2
                   transition-all duration-200 shadow-sm hover:shadow-md
                   active:scale-[0.98]"
      >
        <IconGoogle />
        Entrar com Google
      </button>

      <p className="text-center text-sm text-slate-500">
        Ainda não tens conta?{" "}
        <button
          type="button"
          onClick={onMudarModo}
          className="text-amber-600 font-semibold hover:underline"
        >
          Criar conta
        </button>
      </p>
    </form>
  );
}

// ─── FORMULÁRIO DE REGISTO ────────────────────────────────────────────────────
function FormRegisto({ onSucesso, onMudarModo }) {
  const { registar } = useAuth();
  const [nome,     setNome]     = useState("");
  const [email,    setEmail]    = useState("");
  const [password, setPassword] = useState("");
  const [confirmar, setConfirmar] = useState("");
  const [loading,  setLoading]  = useState(false);
  const [erro,     setErro]     = useState("");
  const [sucesso,  setSucesso]  = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setErro("");
    if (password !== confirmar) {
      return setErro("As passwords não coincidem.");
    }
    if (password.length < 8) {
      return setErro("A password deve ter pelo menos 8 caracteres.");
    }
    setLoading(true);
    try {
      await registar(nome, email, password);
      setSucesso("Conta criada com sucesso! Podes fazer login agora.");
      setTimeout(() => onMudarModo(), 2000);
    } catch (err) {
      setErro(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <Alerta tipo="erro"    mensagem={erro}   />
      <Alerta tipo="sucesso" mensagem={sucesso} />

      <InputField
        label="Nome completo"
        value={nome}
        onChange={e => setNome(e.target.value)}
        placeholder="João Silva"
        autoComplete="name"
      />
      <InputField
        label="Email"
        type="email"
        value={email}
        onChange={e => setEmail(e.target.value)}
        placeholder="apicultor@exemplo.pt"
        autoComplete="email"
      />
      <InputField
        label="Password"
        type="password"
        value={password}
        onChange={e => setPassword(e.target.value)}
        placeholder="Mínimo 8 caracteres"
        autoComplete="new-password"
      />
      <InputField
        label="Confirmar password"
        type="password"
        value={confirmar}
        onChange={e => setConfirmar(e.target.value)}
        placeholder="Repete a password"
        autoComplete="new-password"
      />

      <button
        type="submit"
        disabled={loading}
        className="w-full py-3 rounded-xl bg-amber-500 hover:bg-amber-600
                   text-white font-bold text-sm tracking-wide
                   transition-all duration-200 shadow-md hover:shadow-lg
                   disabled:opacity-50 disabled:cursor-not-allowed
                   active:scale-[0.98]"
      >
        {loading ? "A criar conta..." : "Criar conta"}
      </button>

      <p className="text-center text-sm text-slate-500">
        Já tens conta?{" "}
        <button
          type="button"
          onClick={onMudarModo}
          className="text-amber-600 font-semibold hover:underline"
        >
          Fazer login
        </button>
      </p>
    </form>
  );
}

// ─── PÁGINA DE LOGIN (COMPONENTE PRINCIPAL) ───────────────────────────────────
export default function LoginPage({ onSucesso }) {
  const [modo, setModo] = useState("login"); // "login" | "registo"

  return (
    <div className="min-h-screen bg-gradient-to-br from-amber-50 via-orange-50 to-yellow-50 flex items-center justify-center p-4">

      {/* Decoração de fundo */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-32 -right-32 w-96 h-96 bg-amber-200/30 rounded-full blur-3xl" />
        <div className="absolute -bottom-32 -left-32 w-96 h-96 bg-orange-200/30 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-yellow-100/20 rounded-full blur-3xl" />
      </div>

      {/* Card principal */}
      <div className="relative w-full max-w-md">
        <div className="bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-amber-100 overflow-hidden">

          {/* Header do card */}
          <div className="bg-gradient-to-r from-amber-500 to-orange-500 px-8 pt-8 pb-6 text-center">
            <div className="w-16 h-16 bg-white/20 backdrop-blur rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-lg">
              <IconBee />
            </div>
            <h1 className="text-2xl font-black text-white tracking-tight">BeeApp</h1>
            <p className="text-amber-100 text-sm mt-1">Sistema Inteligente de Monitorização de Colmeias</p>
          </div>

          {/* Tabs Login / Registo */}
          <div className="flex border-b border-amber-100">
            {["login", "registo"].map(m => (
              <button
                key={m}
                onClick={() => setModo(m)}
                className={`flex-1 py-3 text-sm font-semibold transition-all duration-200
                  ${modo === m
                    ? "text-amber-600 border-b-2 border-amber-500 bg-amber-50/50"
                    : "text-slate-400 hover:text-slate-600"
                  }`}
              >
                {m === "login" ? "Entrar" : "Criar conta"}
              </button>
            ))}
          </div>

          {/* Formulário */}
          <div className="px-8 py-6">
            {modo === "login"
              ? <FormLogin   onSucesso={onSucesso} onMudarModo={() => setModo("registo")} />
              : <FormRegisto onSucesso={onSucesso} onMudarModo={() => setModo("login")}   />
            }
          </div>

          {/* Rodapé */}
          <div className="px-8 pb-6 text-center">
            <p className="text-xs text-slate-300">
              © 2026 BeeApp · Sistema IoT para Apicultura Inteligente
            </p>
          </div>
        </div>

        {/* Credenciais de teste */}
        <div className="mt-4 bg-white/60 backdrop-blur rounded-2xl border border-amber-100 p-4">
          <p className="text-xs font-bold text-amber-700 mb-2">🧪 Credenciais de teste:</p>
          <div className="grid grid-cols-2 gap-2 text-xs text-slate-600">
            <div className="bg-amber-50 rounded-lg p-2">
              <p className="font-semibold text-amber-800">Admin</p>
              <p>admin@beeapp.pt</p>
              <p className="font-mono">password</p>
            </div>
            <div className="bg-amber-50 rounded-lg p-2">
              <p className="font-semibold text-amber-800">Apicultor</p>
              <p>joao@beeapp.pt</p>
              <p className="font-mono">password</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
