-- P0 thu thập dữ liệu dùng thật: người dùng ẩn danh + đồng ý, check-in điểm dừng, sự kiện thao tác.
-- Áp một lần trên DB đã có 001: psql -v ON_ERROR_STOP=1 -d learnloop -f db/migrations/003_hanh_vi.sql
BEGIN;

-- Người dùng ẩn danh theo máy: app tự sinh UUID; chỉ thu sự kiện khi dong_y_thu_thap = true.
ALTER TABLE learnloop.nguoi_dung
    ADD COLUMN an_danh boolean NOT NULL DEFAULT false,
    ADD COLUMN dong_y_thu_thap boolean NOT NULL DEFAULT false,
    ADD COLUMN dong_y_luc timestamptz;

-- Check-in "Đã xong" từng điểm dừng (giờ thực tế, để đo tỉ lệ hoàn thành và độ lệch thời gian).
ALTER TABLE learnloop.diem_dung
    ADD COLUMN xong_luc timestamptz;

-- Sự kiện thao tác. KHÔNG lưu nội dung câu hỏi, KHÔNG lưu toạ độ: du_lieu chỉ là vài trường nhỏ.
CREATE TABLE learnloop.su_kien (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nguoi_dung_id uuid NOT NULL REFERENCES learnloop.nguoi_dung ON DELETE CASCADE,
    chuyen_di_id uuid REFERENCES learnloop.chuyen_di ON DELETE SET NULL,
    loai text NOT NULL CHECK (loai ~ '^[a-z][a-z_]{1,39}$'),
    luc timestamptz NOT NULL,
    nhan_luc timestamptz NOT NULL DEFAULT now(),
    du_lieu jsonb NOT NULL DEFAULT '{}'
        CHECK (jsonb_typeof(du_lieu) = 'object' AND pg_column_size(du_lieu) <= 2048)
);

CREATE INDEX su_kien_loai_luc_idx ON learnloop.su_kien (loai, luc);
CREATE INDEX su_kien_nguoi_dung_luc_idx ON learnloop.su_kien (nguoi_dung_id, luc);

-- Giữ sự kiện tối đa 90 ngày (chạy định kỳ): SELECT learnloop.xoa_su_kien_cu();
CREATE FUNCTION learnloop.xoa_su_kien_cu(so_ngay_giu integer DEFAULT 90) RETURNS bigint
LANGUAGE sql AS $$
    WITH xoa AS (
        DELETE FROM learnloop.su_kien WHERE luc < now() - make_interval(days => so_ngay_giu) RETURNING 1
    )
    SELECT count(*) FROM xoa
$$;

-- Nền cho P1: tỉ lệ hoàn thành theo điểm (chỉ tính chuyến đã kết thúc).
CREATE VIEW learnloop.ti_le_hoan_thanh_diem AS
SELECT dd.dia_diem_id,
       count(*) AS so_lan_xep,
       count(dd.xong_luc) AS so_lan_xong,
       round(count(dd.xong_luc)::numeric / count(*), 3) AS ti_le_xong
FROM learnloop.diem_dung AS dd
JOIN learnloop.chuyen_di AS cd ON cd.id = dd.chuyen_di_id
WHERE dd.dia_diem_id IS NOT NULL
  AND cd.ngay_ket_thuc < (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
GROUP BY dd.dia_diem_id;

COMMIT;
