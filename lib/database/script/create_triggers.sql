-- TRIGGER cho bảng products
CREATE TRIGGER IF NOT EXISTS update_products_timestamp 

-- Kích hoạt SAU KHI cập nhật bảng products
AFTER UPDATE ON products
BEGIN
    -- Cập nhật trường updated_at của bản ghi vừa được sửa thành thời gian hiện tại
    UPDATE products SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- TRIGGER cho bảng photos
CREATE TRIGGER IF NOT EXISTS update_photos_timestamp 
AFTER UPDATE ON photos  -- Kích hoạt SAU KHI cập nhật bảng photos
BEGIN
-- Cập nhật trường updated_at của bản ghi vừa được sửa thành thời gian hiện tại
    UPDATE photos SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;