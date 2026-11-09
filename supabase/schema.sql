-- =====================================================================
-- Mise — database schema
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run once on a fresh project. (Running it twice will error
-- because the tables already exist.)
-- =====================================================================


-- ============ PROFILES (linked to Supabase Auth) ============
-- Supabase keeps emails/passwords in auth.users. This table holds
-- anything extra about a user and is created automatically on sign-up.
CREATE TABLE profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name');
  RETURN NEW;
END $$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============ GOALS ============
CREATE TABLE user_goals (
  user_id          UUID PRIMARY KEY DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  calories_target  INT,
  protein_g_target NUMERIC(6,1),
  fibre_g_target   NUMERIC(6,1),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============ INGREDIENT CATALOG ============
-- user_id NULL = built-in ingredient everyone can see.
CREATE TABLE ingredients (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  name                    TEXT NOT NULL,
  category                TEXT,
  default_unit            TEXT NOT NULL DEFAULT 'g',
  default_shelf_life_days INT,
  storage                 TEXT CHECK (storage IN ('fridge','freezer','pantry')),
  UNIQUE NULLS NOT DISTINCT (user_id, name)
);

CREATE TABLE ingredient_aliases (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  alias         TEXT NOT NULL,
  UNIQUE NULLS NOT DISTINCT (user_id, alias)
);


-- ============ RECIPES ============
CREATE TABLE recipes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  servings      INT NOT NULL DEFAULT 1 CHECK (servings > 0),
  prep_minutes  INT,
  cook_minutes  INT,
  image_url     TEXT,

  -- Macros are PER SERVING
  calories      INT,
  protein_g     NUMERIC(6,1),
  fibre_g       NUMERIC(6,1),
  carbs_g       NUMERIC(6,1),
  fat_g         NUMERIC(6,1),
  macros_source TEXT NOT NULL DEFAULT 'manual'
                CHECK (macros_source IN ('manual','ai_estimated','ai_edited')),

  source        TEXT NOT NULL DEFAULT 'user' CHECK (source IN ('user','ai_generated')),
  ai_prompt     TEXT,
  is_favourite  BOOLEAN NOT NULL DEFAULT false,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recipe_ingredients (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id     UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity      NUMERIC(10,2),
  unit          TEXT,
  note          TEXT,
  is_optional   BOOLEAN NOT NULL DEFAULT false,
  position      INT NOT NULL DEFAULT 0
);

CREATE TABLE recipe_steps (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id   UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  step_number INT NOT NULL,
  instruction TEXT NOT NULL,
  UNIQUE (recipe_id, step_number)
);


-- ============ TAGS ============
CREATE TABLE tags (
  id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  name    TEXT NOT NULL,
  kind    TEXT CHECK (kind IN ('cuisine','diet','time','other')),
  UNIQUE NULLS NOT DISTINCT (user_id, name)
);

CREATE TABLE recipe_tags (
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  tag_id    UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (recipe_id, tag_id)
);


-- ============ MEAL PLANNING ============
CREATE TABLE meal_plans (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,
  name       TEXT,
  status     TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','finalized')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

CREATE TABLE meal_plan_entries (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id UUID NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
  recipe_id    UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  plan_date    DATE NOT NULL,
  meal_type    TEXT CHECK (meal_type IN ('breakfast','lunch','dinner','snack')),
  servings     NUMERIC(4,1) NOT NULL DEFAULT 1
);


-- ============ GROCERY LIST ============
CREATE TABLE grocery_lists (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  meal_plan_id UUID REFERENCES meal_plans(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE grocery_list_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grocery_list_id UUID NOT NULL REFERENCES grocery_lists(id) ON DELETE CASCADE,
  ingredient_id   UUID REFERENCES ingredients(id),
  custom_name     TEXT,
  quantity_needed NUMERIC(10,2),
  unit            TEXT,
  is_checked      BOOLEAN NOT NULL DEFAULT false
);


-- ============ RECEIPTS & SPENDING ============
CREATE TABLE receipts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  store_name   TEXT,
  purchased_at DATE NOT NULL,
  subtotal     NUMERIC(10,2),
  tax          NUMERIC(10,2),
  total        NUMERIC(10,2) NOT NULL,
  currency     CHAR(3) NOT NULL DEFAULT 'CAD',
  image_url    TEXT,
  parse_status TEXT NOT NULL DEFAULT 'pending'
               CHECK (parse_status IN ('pending','parsed','reviewed','failed')),
  raw_parse    JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE receipt_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id    UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
  raw_text      TEXT NOT NULL,
  ingredient_id UUID REFERENCES ingredients(id),
  quantity      NUMERIC(10,2),
  unit          TEXT,
  line_total    NUMERIC(10,2) NOT NULL,
  is_food       BOOLEAN NOT NULL DEFAULT true
);


-- ============ PANTRY ============
CREATE TABLE pantry_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL DEFAULT auth.uid() REFERENCES profiles(id) ON DELETE CASCADE,
  ingredient_id   UUID NOT NULL REFERENCES ingredients(id),
  receipt_item_id UUID REFERENCES receipt_items(id) ON DELETE SET NULL,
  quantity        NUMERIC(10,2),
  unit            TEXT,
  added_at        DATE NOT NULL DEFAULT CURRENT_DATE,
  expiry_date     DATE,
  expiry_source   TEXT NOT NULL DEFAULT 'estimated'
                  CHECK (expiry_source IN ('estimated','manual')),
  status          TEXT NOT NULL DEFAULT 'available'
                  CHECK (status IN ('available','used_up','discarded')),
  removed_at      TIMESTAMPTZ
);


-- ============ INDEXES ============
CREATE INDEX ON recipes (user_id);
CREATE INDEX ON recipes (user_id, protein_g);
CREATE INDEX ON recipe_ingredients (recipe_id);
CREATE INDEX ON recipe_ingredients (ingredient_id);
CREATE INDEX ON recipe_steps (recipe_id);
CREATE INDEX ON recipe_tags (tag_id);
CREATE INDEX ON meal_plan_entries (meal_plan_id, plan_date);
CREATE INDEX ON grocery_list_items (grocery_list_id);
CREATE INDEX ON receipt_items (receipt_id);
CREATE INDEX ON pantry_items (user_id, status, expiry_date);
CREATE INDEX ON receipts (user_id, purchased_at);


-- ============ ROW-LEVEL SECURITY ============
-- Every table is locked down: users only see and change their own rows.

ALTER TABLE profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_goals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_steps       ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags               ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_tags        ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE grocery_lists      ENABLE ROW LEVEL SECURITY;
ALTER TABLE grocery_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE pantry_items       ENABLE ROW LEVEL SECURITY;

-- Profiles: read/update your own
CREATE POLICY "own profile read"   ON profiles FOR SELECT USING (id = (SELECT auth.uid()));
CREATE POLICY "own profile update" ON profiles FOR UPDATE USING (id = (SELECT auth.uid()));

-- Tables with a user_id column: full access to your own rows
CREATE POLICY "own rows" ON user_goals   FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "own rows" ON recipes      FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "own rows" ON meal_plans   FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "own rows" ON grocery_lists FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "own rows" ON receipts     FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "own rows" ON pantry_items FOR ALL USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- Shared catalogs: read built-in (user_id NULL) + your own; write only your own
CREATE POLICY "read built-in or own" ON ingredients        FOR SELECT USING (user_id IS NULL OR user_id = (SELECT auth.uid()));
CREATE POLICY "write own"            ON ingredients        FOR ALL    USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "read built-in or own" ON ingredient_aliases FOR SELECT USING (user_id IS NULL OR user_id = (SELECT auth.uid()));
CREATE POLICY "write own"            ON ingredient_aliases FOR ALL    USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "read built-in or own" ON tags               FOR SELECT USING (user_id IS NULL OR user_id = (SELECT auth.uid()));
CREATE POLICY "write own"            ON tags               FOR ALL    USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- Child tables: access follows the parent row
CREATE POLICY "via recipe" ON recipe_ingredients FOR ALL
  USING      (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())));

