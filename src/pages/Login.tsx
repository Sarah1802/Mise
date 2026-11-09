import { useState, type SubmitEvent } from "react";
import { supabase } from "../lib/supabase";
import { useAuth } from "../auth/AuthProvider";
import { Navigate } from "react-router";

export default function Login() {
  const { session } = useAuth();
  const [mode, setMode] = useState<"login" | "signup">("login");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [email, setEmail] = useState("");

  if (session) return <Navigate to="/" replace />;

  async function handleSubmit(e: SubmitEvent<HTMLFormElement>) {
    e.preventDefault();
    setMessage(null);

    const { error } =
      mode === "login"
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password });

    if (error) {
      setMessage(error.message);
    } else if (mode === "signup") {
      setMessage(`A confirmation email has been sent to ${email}`);
    }
  }

  async function signInWithGoogle() {
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin },
    });
  }

  return (
    <main>
      <h1>{mode === "login" ? "Sign in" : "Create Account"}</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Email"
          required
        />
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Password"
          minLength={6}
          required
        />
        <button type="submit">
          {mode === "login" ? "Sign in" : "Sign up"}
        </button>
      </form>
      <button onClick={signInWithGoogle}>Continue with Google</button>
      <button onClick={() => setMode(mode === "login" ? "signup" : "login")}>
        {mode === "login"
          ? "Need an account? Sign up"
          : "Have an account? Sign in"}
      </button>
      {message && <p>{message}</p>}
    </main>
  );
}
