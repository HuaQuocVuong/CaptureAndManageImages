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
    image_path TEXT NOT NULL UNIQUE,   -- Đường dẫn file ảnh (duy nhất)
    -- Trạng thái xử lý của ảnh
    status TEXT NOT NULL DEFAULT 'captured' CHECK (
        status IN (
            'captured', -- Ảnh vừa chụp xong
            'queued',   -- Đang chờ xử lý
            'processing', -- Đang xử lý
            'ready',    -- Đã xử lý xong, sẵn sàng
            'failed'    -- Xử lý thất bại
        )
    ),
    -- CÁC CỘT METADATA CẦN THÊM
    title TEXT,                 -- Tiêu đề ảnh
    description TEXT,           -- Mô tả ảnh
    price REAL,                 -- Giá sản phẩm trong ảnh (có thể khác giá trong bảng products)
    category TEXT,              -- Danh mục của ảnh
    note TEXT,                  -- Ghi chú cho ảnh
    
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,  -- Thời gian tạo
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,  -- Thời gian cập nhật
    
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);

-- Tạo trigger để tự động cập nhật updated_at
CREATE TRIGGER IF NOT EXISTS update_photos_updated_at 
    AFTER UPDATE ON photos
BEGIN
    UPDATE photos SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_products_updated_at 
    AFTER UPDATE ON products
BEGIN
    UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;