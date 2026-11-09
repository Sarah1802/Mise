import { useAuth } from "./AuthProvider";
import { Outlet, Navigate } from "react-router";

export function RequireAuth() {
  const { session, loading } = useAuth();

  if (loading) {
    return <p>loading...</p>;
  }

  return session ? <Outlet /> : <Navigate to="/login" replace />;
}
