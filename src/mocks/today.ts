// Mock data for the home page. Replace with Supabase queries later.

export type MealType = "breakfast" | "lunch" | "dinner" | "snack";

export type PlannedMeal = {
  id: string;
  mealType: MealType;
  servings: number;
  recipe: {
    id: string;
    title: string;
    tags: string[];
    isFavourite: boolean;
    totalMinutes: number;
    // per serving
    calories: number;
    proteinG: number;
    fibreG: number;
  };
};

export const mockGoals = {
  calories: 2000,
  proteinG: 120,
  fibreG: 30,
};

export const mockTodayMeals: PlannedMeal[] = [
  {
    id: "m1",
    mealType: "breakfast",
    servings: 1,
    recipe: {
      id: "r1",
      title: "Banana oat porridge with Greek yogurt",
      tags: ["gastritis-friendly", "quick"],
      isFavourite: true,
      totalMinutes: 10,
      calories: 380,
      proteinG: 22,
      fibreG: 6,
    },
  },
  {
    id: "m2",
    mealType: "lunch",
    servings: 1,
    recipe: {
      id: "r2",
      title: "Kimchi fried rice with a fried egg",
      tags: ["korean", "quick"],
      isFavourite: false,
      totalMinutes: 20,
      calories: 520,
      proteinG: 24,
      fibreG: 4,
    },
  },
  {
    id: "m3",
    mealType: "dinner",
    servings: 1,
    recipe: {
      id: "r3",
      title: "Ginger chicken & zucchini rice bowl",
      tags: ["high-protein", "gastritis-friendly"],
      isFavourite: true,
      totalMinutes: 35,
      calories: 610,
      proteinG: 45,
      fibreG: 5,
    },
  },
  // No snack planned today, so the home page shows an empty slot.
];
