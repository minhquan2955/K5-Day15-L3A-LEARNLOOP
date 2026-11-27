BEGIN;

-- Docker gắn tệp nguồn vào đường dẫn này khi khởi tạo PostgreSQL local.
CREATE TEMP TABLE poi_mau ON COMMIT DROP AS
SELECT diem.*
FROM jsonb_to_recordset((pg_read_file('/seed/hanoi_poi.json')::jsonb)->'diem') AS diem(
    id text, ten text, ten_khac text[], lat numeric, lon numeric,
    mo time, dong time, phut_tham_quan smallint, gia_ve integer,
    tre_em_mien_phi_duoi smallint, so_thich text[]
);

INSERT INTO learnloop.dia_diem (
    id, ten, ten_khac, vi_do, kinh_do, gio_mo, gio_dong,
    phut_tham_quan, gia_ve_vnd, tre_em_mien_phi_duoi, du_lieu_mau
)
SELECT id, ten, coalesce(ten_khac, '{}'), lat, lon, mo, dong,
       phut_tham_quan, gia_ve, tre_em_mien_phi_duoi, true
FROM poi_mau
ON CONFLICT (id) DO NOTHING;

INSERT INTO learnloop.so_thich (ma)
SELECT DISTINCT tag.ma FROM poi_mau CROSS JOIN LATERAL unnest(so_thich) AS tag(ma)
ON CONFLICT (ma) DO NOTHING;

INSERT INTO learnloop.dia_diem_so_thich (dia_diem_id, so_thich_ma)
SELECT poi_mau.id, tag.ma FROM poi_mau CROSS JOIN LATERAL unnest(so_thich) AS tag(ma)
ON CONFLICT (dia_diem_id, so_thich_ma) DO NOTHING;

COMMIT;