CREATE POLICY "via recipe" ON recipe_steps FOR ALL
  USING      (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())));

CREATE POLICY "via recipe" ON recipe_tags FOR ALL
  USING      (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM recipes r WHERE r.id = recipe_id AND r.user_id = (SELECT auth.uid())));

CREATE POLICY "via meal plan" ON meal_plan_entries FOR ALL
  USING      (EXISTS (SELECT 1 FROM meal_plans m WHERE m.id = meal_plan_id AND m.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM meal_plans m WHERE m.id = meal_plan_id AND m.user_id = (SELECT auth.uid())));

CREATE POLICY "via grocery list" ON grocery_list_items FOR ALL
  USING      (EXISTS (SELECT 1 FROM grocery_lists g WHERE g.id = grocery_list_id AND g.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM grocery_lists g WHERE g.id = grocery_list_id AND g.user_id = (SELECT auth.uid())));

CREATE POLICY "via receipt" ON receipt_items FOR ALL
  USING      (EXISTS (SELECT 1 FROM receipts rc WHERE rc.id = receipt_id AND rc.user_id = (SELECT auth.uid())))
  WITH CHECK (EXISTS (SELECT 1 FROM receipts rc WHERE rc.id = receipt_id AND rc.user_id = (SELECT auth.uid())));


