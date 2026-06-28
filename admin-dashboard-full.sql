/*
  ============================================================================
  COMPLETE ADMIN DASHBOARD SQL SCHEMA
  ============================================================================
  This file contains all SQL migrations needed for the admin dashboard
  Combined from all migration files for easy reference and copying
  ============================================================================
*/

-- ============================================================================
-- 1. CREATE MENU MANAGEMENT SYSTEM (20250829160942_green_stream.sql)
-- ============================================================================

-- Create menu_items table
CREATE TABLE IF NOT EXISTS menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  base_price decimal(10,2) NOT NULL,
  category text NOT NULL,
  popular boolean DEFAULT false,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create variations table
CREATE TABLE IF NOT EXISTS variations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create add_ons table
CREATE TABLE IF NOT EXISTS add_ons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price decimal(10,2) NOT NULL DEFAULT 0,
  category text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS for menu tables
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE variations ENABLE ROW LEVEL SECURITY;
ALTER TABLE add_ons ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access to menu
CREATE POLICY "Anyone can read menu items"
  ON menu_items
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can read variations"
  ON variations
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can read add-ons"
  ON add_ons
  FOR SELECT
  TO public
  USING (true);

-- Create policies for authenticated admin access to menu
CREATE POLICY "Authenticated users can manage menu items"
  ON menu_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can manage variations"
  ON variations
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can manage add-ons"
  ON add_ons
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for menu_items
CREATE TRIGGER update_menu_items_updated_at
  BEFORE UPDATE ON menu_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 2. CREATE CATEGORIES MANAGEMENT SYSTEM (20250901005107_calm_pine.sql)
-- ============================================================================

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
  id text PRIMARY KEY,
  name text NOT NULL,
  icon text NOT NULL DEFAULT '☕',
  sort_order integer NOT NULL DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS for categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access to categories
CREATE POLICY "Anyone can read categories"
  ON categories
  FOR SELECT
  TO public
  USING (active = true);

-- Create policies for authenticated admin access to categories
CREATE POLICY "Authenticated users can manage categories"
  ON categories
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for categories
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert existing categories
INSERT INTO categories (id, name, icon, sort_order, active) VALUES
  ('hot-coffee', 'Hot Coffee', '☕', 1, true),
  ('iced-coffee', 'Iced Coffee', '🧊', 2, true),
  ('non-coffee', 'Non-Coffee', '🫖', 3, true),
  ('food', 'Food & Pastries', '🥐', 4, true)
ON CONFLICT (id) DO NOTHING;

-- Add foreign key constraint to menu_items table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'menu_items_category_fkey'
  ) THEN
    ALTER TABLE menu_items 
    ADD CONSTRAINT menu_items_category_fkey 
    FOREIGN KEY (category) REFERENCES categories(id);
  END IF;
END $$;

-- ============================================================================
-- 3. CREATE PAYMENT METHODS MANAGEMENT SYSTEM (20250901125510_floating_sky.sql)
-- ============================================================================

-- Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
  id text PRIMARY KEY,
  name text NOT NULL,
  account_number text NOT NULL,
  account_name text NOT NULL,
  qr_code_url text NOT NULL,
  active boolean DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS for payment_methods
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access to payment methods
CREATE POLICY "Anyone can read active payment methods"
  ON payment_methods
  FOR SELECT
  TO public
  USING (active = true);

-- Create policies for authenticated admin access to payment methods
CREATE POLICY "Authenticated users can manage payment methods"
  ON payment_methods
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for payment_methods
CREATE TRIGGER update_payment_methods_updated_at
  BEFORE UPDATE ON payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default payment methods
INSERT INTO payment_methods (id, name, account_number, account_name, qr_code_url, sort_order, active) VALUES
  ('gcash', 'GCash', '09XX XXX XXXX', 'M&C Bakehouse', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 1, true),
  ('maya', 'Maya (PayMaya)', '09XX XXX XXXX', 'M&C Bakehouse', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 2, true),
  ('bank-transfer', 'Bank Transfer', 'Account: 1234-5678-9012', 'M&C Bakehouse', 'https://images.pexels.com/photos/8867482/pexels-photo-8867482.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 3, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 4. ADD DISCOUNT PRICING AND SITE SETTINGS (20250101000000_add_discount_pricing_and_site_settings.sql)
-- ============================================================================

-- Add discount pricing fields to menu_items table
DO $$
BEGIN
  -- Add discount_price column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_price'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_price decimal(10,2);
  END IF;

  -- Add discount_start_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_start_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_start_date timestamptz;
  END IF;

  -- Add discount_end_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_end_date'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_end_date timestamptz;
  END IF;

  -- Add discount_active column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'menu_items' AND column_name = 'discount_active'
  ) THEN
    ALTER TABLE menu_items ADD COLUMN discount_active boolean DEFAULT false;
  END IF;
END $$;

