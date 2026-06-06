export const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
export const API_SERVER_URL = process.env.INTERNAL_API_URL || API_URL;
export const WS_URL = process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:8000/ws/locations";

const TOKEN_KEY = "shipops_token";
const USER_KEY = "shipops_user";

export type AuthUser = { id: number; name: string; email: string; phone?: string | null; role: "ADMIN" | "DISPATCHER" | "SHIPPER" };
export type LoginResponse = { access_token: string; token_type: string; role: AuthUser["role"]; user_id: number };

export function getToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem(TOKEN_KEY, token);
  document.cookie = `${TOKEN_KEY}=${token}; path=/; max-age=${60 * 60 * 24}; SameSite=Lax`;
}

export function clearToken() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  document.cookie = `${TOKEN_KEY}=; path=/; max-age=0; SameSite=Lax`;
}

function authHeaders(extra?: HeadersInit): HeadersInit {
  const token = getToken();
  return {
    ...(extra || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

function formatApiDetail(detail: unknown): string | null {
  if (!detail) return null;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return detail
      .map((item) => {
        if (!item || typeof item !== "object") return String(item);
        const entry = item as { loc?: unknown[]; msg?: unknown; type?: unknown };
        const location = Array.isArray(entry.loc)
          ? entry.loc.filter((part) => part !== "body").join(".")
          : "";
        const message = typeof entry.msg === "string" ? entry.msg : typeof entry.type === "string" ? entry.type : JSON.stringify(item);
        return location ? `${location}: ${message}` : message;
      })
      .join("; ");
  }
  try {
    return JSON.stringify(detail);
  } catch {
    return String(detail);
  }
}

async function parseApiError(res: Response) {
  try {
    const data = await res.json();
    return formatApiDetail(data?.detail) || `API error: ${res.status}`;
  } catch {
    return `API error: ${res.status}`;
  }
}

export async function apiGet<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { cache: "no-store", headers: authHeaders() });
  if (res.status === 401 && typeof window !== "undefined") {
    clearToken();
    window.location.href = "/login";
  }
  if (!res.ok) throw new Error(await parseApiError(res));
  const data = await res.json();
  return (data && Array.isArray(data.items) ? data.items : data) as T;
}

export async function apiPost<T = unknown>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: "POST",
    headers: authHeaders({ "Content-Type": "application/json" }),
    body: JSON.stringify(body),
  });
  if (res.status === 401 && typeof window !== "undefined") {
    clearToken();
    window.location.href = "/login";
  }
  if (!res.ok) throw new Error(await parseApiError(res));
  return res.json();
}

export async function apiPut<T = unknown>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: "PUT",
    headers: authHeaders({ "Content-Type": "application/json" }),
    body: JSON.stringify(body),
  });
  if (res.status === 401 && typeof window !== "undefined") {
    clearToken();
    window.location.href = "/login";
  }
  if (!res.ok) throw new Error(await parseApiError(res));
  return res.json();
}

export async function apiDelete(path: string): Promise<void> {
  const res = await fetch(`${API_URL}${path}`, { method: "DELETE", headers: authHeaders() });
  if (res.status === 401 && typeof window !== "undefined") {
    clearToken();
    window.location.href = "/login";
  }
  if (!res.ok) throw new Error(await parseApiError(res));
}

export async function apiUpload<T = unknown>(path: string, formData: FormData): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { method: "POST", headers: authHeaders(), body: formData });
  if (!res.ok) throw new Error(await parseApiError(res));
  return res.json();
}

export async function login(email: string, password: string) {
  const result = await apiPost<LoginResponse>("/auth/login", { email, password });
  setToken(result.access_token);
  return result;
}

export async function getMe() {
  return apiGet<AuthUser>("/auth/me");
}
