-- INDEX cho bảng products
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at);

-- INDEX cho bảng photos
CREATE INDEX IF NOT EXISTS idx_photos_product_id ON photos(product_id);
CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(status);
CREATE INDEX IF NOT EXISTS idx_photos_created_at ON photos(created_at);