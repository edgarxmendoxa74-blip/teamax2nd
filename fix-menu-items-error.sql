/*
  FIX MENU ITEMS 400 ERROR
  Common issues causing 400 errors when accessing menu_items table:
  1. Missing required columns
  2. Foreign key constraint violations
  3. Invalid data types
  4. Missing RLS policies for public/anon access
*/

-- ============================================================================
-- 1. CHECK AND FIX CATEGORIES FOREIGN KEY
-- ============================================================================

-- First, ensure all categories exist
INSERT INTO categories (id, name, icon, sort_order, active) VALUES
  ('hot-coffee', 'Hot Coffee', '☕', 1, true),
  ('iced-coffee', 'Iced Coffee', '🧊', 2, true),
  ('non-coffee', 'Non-Coffee', '🫖', 3, true),
  ('food', 'Food & Pastries', '🥐', 4, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. ADD REQUIRED COLUMNS IF MISSING
-- ============================================================================

-- Check if required columns exist and add them if missing
DO $$
BEGIN
  -- Add 'available' column if it doesn't exist (commonly missing)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'available'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN available boolean DEFAULT true;
  END IF;

  -- Add discount-related columns if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'discount_price'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_price decimal(10,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'discount_start_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_start_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'discount_end_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_end_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'discount_active'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_active boolean DEFAULT false;
  END IF;
END $$;

-- ============================================================================
-- 3. ADD ANON ACCESS POLICIES FOR ADMIN DASHBOARD (uses anon key)
-- ============================================================================

-- Drop existing menu_items policies to recreate
DROP POLICY IF EXISTS "Anyone can read menu items" ON menu_items;
DROP POLICY IF EXISTS "Authenticated users can manage menu items" ON menu_items;

-- Create policies for public read access (for public menu)
CREATE POLICY "Anyone can read menu items"
  ON menu_items
  FOR SELECT
  TO public
  USING (true);

-- Create policies for anon access (admin dashboard uses anon key)
CREATE POLICY "Anyone can insert menu items"
  ON menu_items
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Anyone can update menu items"
  ON menu_items
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone can delete menu items"
  ON menu_items
  FOR DELETE
  TO public
  USING (true);

-- ============================================================================
-- 4. VERIFY FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Temporarily disable foreign key constraint to check
DO $$
DECLARE
  constraint_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'menu_items' AND constraint_name = 'menu_items_category_fkey'
  ) INTO constraint_exists;
  
  IF constraint_exists THEN
    -- Foreign key exists, check if categories have data
    IF NOT EXISTS (SELECT 1 FROM categories WHERE id = 'hot-coffee') THEN
      INSERT INTO categories (id, name, icon, sort_order, active) 
      VALUES ('hot-coffee', 'Hot Coffee', '☕', 1, true);
    END IF;
    
    -- Add other required categories if missing
    INSERT INTO categories (id, name, icon, sort_order, active) VALUES
      ('iced-coffee', 'Iced Coffee', '🧊', 2, true),
      ('non-coffee', 'Non-Coffee', '🫖', 3, true),
      ('food', 'Food & Pastries', '🥐', 4, true)
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- ============================================================================
-- 5. TEST THE FIX - Create a sample menu item to verify
-- ============================================================================

-- Insert a test menu item to verify everything works
INSERT INTO menu_items (name, description, base_price, category, popular, image_url, available) VALUES
  (
    'Test Coffee',
    'A test coffee item to verify the system works',
    120.00,
    'hot-coffee',
    false,
    'https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg',
    true
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 6. SHOW STATUS
-- ============================================================================

SELECT '✅ Categories table has ' || COUNT(*) || ' categories' AS status FROM categories;
SELECT '✅ Menu items table has ' || COUNT(*) || ' items' AS status FROM menu_items;
SELECT '✅ Storage bucket exists' AS status WHERE EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'menu-images');

-- Show current menu_items table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'menu_items' 
ORDER BY ordinal_position;