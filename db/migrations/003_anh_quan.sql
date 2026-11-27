BEGIN;

-- Ảnh (tên tệp trong app/assets/images) và quận cho danh mục mẫu; JSON nguồn không có hai trường này.
UPDATE learnloop.dia_diem AS d
SET anh = coalesce(d.anh, v.anh), quan = coalesce(d.quan, v.quan)
FROM (VALUES
    ('lang_bac', 'mausoleum.jpg', 'Ba Đình'),
    ('chua_mot_cot', 'pavilion.jpg', 'Ba Đình'),
    ('hoang_thanh', NULL, 'Ba Đình'),
    ('van_mieu', 'temple.jpg', 'Đống Đa'),
    ('ho_guom', 'lake.jpg', 'Hoàn Kiếm'),
    ('hoa_lo', NULL, 'Hoàn Kiếm'),
    ('dong_xuan', NULL, 'Hoàn Kiếm'),
    ('pho_duong_tau', 'quarter.jpg', 'Hoàn Kiếm'),
    ('tran_quoc', 'pagoda.jpg', 'Tây Hồ'),
    ('bt_dan_toc_hoc', NULL, 'Cầu Giấy'),
    ('pho_di_bo', 'avenue.jpg', 'Hoàn Kiếm'),
    ('nha_hat_lon', NULL, 'Hoàn Kiếm'),
    ('bat_trang', NULL, 'Gia Lâm'),
    ('chua_huong', NULL, 'Mỹ Đức')
) AS v (id, anh, quan)
WHERE d.id = v.id;

COMMIT;
