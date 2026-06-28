/*
  SIMPLE FIX FOR MENU ITEMS 400 ERROR
  Run this SQL in Supabase SQL Editor
*/

-- 1. First, fix the menu_items table structure
DO $$
BEGIN
  -- Add 'available' column (missing from original create table)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'available'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN available boolean DEFAULT true;
    RAISE NOTICE 'Added "available" column to menu_items';
  ELSE
    RAISE NOTICE '"available" column already exists';
  END IF;
END $$;

-- 2. Ensure all required categories exist
INSERT INTO categories (id, name, icon, sort_order, active) VALUES
  ('hot-coffee', 'Hot Coffee', '☕', 1, true),
  ('iced-coffee', 'Iced Coffee', '🧊', 2, true),
  ('non-coffee', 'Non-Coffee', '🫖', 3, true),
  ('food', 'Food & Pastries', '🥐', 4, true)
ON CONFLICT (id) DO NOTHING;

-- 3. Ensure public/anon can access menu_items (admin dashboard uses anon key)
-- First, drop any restrictive policies
DROP POLICY IF EXISTS "Authenticated users can manage menu items" ON menu_items;

-- Create public read policy
CREATE POLICY IF NOT EXISTS "Public can read menu items"
  ON menu_items
  FOR SELECT
  TO public
  USING (true);

-- Create policy for inserting (admin dashboard needs this)
CREATE POLICY IF NOT EXISTS "Public can insert menu items"
  ON menu_items
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Create policy for updating
CREATE POLICY IF NOT EXISTS "Public can update menu items"
  ON menu_items
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Create policy for deleting
CREATE POLICY IF NOT EXISTS "Public can delete menu items"
  ON menu_items
  FOR DELETE
  TO public
  USING (true);

-- 4. Add a test item to verify everything works
INSERT INTO menu_items (
  name, 
  description, 
  base_price, 
  category, 
  popular, 
  available,
  image_url
) VALUES (
  'Test Coffee',
  'Test item to verify menu works',
  150.00,
  'hot-coffee',
  false,
  true,
  'https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg'
) ON CONFLICT DO NOTHING;

-- 5. Show status
SELECT '✅ Fix completed!' AS message;
SELECT 'Categories count:' AS label, COUNT(*) AS count FROM categories;
SELECT 'Menu items count:' AS label, COUNT(*) AS count FROM menu_items;