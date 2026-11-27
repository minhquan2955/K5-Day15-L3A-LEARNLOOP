BEGIN;

DO $$
DECLARE
    query_vec vector := array_prepend(1::real, array_fill(0::real, ARRAY[767]))::vector;
    far_vec vector := array_prepend(0::real, array_prepend(1::real, array_fill(0::real, ARRAY[766])))::vector;
    zero_vec vector := array_fill(0::real, ARRAY[768])::vector;
BEGIN
    INSERT INTO learnloop.rag_doan (nguon, tieu_de, thu_tu, noi_dung, dia_diem_id, embedding_model, embedding)
    VALUES ('urn:learnloop:check-rag', 'Hồ Hoàn Kiếm', 1, 'Đoạn mẫu gần', 'ho_guom', 'check-rag-a', query_vec),
           ('urn:learnloop:check-rag', 'Văn Miếu', 2, 'Đoạn mẫu xa', 'van_mieu', 'check-rag-a', far_vec),
           ('urn:learnloop:check-rag', 'Model khác', 3, 'Đoạn mẫu cùng vector', NULL, 'check-rag-b', query_vec);

    IF (SELECT array_agg(r.thu_tu) FROM learnloop.tim_doan_rag(query_vec, 'check-rag-a', 5) AS r)
       IS DISTINCT FROM ARRAY[1, 2] THEN
        RAISE EXCEPTION 'Kết quả sai thứ tự cosine hoặc bị lẫn model';
    END IF;
    IF (SELECT count(*) FROM learnloop.tim_doan_rag(query_vec, 'check-rag-a', 1)) <> 1 THEN
        RAISE EXCEPTION 'Giới hạn số đoạn không được áp dụng';
    END IF;
    BEGIN
        PERFORM learnloop.tim_doan_rag('[1,2]'::vector, 'check-rag-a', 5);
        RAISE EXCEPTION 'Truy vấn chấp nhận sai số chiều';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        INSERT INTO learnloop.rag_doan (nguon, tieu_de, thu_tu, noi_dung, embedding_model, embedding)
        VALUES ('urn:learnloop:check-rag', 'Vector 0', 4, 'Đoạn mẫu không hợp lệ', 'check-rag-a', zero_vec);
        RAISE EXCEPTION 'Kho embedding chấp nhận vector 0';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END
$$;

ROLLBACK;
