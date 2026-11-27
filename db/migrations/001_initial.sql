BEGIN;

CREATE SCHEMA learnloop;

CREATE TABLE learnloop.nguoi_dung (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ten_hien_thi text NOT NULL CHECK (btrim(ten_hien_thi) <> ''),
    email text CHECK (email <> '' AND email = btrim(email)),
    so_dien_thoai text,
    anh_dai_dien text,
    tao_luc timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX nguoi_dung_email_idx ON learnloop.nguoi_dung (lower(email));

CREATE TABLE learnloop.dia_diem (
    id text PRIMARY KEY CHECK (id ~ '^[a-z][a-z0-9_]*$'),
    ten text NOT NULL CHECK (btrim(ten) <> ''),
    ten_khac text[] NOT NULL DEFAULT '{}',
    quan text,
    mo_ta text,
    anh text,
    vi_do numeric(8, 6) NOT NULL CHECK (vi_do BETWEEN -90 AND 90),
    kinh_do numeric(9, 6) NOT NULL CHECK (kinh_do BETWEEN -180 AND 180),
    gio_mo time(0) NOT NULL,
    gio_dong time(0) NOT NULL,
    phut_tham_quan smallint NOT NULL CHECK (phut_tham_quan > 0),
    gia_ve_vnd integer NOT NULL CHECK (gia_ve_vnd >= 0),
    tre_em_mien_phi_duoi smallint CHECK (tre_em_mien_phi_duoi BETWEEN 1 AND 18),
    du_lieu_mau boolean NOT NULL DEFAULT true,
    CHECK (gio_mo < gio_dong)
);

CREATE TABLE learnloop.so_thich (
    ma text PRIMARY KEY CHECK (ma ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE learnloop.dia_diem_so_thich (
    dia_diem_id text NOT NULL REFERENCES learnloop.dia_diem ON DELETE CASCADE,
    so_thich_ma text NOT NULL REFERENCES learnloop.so_thich ON DELETE CASCADE,
    PRIMARY KEY (dia_diem_id, so_thich_ma)
);

CREATE INDEX dia_diem_so_thich_ma_idx
    ON learnloop.dia_diem_so_thich (so_thich_ma, dia_diem_id);

CREATE TABLE learnloop.dia_diem_da_luu (
    nguoi_dung_id uuid NOT NULL REFERENCES learnloop.nguoi_dung ON DELETE CASCADE,
    dia_diem_id text NOT NULL REFERENCES learnloop.dia_diem ON DELETE CASCADE,
    luu_luc timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (nguoi_dung_id, dia_diem_id)
);

CREATE INDEX dia_diem_da_luu_dia_diem_idx ON learnloop.dia_diem_da_luu (dia_diem_id);

CREATE TABLE learnloop.chuyen_di (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nguoi_dung_id uuid NOT NULL REFERENCES learnloop.nguoi_dung ON DELETE CASCADE,
    ten text NOT NULL CHECK (btrim(ten) <> ''),
    ngay_bat_dau date NOT NULL CHECK (isfinite(ngay_bat_dau)),
    so_ngay smallint NOT NULL CHECK (so_ngay BETWEEN 1 AND 3),
    ngay_ket_thuc date GENERATED ALWAYS AS (ngay_bat_dau + (so_ngay::integer - 1)) STORED,
    yeu_thich boolean NOT NULL DEFAULT false,
    kha_thi boolean,
    tong_ve_vnd integer CHECK (tong_ve_vnd >= 0),
    ve_moi_nguoi_vnd integer CHECK (ve_moi_nguoi_vnd >= 0),
    taxi_uoc_tinh_vnd integer CHECK (taxi_uoc_tinh_vnd >= 0),
    ghi_chu text[] NOT NULL DEFAULT '{}',
    tao_luc timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, so_ngay)
);

CREATE INDEX chuyen_di_nguoi_dung_ngay_idx
    ON learnloop.chuyen_di (nguoi_dung_id, ngay_ket_thuc);

CREATE TABLE learnloop.ngay_lich_trinh (
    chuyen_di_id uuid NOT NULL,
    so_ngay smallint NOT NULL,
    ngay_thu smallint NOT NULL CHECK (ngay_thu BETWEEN 1 AND so_ngay),
    PRIMARY KEY (chuyen_di_id, ngay_thu),
    FOREIGN KEY (chuyen_di_id, so_ngay) REFERENCES learnloop.chuyen_di (id, so_ngay)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE learnloop.diem_dung (
    chuyen_di_id uuid NOT NULL,
    ngay_thu smallint NOT NULL,
    thu_tu smallint NOT NULL CHECK (thu_tu > 0),
    dia_diem_id text REFERENCES learnloop.dia_diem ON DELETE SET NULL,
    ten_luc_luu text NOT NULL CHECK (btrim(ten_luc_luu) <> ''),
    gio_den time(0),
    buoi text CHECK (buoi IN ('sang', 'trua', 'chieu', 'toi')),
    phut_di_chuyen smallint CHECK (phut_di_chuyen >= 0),
    phut_tham_quan smallint CHECK (phut_tham_quan > 0),
    tien_ve_nhom_vnd integer CHECK (tien_ve_nhom_vnd >= 0),
    ly_do text,
    PRIMARY KEY (chuyen_di_id, ngay_thu, thu_tu),
    FOREIGN KEY (chuyen_di_id, ngay_thu) REFERENCES learnloop.ngay_lich_trinh ON DELETE CASCADE
);

CREATE INDEX diem_dung_dia_diem_idx ON learnloop.diem_dung (dia_diem_id);

CREATE VIEW learnloop.chuyen_di_theo_trang_thai AS
SELECT cd.*,
       CASE WHEN cd.ngay_ket_thuc < (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            THEN 'hoan_thanh' ELSE 'sap_toi' END AS trang_thai
FROM learnloop.chuyen_di AS cd;

COMMIT;
