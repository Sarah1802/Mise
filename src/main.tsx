import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes } from "react-router";
import { AuthProvider } from "./auth/AuthProvider.tsx";
import { RequireAuth } from "./auth/RequireAuth.tsx";
import Layout from "./components/Layout.tsx";
import Login from "./pages/Login.tsx";
import Home from "./pages/Home.tsx";
import Recipes from "./pages/Recipes.tsx";
import MealPlan from "./pages/MealPlan.tsx";
import Pantry from "./pages/Pantry.tsx";
import GroceryList from "./pages/GroceryList.tsx";
import Spending from "./pages/Spending.tsx";

import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<RequireAuth />}>
            <Route element={<Layout />}>
              <Route path="/" element={<Home />} />
              <Route path="/recipes" element={<Recipes />} />
              <Route path="/meal-plan" element={<MealPlan />} />
              <Route path="/pantry" element={<Pantry />} />
              <Route path="/grocery-list" element={<GroceryList />} />
              <Route path="/spending" element={<Spending />} />
            </Route>
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  </StrictMode>,
);
