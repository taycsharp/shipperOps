"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { clearToken, getMe, getToken, type AuthUser } from "../lib/api";

type AuthContextValue = {
  user: AuthUser | null;
  loading: boolean;
  refreshUser: () => Promise<AuthUser | null>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  async function refreshUser() {
    const token = getToken();
    if (!token) {
      setUser(null);
      setLoading(false);
      return null;
    }
    try {
      const me = await getMe();
      setUser(me);
      return me;
    } catch {
      clearToken();
      setUser(null);
      return null;
    } finally {
      setLoading(false);
    }
  }

  function logout() {
    clearToken();
    setUser(null);
    window.location.href = "/login";
  }

  useEffect(() => {
    void refreshUser();
  }, []);

  const value = useMemo(() => ({ user, loading, refreshUser, logout }), [user, loading]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used inside AuthProvider");
  return context;
}
