-- Thêm dữ liệu mẫu cho products
INSERT
    OR IGNORE INTO products (name, category, price, note)
VALUES (
        'iPhone 14 Pro Max',
        'Điện thoại',
        28999000,
        'Màu tím deep purple'
    ),
    (
        'Samsung Galaxy S23 Ultra',
        'Điện thoại',
        26999000,
        'Màu đen phantom black'
    ),
    (
        'MacBook Pro 14',
        'Laptop',
        45999000,
        'Chip M2 Pro, 16GB RAM'
    ),
    (
        'iPad Pro 12.9',
        'Máy tính bảng',
        31999000,
        'M2 chip, WiFi + Cellular'
    ),
    (
        'AirPods Pro 2',
        'Phụ kiện',
        6499000,
        'USB-C, Active Noise Cancelling'
    );
-- Thêm dữ liệu mẫu cho photos
INSERT
    OR IGNORE INTO photos (product_id, image_path, status)
VALUES (
        1,
        '/storage/emulated/0/DCIM/iphone14_1.jpg',
        'ready'
    ),
    (
        1,
        '/storage/emulated/0/DCIM/iphone14_2.jpg',
        'ready'
    ),
    (2, '/storage/emulated/0/DCIM/s23_1.jpg', 'ready'),
    (
        3,
        '/storage/emulated/0/DCIM/macbook_1.jpg',
        'ready'
    ),
    (
        NULL,
        '/storage/emulated/0/DCIM/temp_photo_1.jpg',
        'captured'
    ),
    (
        NULL,
        '/storage/emulated/0/DCIM/temp_photo_2.jpg',
        'queued'
    );