-- Create site_settings table
CREATE TABLE IF NOT EXISTS site_settings (
  id text PRIMARY KEY,
  value text NOT NULL,
  type text NOT NULL DEFAULT 'text',
  description text,
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS for site_settings
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access to site settings
CREATE POLICY "Anyone can read site settings"
  ON site_settings
  FOR SELECT
  TO public
  USING (true);

-- Create policies for authenticated admin access to site settings
CREATE POLICY "Authenticated users can manage site settings"
  ON site_settings
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create updated_at trigger for site_settings
CREATE TRIGGER update_site_settings_updated_at
  BEFORE UPDATE ON site_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert default site settings
INSERT INTO site_settings (id, value, type, description) VALUES
  ('site_name', 'Beracah Cafe', 'text', 'The name of the cafe/restaurant'),
  ('site_logo', 'https://images.pexels.com/photos/302899/pexels-photo-302899.jpeg?auto=compress&cs=tinysrgb&w=300&h=300&fit=crop', 'image', 'The logo image URL for the site'),
  ('site_description', 'Welcome to Beracah Cafe - Your perfect coffee destination', 'text', 'Short description of the cafe'),
  ('currency', 'PHP', 'text', 'Currency symbol for prices'),
  ('currency_code', 'PHP', 'text', 'Currency code for payments')
ON CONFLICT (id) DO NOTHING;

-- Create function to check if discount is active
CREATE OR REPLACE FUNCTION is_discount_active(
  discount_active boolean,
  discount_start_date timestamptz,
  discount_end_date timestamptz
)
RETURNS boolean AS $$
BEGIN
  -- If discount is not active, return false
  IF NOT discount_active THEN
    RETURN false;
  END IF;
  
  -- If no dates are set, return the discount_active value
  IF discount_start_date IS NULL AND discount_end_date IS NULL THEN
    RETURN discount_active;
  END IF;
  
  -- Check if current time is within the discount period
  RETURN (
    (discount_start_date IS NULL OR now() >= discount_start_date) AND
    (discount_end_date IS NULL OR now() <= discount_end_date)
  );
END;
$$ LANGUAGE plpgsql;

-- Create function to get effective price (discounted or regular)
CREATE OR REPLACE FUNCTION get_effective_price(
  base_price decimal,
  discount_price decimal,
  discount_active boolean,
  discount_start_date timestamptz,
  discount_end_date timestamptz
)
RETURNS decimal AS $$
BEGIN
  -- If discount is active and within date range, return discount price
  IF is_discount_active(discount_active, discount_start_date, discount_end_date) AND discount_price IS NOT NULL THEN
    RETURN discount_price;
  END IF;
  
  -- Otherwise return base price
  RETURN base_price;
END;
$$ LANGUAGE plpgsql;

-- Create index for better performance on discount queries
CREATE INDEX IF NOT EXISTS idx_menu_items_discount_active ON menu_items(discount_active);
CREATE INDEX IF NOT EXISTS idx_menu_items_discount_dates ON menu_items(discount_start_date, discount_end_date);

-- ============================================================================
-- 5. CREATE ORDERS AND ORDER ITEMS TABLES (20260307000000_create_orders_table.sql)
-- ============================================================================

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  contact_number text NOT NULL,
  service_type text NOT NULL CHECK (service_type IN ('pickup', 'delivery')),
  address text,
  landmark text,
  pickup_time text,
  payment_method text NOT NULL,
  reference_number text,
  total_price decimal(10,2) NOT NULL,
  notes text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'preparing', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  menu_item_id uuid REFERENCES menu_items(id) ON DELETE SET NULL,
  name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price decimal(10,2) NOT NULL,
  variation_name text,
  flavor_name text,
  add_ons jsonb DEFAULT '[]'::jsonb,
  total_item_price decimal(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS for orders tables
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Create policies for orders - anyone can create
CREATE POLICY "Anyone can create orders"
  ON orders
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Create policies for authenticated users to manage orders
CREATE POLICY "Authenticated users can manage orders"
  ON orders
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create policies for order_items - anyone can create
CREATE POLICY "Anyone can create order items"
  ON order_items
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Create policies for authenticated users to manage order items
CREATE POLICY "Authenticated users can manage order items"
  ON order_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create trigger for orders updated_at
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 6. ADD UPDATE AND DELETE POLICIES FOR ORDERS (20260308000000_add_orders_update_delete_rls_for_anon.sql)
-- ============================================================================

-- Allow anon users to update orders (for status changes)
CREATE POLICY "Anyone can update orders"
  ON orders
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Allow anon users to delete orders
CREATE POLICY "Anyone can delete orders"
  ON orders
  FOR DELETE
  TO public
  USING (true);

-- Allow anon users to update order items
CREATE POLICY "Anyone can update order items"
  ON order_items
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Allow anon users to delete order items
CREATE POLICY "Anyone can delete order items"
  ON order_items
  FOR DELETE
  TO public
  USING (true);

-- ============================================================================
-- END OF ADMIN DASHBOARD SCHEMA
-- ============================================================================
