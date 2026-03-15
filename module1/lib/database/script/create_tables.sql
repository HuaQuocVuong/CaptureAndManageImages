-- Bảng lưu trữ thông tin Sản phẩm (Products)

-- Quản lý danh mục và thông tin gốc của sản phẩm
CREATE TABLE IF NOT EXISTS products (
    -- Khóa chính tự tăng, định danh duy nhất cho mỗi sản phẩm
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- Tên và danh mục là bắt buộc (NOT NULL)
    name TEXT NOT NULL,
    category TEXT NOT NULL,

    -- Giá trị số thực (REAL) để lưu giá tiền gốc của sản phẩm
    price REAL,
    note TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- Bảng lưu trữ thông tin Ảnh và Metadata đi kèm (Photos)
-- Kết nối ảnh với sản phẩm và lưu trữ trạng thái xử lý
CREATE TABLE IF NOT EXISTS photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- Khóa ngoại liên kết với bảng products
    product_id INTEGER,
    -- Đường dẫn ảnh phải duy nhất (UNIQUE) để tránh trùng lặp file
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
    -- Ràng buộc khóa ngoại
    -- ON DELETE CASCADE - Nếu xóa sản phẩm, tất cả ảnh liên quan sẽ tự động bị xóa.
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);
-- Đảm bảo cột updated_at luôn phản ánh thời gian chỉnh sửa mới nhất mà không cần can thiệp bằng code ứng dụng
-- Trigger cho bảng Photos
CREATE TRIGGER IF NOT EXISTS update_photos_updated_at 
    AFTER UPDATE ON photos
BEGIN
    UPDATE photos SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger cho bảng Products
CREATE TRIGGER IF NOT EXISTS update_products_updated_at 
    AFTER UPDATE ON products
BEGIN
    UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;