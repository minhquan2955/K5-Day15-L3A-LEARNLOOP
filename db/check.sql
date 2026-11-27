BEGIN;

DO $$
DECLARE
    chu_so_huu uuid;
    trip uuid;
    hom_nay date := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM learnloop.dia_diem AS d
        JOIN learnloop.dia_diem_so_thich AS t ON t.dia_diem_id = d.id
        WHERE d.id = 'ho_guom' AND d.du_lieu_mau
    ) THEN
        RAISE EXCEPTION 'Thiếu địa điểm mẫu hoặc nhãn sở thích';
    END IF;

    INSERT INTO learnloop.nguoi_dung (ten_hien_thi) VALUES ('Kiểm tra schema')
    RETURNING id INTO chu_so_huu;
    INSERT INTO learnloop.dia_diem_da_luu (nguoi_dung_id, dia_diem_id)
    VALUES (chu_so_huu, 'ho_guom');
    INSERT INTO learnloop.chuyen_di (nguoi_dung_id, ten, ngay_bat_dau, so_ngay, yeu_thich)
    VALUES (chu_so_huu, 'Hà Nội hai ngày', hom_nay - 1, 2, true)
    RETURNING id INTO trip;

    INSERT INTO learnloop.ngay_lich_trinh VALUES (trip, 2, 2);
    INSERT INTO learnloop.diem_dung
        (chuyen_di_id, ngay_thu, thu_tu, dia_diem_id, ten_luc_luu, gio_den, tien_ve_nhom_vnd)
    VALUES (trip, 2, 1, 'ho_guom', 'Hồ Hoàn Kiếm', '08:00', 0);

    BEGIN
        INSERT INTO learnloop.ngay_lich_trinh VALUES (trip, 2, 3);
        RAISE EXCEPTION 'Đã chấp nhận ngày ngoài thời lượng chuyến đi';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO learnloop.dia_diem_da_luu (nguoi_dung_id, dia_diem_id)
        VALUES (chu_so_huu, 'ho_guom');
        RAISE EXCEPTION 'Đã chấp nhận địa điểm lưu trùng';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    BEGIN
        UPDATE learnloop.chuyen_di SET so_ngay = 1 WHERE id = trip;
        RAISE EXCEPTION 'Đã rút ngắn chuyến đi khi vẫn còn ngày thứ hai';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM learnloop.chuyen_di_theo_trang_thai
        WHERE id = trip AND ngay_ket_thuc = hom_nay AND trang_thai = 'sap_toi'
    ) THEN
        RAISE EXCEPTION 'Chuyến đi kết thúc hôm nay phải còn hiệu lực';
    END IF;
    UPDATE learnloop.chuyen_di SET ngay_bat_dau = hom_nay - 2 WHERE id = trip;
    IF NOT EXISTS (
        SELECT 1 FROM learnloop.chuyen_di_theo_trang_thai
        WHERE id = trip AND trang_thai = 'hoan_thanh'
    ) THEN
        RAISE EXCEPTION 'Chuyến đi kết thúc hôm qua phải đã hoàn thành';
    END IF;

    DELETE FROM learnloop.nguoi_dung WHERE id = chu_so_huu;
    IF EXISTS (SELECT 1 FROM learnloop.chuyen_di WHERE id = trip)
       OR EXISTS (SELECT 1 FROM learnloop.ngay_lich_trinh WHERE chuyen_di_id = trip)
       OR EXISTS (SELECT 1 FROM learnloop.diem_dung WHERE chuyen_di_id = trip)
       OR EXISTS (SELECT 1 FROM learnloop.dia_diem_da_luu WHERE nguoi_dung_id = chu_so_huu) THEN
        RAISE EXCEPTION 'Xóa hồ sơ còn để lại dữ liệu phụ thuộc';
    END IF;
END
$$;

ROLLBACK;
