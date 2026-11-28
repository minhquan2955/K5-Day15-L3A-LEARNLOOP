BEGIN;

-- Đăng nhập bằng email + mật khẩu; token phiên chỉ lưu dạng băm SHA-256.
ALTER TABLE learnloop.nguoi_dung
    ADD COLUMN mat_khau_bam text,
    ADD COLUMN quan_tri boolean NOT NULL DEFAULT false;

CREATE TABLE learnloop.phien (
    token_bam text PRIMARY KEY,
    nguoi_dung_id uuid NOT NULL REFERENCES learnloop.nguoi_dung ON DELETE CASCADE,
    het_han timestamptz NOT NULL
);

CREATE INDEX phien_nguoi_dung_idx ON learnloop.phien (nguoi_dung_id);

-- Hồ sơ dùng chung tạo trước khi có đăng nhập.
DELETE FROM learnloop.nguoi_dung WHERE id = '00000000-0000-0000-0000-000000000001';

-- Thông tin tra sẵn từ Wikidata, Wikipedia, Wikimedia Commons và OpenStreetMap (xem data/dia_diem_nguon.json).
ALTER TABLE learnloop.dia_diem
    ADD COLUMN wikidata text CHECK (wikidata ~ '^Q[0-9]+$'),
    ADD COLUMN dia_chi text,
    ADD COLUMN website text,
    ADD COLUMN gio_mo_cua_osm text,
    ADD COLUMN wikipedia_url text,
    ADD COLUMN anh_ghi_cong text,
    ADD COLUMN nguon_cap_nhat timestamptz;

COMMIT;
