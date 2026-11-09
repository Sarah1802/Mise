import { Link } from "react-router";
import {
  mockGoals,
  mockTodayMeals,
  type MealType,
  type PlannedMeal,
} from "../mocks/today";
import "./Home.css";

const MEAL_ORDER: MealType[] = ["breakfast", "lunch", "dinner", "snack"];

const MEAL_LABELS: Record<MealType, string> = {
  breakfast: "Breakfast",
  lunch: "Lunch",
  dinner: "Dinner",
  snack: "Snack",
};

function greeting(hour: number) {
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

export default function Home() {
  const now = new Date();
  const dateLabel = now.toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  const totals = mockTodayMeals.reduce(
    (sum, m) => ({
      calories: sum.calories + m.recipe.calories * m.servings,
      proteinG: sum.proteinG + m.recipe.proteinG * m.servings,
      fibreG: sum.fibreG + m.recipe.fibreG * m.servings,
    }),
    { calories: 0, proteinG: 0, fibreG: 0 },
  );

  return (
    <div className="home">
      <header className="home-header">
        <p className="home-date">{dateLabel}</p>
        <h1>{greeting(now.getHours())}</h1>
      </header>

      <section className="totals" aria-label="Today's totals">
        <TotalCard label="Calories" value={totals.calories} goal={mockGoals.calories} unit="kcal" />
        <TotalCard label="Protein" value={totals.proteinG} goal={mockGoals.proteinG} unit="g" />
        <TotalCard label="Fibre" value={totals.fibreG} goal={mockGoals.fibreG} unit="g" />
      </section>

      <section className="meals">
        <div className="section-head">
          <h2>Today's meals</h2>
          <Link to="/meal-plan" className="text-link">
            View full week →
          </Link>
        </div>

        <ul className="meal-list">
          {MEAL_ORDER.map((type) => {
            const meal = mockTodayMeals.find((m) => m.mealType === type);
            return (
              <li key={type}>
                {meal ? <MealCard meal={meal} /> : <EmptySlot type={type} />}
              </li>
            );
          })}
        </ul>
      </section>
    </div>
  );
}

function TotalCard({
  label,
  value,
  goal,
  unit,
}: {
  label: string;
  value: number;
  goal: number;
  unit: string;
}) {
  const pct = Math.min(100, Math.round((value / goal) * 100));
  return (
    <div className="total-card">
      <p className="total-label">{label}</p>
      <p className="total-value">
        {value.toLocaleString()}
        <span className="total-goal">
          {" "}
          / {goal.toLocaleString()} {unit}
        </span>
      </p>
      <div
        className="bar"
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${label}: ${pct}% of goal`}>
        <div className="bar-fill" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function MealCard({ meal }: { meal: PlannedMeal }) {
  const { recipe, servings } = meal;
  return (
    <article className="meal-card">
      <p className="meal-type">{MEAL_LABELS[meal.mealType]}</p>
      <h3 className="meal-title">
        {recipe.title}
        {recipe.isFavourite && (
          <span className="fav" aria-label="Favourite" title="Favourite">
            ★
          </span>
        )}
      </h3>
      <ul className="tags">
        {recipe.tags.map((tag) => (
          <li key={tag} className="tag">
            {tag}
          </li>
        ))}
      </ul>
      <p className="meal-stats">
        <span>{recipe.calories * servings} kcal</span>
        <span>{recipe.proteinG * servings}g protein</span>
        <span>{recipe.totalMinutes} min</span>
      </p>
    </article>
  );
}

function EmptySlot({ type }: { type: MealType }) {
  return (
    <div className="meal-card empty">
      <p className="meal-type">{MEAL_LABELS[type]}</p>
      <p className="empty-text">Nothing planned</p>
      <Link to="/meal-plan" className="text-link">
        + Add a recipe
      </Link>
    </div>
  );
}
