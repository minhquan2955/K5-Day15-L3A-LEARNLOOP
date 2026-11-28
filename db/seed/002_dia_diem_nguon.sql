BEGIN;

-- Nạp thông tin tra sẵn (db/fetch_sources.py → data/dia_diem_nguon.json). Docker gắn tệp vào đường dẫn này.
-- Ghi đè mô tả/ảnh bằng bản có nguồn; trường nào nguồn không có thì giữ giá trị cũ.
UPDATE learnloop.dia_diem AS d
SET wikidata = n.wikidata,
    mo_ta = coalesce(n.mo_ta, d.mo_ta),
    anh = coalesce(n.anh, d.anh),
    anh_ghi_cong = CASE WHEN n.anh IS NULL THEN d.anh_ghi_cong ELSE n.anh_ghi_cong END,
    website = coalesce(n.website, d.website),
    dia_chi = coalesce(n.dia_chi, d.dia_chi),
    gio_mo_cua_osm = coalesce(n.gio_mo_cua_osm, d.gio_mo_cua_osm),
    wikipedia_url = coalesce(n.wikipedia_url, d.wikipedia_url),
    nguon_cap_nhat = (pg_read_file('/seed/dia_diem_nguon.json')::jsonb ->> 'tra_luc')::timestamptz
FROM jsonb_to_recordset((pg_read_file('/seed/dia_diem_nguon.json')::jsonb)->'diem') AS n(
    id text, wikidata text, mo_ta text, anh text, anh_ghi_cong text, website text,
    dia_chi text, gio_mo_cua_osm text, wikipedia_url text
)
WHERE d.id = n.id;

COMMIT;
