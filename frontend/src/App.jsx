import { useAuth, AuthProvider } from "./AuthContext";
import LoginPage from "./LoginPage";
import Dashboard from "./Dashboard";

// Componente interno que decide o que mostrar
function AppContent() {
  const { isAutenticado, loading, utilizador, logout } = useAuth();

  // Enquanto verifica a sessão guardada
  if (loading) {
    return (
      <div className="min-h-screen bg-amber-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <span className="text-5xl animate-bounce">🍯</span>
          <p className="text-amber-700 font-semibold text-sm">A carregar...</p>
        </div>
      </div>
    );
  }

  // Não autenticado → mostra login
  if (!isAutenticado) {
    return <LoginPage onSucesso={() => {}} />;
  }

  // Autenticado → mostra dashboard
  return <Dashboard utilizador={utilizador} onLogout={logout} />;
}

// Exportação principal — envolve tudo no AuthProvider
export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}
