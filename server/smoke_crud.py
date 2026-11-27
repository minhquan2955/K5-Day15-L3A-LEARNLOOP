"""Kiểm đăng nhập + CRUD trên stack đang chạy (docker compose up). Tự dọn dữ liệu nó tạo.

python server/smoke_crud.py [http://127.0.0.1:8080]
Cần `docker compose` trong PATH để cấp quyền quản trị cho tài khoản thử và xoá nó khi xong.
"""
import json
import secrets
import subprocess
import sys
import urllib.error
import urllib.request

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080").rstrip("/") + "/api"


def call(method, path, body=None, expect=200, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(BASE + path, method=method, headers=headers,
                                 data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    assert status == expect, "%s %s → %s (cần %s): %s" % (method, path, status, expect, raw.decode())
    return json.loads(raw) if raw else None


def psql(sql):
    subprocess.run(["docker", "compose", "exec", "-T", "db", "psql", "-v", "ON_ERROR_STOP=1", "-q",
                    "-U", "learnloop", "-d", "learnloop", "-c", sql], check=True)


tag = secrets.token_hex(4)
emails = ["smoke-a-%s@example.com" % tag, "smoke-b-%s@example.com" % tag]
try:
    # ---------- đăng ký / đăng nhập ----------
    a = call("POST", "/dang-ky", {"ten_hien_thi": "A", "email": emails[0].upper(), "mat_khau": "mat-khau-a1"}, 201)
    assert a["nguoi_dung"]["email"] == emails[0] and "mat_khau_bam" not in a["nguoi_dung"], a
    call("POST", "/dang-ky", {"ten_hien_thi": "A2", "email": emails[0], "mat_khau": "mat-khau-a1"}, 409)
    call("POST", "/dang-ky", {"ten_hien_thi": "X", "email": "x@y.z", "mat_khau": "ngan"}, 422)
    call("POST", "/dang-nhap", {"email": emails[0], "mat_khau": "sai-mat-khau"}, 401)
    A = call("POST", "/dang-nhap", {"email": emails[0], "mat_khau": "mat-khau-a1"})["token"]
    B = call("POST", "/dang-ky", {"ten_hien_thi": "B", "email": emails[1], "mat_khau": "mat-khau-b1"}, 201)["token"]
    call("GET", "/toi", expect=401)
    call("GET", "/chuyen-di", expect=401, token="token-bia")
    me = call("GET", "/toi", token=A)
    assert me["ten_hien_thi"] == "A" and not me["quan_tri"] and "mat_khau_bam" not in me, me

    # ---------- danh mục (đọc công khai, ghi cần quản trị) ----------
    places = call("GET", "/dia-diem")
    assert any(p["id"] == "ho_guom" and "van_hoa" in p["so_thich"] for p in places), places
    assert "am_thuc" in call("GET", "/so-thich")
    new = {"id": "smoke_%s" % tag, "ten": "Điểm thử", "vi_do": 21.0, "kinh_do": 105.8, "gio_mo": "08:00",
           "gio_dong": "17:00", "phut_tham_quan": 30, "gia_ve_vnd": 0, "so_thich": ["am_thuc"]}
    pid = new["id"]
    call("POST", "/dia-diem", new, 401)
    call("POST", "/dia-diem", new, 403, token=A)
    psql("UPDATE learnloop.nguoi_dung SET quan_tri = true WHERE email = '%s'" % emails[0])
    assert call("POST", "/dia-diem", new, 201, token=A)["so_thich"] == ["am_thuc"]
    call("POST", "/dia-diem", new, 409, token=A)
    upd = {k: v for k, v in new.items() if k != "id"} | {"ten": "Điểm thử 2", "so_thich": ["van_hoa", "lich_su"],
                                                         "wikidata": "Q1"}
    assert call("PUT", "/dia-diem/" + pid, upd, token=A)["so_thich"] == ["lich_su", "van_hoa"]
    call("PUT", "/dia-diem/" + pid, upd | {"so_thich": ["khong_co"]}, 400, token=A)
    call("PUT", "/dia-diem/" + pid, upd | {"gio_mo": "18:00"}, 400, token=A)

    # ---------- đã lưu ----------
    call("PUT", "/da-luu/" + pid, expect=204, token=A)
    call("PUT", "/da-luu/" + pid, expect=204, token=A)
    assert [p["id"] for p in call("GET", "/da-luu", token=A)].count(pid) == 1
    assert call("GET", "/da-luu", token=B) == []
    call("PUT", "/da-luu/khong_co", expect=404, token=A)

    # ---------- chuyến đi ----------
    trip = call("POST", "/chuyen-di", {"ten": "Thử", "ngay_bat_dau": "2026-12-01", "ngay": [
        {"diem_dung": [{"ten_luc_luu": "Hồ Gươm", "dia_diem_id": "ho_guom", "gio_den": "08:00"},
                       {"ten_luc_luu": "Điểm thử", "dia_diem_id": pid, "buoi": "trua"}]},
        {"diem_dung": [{"ten_luc_luu": "Văn Miếu", "buoi": "sang"}]}]}, 201, token=A)
    tid = trip["id"]
    assert trip["so_ngay"] == 2 and trip["ngay_ket_thuc"] == "2026-12-02" and trip["so_diem_dung"] == 3, trip
    assert [t["id"] for t in call("GET", "/chuyen-di", token=A)] == [tid]
    assert call("GET", "/chuyen-di", token=B) == []
    call("GET", "/chuyen-di/" + tid, expect=404, token=B)
    call("PATCH", "/chuyen-di/" + tid, {"ten": "Chiếm"}, 404, token=B)
    call("DELETE", "/chuyen-di/" + tid, expect=404, token=B)
    t = call("PATCH", "/chuyen-di/" + tid, {"ten": "Đổi tên", "yeu_thich": True, "ngay_bat_dau": "2020-01-01"}, token=A)
    assert t["ten"] == "Đổi tên" and t["yeu_thich"] and t["trang_thai"] == "hoan_thanh" and t["so_diem_dung"] == 3, t
    t = call("PATCH", "/chuyen-di/" + tid, {"ngay": [{"diem_dung": [{"ten_luc_luu": "Chỉ một"}]}]}, token=A)
    assert t["so_ngay"] == 1 and t["so_diem_dung"] == 1 and t["ngay"][0]["diem_dung"][0]["thu_tu"] == 1, t
    long_trip = call("POST", "/chuyen-di", {"ten": "Dài ngày", "ngay_bat_dau": "2026-12-01", "ngay": [{}] * 14}, 201,
                     token=A)
    assert long_trip["so_ngay"] == 14 and long_trip["ngay_ket_thuc"] == "2026-12-14", long_trip
    call("DELETE", "/chuyen-di/" + long_trip["id"], expect=204, token=A)
    call("POST", "/chuyen-di", {"ten": "Quá dài", "ngay_bat_dau": "2026-12-01", "ngay": [{}] * 15}, 422, token=A)

    # xoá địa điểm: điểm dừng giữ tên, bỏ liên kết
    call("PATCH", "/chuyen-di/" + tid, {"ngay": [{"diem_dung": [{"ten_luc_luu": "Điểm thử", "dia_diem_id": pid}]}]},
         token=A)
    call("DELETE", "/dia-diem/" + pid, expect=204, token=A)
    stop = call("GET", "/chuyen-di/" + tid, token=A)["ngay"][0]["diem_dung"][0]
    assert stop["dia_diem_id"] is None and stop["ten_luc_luu"] == "Điểm thử", stop
    call("DELETE", "/chuyen-di/" + tid, expect=204, token=A)
    call("GET", "/chuyen-di/" + tid, expect=404, token=A)
    call("GET", "/chuyen-di/khong-phai-uuid", expect=404, token=A)

    # ---------- hồ sơ, đăng xuất ----------
    assert call("PUT", "/toi", {"ten_hien_thi": "A mới", "email": emails[0], "so_dien_thoai": "0900"},
                token=A)["so_dien_thoai"] == "0900"
    call("PUT", "/toi", {"ten_hien_thi": "A", "email": emails[1]}, 409, token=A)  # email của B
    call("PUT", "/toi", {"ten_hien_thi": " ", "email": emails[0]}, 400, token=A)
    call("POST", "/dang-xuat", expect=204, token=A)
    call("GET", "/toi", expect=401, token=A)
    print("AUTH + CRUD OK")
finally:
    psql("DELETE FROM learnloop.dia_diem WHERE id = 'smoke_%s'; DELETE FROM learnloop.nguoi_dung WHERE email IN ('%s', '%s')"
         % (tag, *emails))