-- ============ VIEWS ============
-- security_invoker = on makes views respect the RLS rules above.

CREATE VIEW daily_totals WITH (security_invoker = on) AS
SELECT mpe.meal_plan_id, mpe.plan_date,
       SUM(r.calories  * mpe.servings) AS calories,
       SUM(r.protein_g * mpe.servings) AS protein_g,
       SUM(r.fibre_g   * mpe.servings) AS fibre_g
FROM meal_plan_entries mpe
JOIN recipes r ON r.id = mpe.recipe_id
GROUP BY mpe.meal_plan_id, mpe.plan_date;

CREATE VIEW recipe_pantry_match WITH (security_invoker = on) AS
SELECT r.id AS recipe_id, r.user_id,
       COUNT(ri.id) FILTER (WHERE NOT ri.is_optional) AS needed,
       COUNT(ri.id) FILTER (WHERE NOT ri.is_optional AND EXISTS (
         SELECT 1 FROM pantry_items p
         WHERE p.user_id = r.user_id AND p.ingredient_id = ri.ingredient_id
           AND p.status = 'available')) AS have
FROM recipes r
JOIN recipe_ingredients ri ON ri.recipe_id = r.id
GROUP BY r.id, r.user_id;

CREATE VIEW monthly_spend WITH (security_invoker = on) AS
SELECT user_id, date_trunc('month', purchased_at)::date AS month,
       SUM(total) AS total_spent, COUNT(*) AS receipt_count
FROM receipts
GROUP BY user_id, date_trunc('month', purchased_at);


-- ============ STARTER DATA ============
-- Built-in tags and ingredients (user_id is NULL because the SQL editor
-- isn't logged in as an app user, so everyone can see these).

INSERT INTO tags (user_id, name, kind) VALUES
  (NULL, 'korean',             'cuisine'),
  (NULL, 'chinese',            'cuisine'),
  (NULL, 'japanese',           'cuisine'),
  (NULL, 'italian',            'cuisine'),
  (NULL, 'mexican',            'cuisine'),
  (NULL, 'gastritis-friendly', 'diet'),
  (NULL, 'high-protein',       'diet'),
  (NULL, 'vegetarian',         'diet'),
  (NULL, 'quick',              'time'),
  (NULL, 'meal-prep',          'time');

INSERT INTO ingredients (user_id, name, category, default_unit, default_shelf_life_days, storage) VALUES
  (NULL, 'chicken breast', 'meat',    'g',     2,   'fridge'),
  (NULL, 'eggs',           'dairy',   'whole', 28,  'fridge'),
  (NULL, 'tofu',           'protein', 'g',     7,   'fridge'),
  (NULL, 'white rice',     'pantry',  'g',     365, 'pantry'),
  (NULL, 'oats',           'pantry',  'g',     365, 'pantry'),
  (NULL, 'spinach',        'produce', 'g',     5,   'fridge'),
  (NULL, 'carrot',         'produce', 'whole', 21,  'fridge'),
  (NULL, 'zucchini',       'produce', 'whole', 7,   'fridge'),
  (NULL, 'green onion',    'produce', 'g',     7,   'fridge'),
  (NULL, 'banana',         'produce', 'whole', 5,   'pantry'),
  (NULL, 'greek yogurt',   'dairy',   'g',     14,  'fridge'),
  (NULL, 'soy sauce',      'pantry',  'ml',    730, 'pantry'),
  (NULL, 'sesame oil',     'pantry',  'ml',    365, 'pantry'),
  (NULL, 'kimchi',         'fermented', 'g',     90,  'fridge');

INSERT INTO ingredient_aliases (user_id, ingredient_id, alias)
SELECT NULL, id, a.alias FROM ingredients i
JOIN (VALUES ('green onion','scallion'), ('green onion','spring onion'),
             ('chicken breast','chicken breasts'), ('eggs','egg')) AS a(name, alias)
  ON i.name = a.name AND i.user_id IS NULL;
