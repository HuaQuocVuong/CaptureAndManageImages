-- ========== INDEX CHO BẢNG products ==========

-- Index theo tên sản phẩm (tăng tốc tìm kiếm theo tên)
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- Index theo danh mục (tăng tốc lọc theo category)
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Index theo ngày tạo (tăng tốc sắp xếp theo thời gian)
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at);

-- Index tổ hợp cho tìm kiếm nâng cao (tùy chọn)
-- CREATE INDEX IF NOT EXISTS idx_products_name_category ON products(name, category);

-- ========== INDEX CHO BẢNG photos ==========

-- Index theo product_id (tăng tốc JOIN và lấy ảnh của sản phẩm)
CREATE INDEX IF NOT EXISTS idx_photos_product_id ON photos(product_id);

-- Index theo status (tăng tốc lọc theo trạng thái: captured, ready, failed...)
CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(status);

-- Index theo ngày tạo (tăng tốc sắp xếp ảnh theo thời gian)
CREATE INDEX IF NOT EXISTS idx_photos_created_at ON photos(created_at);

-- Index tổ hợp cho tìm kiếm ảnh theo sản phẩm và trạng thái (tùy chọn)
-- CREATE INDEX IF NOT EXISTS idx_photos_product_status ON photos(product_id, status);