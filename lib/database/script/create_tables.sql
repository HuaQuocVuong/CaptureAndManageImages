CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price REAL,
    note TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER,
    image_path TEXT NOT NULL,    --UNIQUE
    -- Trạng thái xử lý của ảnh
    status TEXT NOT NULL DEFAULT 'captured' CHECK (
        status IN (
            'captured',   -- Ảnh vừa chụp xong
            'queued',     -- Đang chờ xử lý
            'processing', -- Đang xử lý
            'ready',      -- Đã xử lý xong, sẵn sàng
            'failed'      -- Xử lý thất bại
        )
    ),
    -- CÁC CỘT METADATA
    title TEXT,                 -- Tiêu đề ảnh
    description TEXT,           -- Mô tả ảnh
    price REAL,                 -- Giá sản phẩm trong ảnh
    category TEXT,              -- Danh mục của ảnh
    note TEXT,                  -- Ghi chú cho ảnh
    
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);

-- Tạo trigger cho photos (đã thêm FOR EACH ROW)
CREATE TRIGGER IF NOT EXISTS update_photos_updated_at 
    AFTER UPDATE ON photos
    FOR EACH ROW
BEGIN
    UPDATE photos SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

-- Tạo trigger cho products (đã thêm FOR EACH ROW)
--CREATE TRIGGER IF NOT EXISTS update_products_updated_at 
--    AFTER UPDATE ON products
--    FOR EACH ROW
--BEGIN
--    UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
--END;