import { NavLink, Outlet } from "react-router";
import { supabase } from "../lib/supabase";
import "./Layout.css";

const NAV_LINKS = [
  { to: "/", label: "Today" },
  { to: "/recipes", label: "Recipes" },
  { to: "/meal-plan", label: "Meal plan" },
  { to: "/pantry", label: "Pantry" },
  { to: "/grocery-list", label: "Grocery list" },
  { to: "/spending", label: "Spending" },
];

export default function Layout() {
  return (
    <div className="layout">
      <header className="topbar">
        <NavLink to="/" className="brand">
          mise
        </NavLink>
        <nav className="nav" aria-label="Main">
          {NAV_LINKS.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === "/"}
              className={({ isActive }) =>
                isActive ? "nav-link active" : "nav-link"
              }>
              {link.label}
            </NavLink>
          ))}
        </nav>
        <button className="signout" onClick={() => supabase.auth.signOut()}>
          Sign out
        </button>
      </header>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
