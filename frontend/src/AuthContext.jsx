import { createContext, useContext, useState, useEffect, useCallback } from "react";

const AuthContext = createContext(null);

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:3000";

export function AuthProvider({ children }) {
  const [utilizador, setUtilizador] = useState(null);
  const [accessToken, setAccessToken] = useState(null);
  const [loading, setLoading] = useState(true);

  // Ao arrancar, tenta restaurar sessão do localStorage
  useEffect(() => {
    const token     = localStorage.getItem("accessToken");
    const refresh   = localStorage.getItem("refreshToken");
    const userData  = localStorage.getItem("utilizador");

    if (token && userData) {
      setAccessToken(token);
      setUtilizador(JSON.parse(userData));
    }
    setLoading(false);
  }, []);

  // Guardar sessão
  function guardarSessao(data) {
    localStorage.setItem("accessToken",  data.accessToken);
    localStorage.setItem("refreshToken", data.refreshToken);
    localStorage.setItem("utilizador",   JSON.stringify(data.utilizador));
    setAccessToken(data.accessToken);
    setUtilizador(data.utilizador);
  }

  // Login com email + password
  async function login(email, password) {
    const res = await fetch(`${API_BASE}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.erro || "Erro ao fazer login.");
    guardarSessao(data);
    return data.utilizador;
  }

  // Registar nova conta
  async function registar(nome, email, password) {
    const res = await fetch(`${API_BASE}/api/auth/registar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome, email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.erro || data.erros?.[0]?.msg || "Erro ao criar conta.");
    return data;
  }

  // Login com Google
  async function loginGoogle(idToken) {
    const res = await fetch(`${API_BASE}/api/auth/google`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.erro || "Erro ao fazer login com Google.");
    guardarSessao(data);
    return data.utilizador;
  }

  // Logout
  async function logout() {
    const refreshToken = localStorage.getItem("refreshToken");
    try {
      await fetch(`${API_BASE}/api/auth/logout`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken }),
      });
    } catch (_) {}
    localStorage.removeItem("accessToken");
    localStorage.removeItem("refreshToken");
    localStorage.removeItem("utilizador");
    setAccessToken(null);
    setUtilizador(null);
  }

  // Fetch autenticado (com token no header)
  const apiFetch = useCallback(async (url, options = {}) => {
    const token = localStorage.getItem("accessToken");
    const res = await fetch(`${API_BASE}${url}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        ...options.headers,
      },
    });

    // Token expirado → tenta renovar
    if (res.status === 403) {
      const refreshToken = localStorage.getItem("refreshToken");
      const refreshRes = await fetch(`${API_BASE}/api/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken }),
      });
      if (refreshRes.ok) {
        const { accessToken: novoToken } = await refreshRes.json();
        localStorage.setItem("accessToken", novoToken);
        setAccessToken(novoToken);
        // Repete o pedido original com o novo token
        return fetch(`${API_BASE}${url}`, {
          ...options,
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${novoToken}`,
            ...options.headers,
          },
        });
      } else {
        await logout();
        throw new Error("Sessão expirada. Por favor faz login novamente.");
      }
    }
    return res;
  }, []);

  return (
    <AuthContext.Provider value={{
      utilizador,
      accessToken,
      loading,
      login,
      registar,
      loginGoogle,
      logout,
      apiFetch,
      isAdmin: utilizador?.role === "admin",
      isAutenticado: !!utilizador,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth deve ser usado dentro de <AuthProvider>");
  return ctx;
}
