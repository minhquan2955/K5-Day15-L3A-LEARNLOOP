BEGIN;

-- Chuyến đi dài hơn 3 ngày: nâng trần lên 14 ngày (khớp MAX_TRIP_DAYS trong server/crud.py).
ALTER TABLE learnloop.chuyen_di DROP CONSTRAINT chuyen_di_so_ngay_check;
ALTER TABLE learnloop.chuyen_di ADD CONSTRAINT chuyen_di_so_ngay_check CHECK (so_ngay BETWEEN 1 AND 14);

COMMIT;
