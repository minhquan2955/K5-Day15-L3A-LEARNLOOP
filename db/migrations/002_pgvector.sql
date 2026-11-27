BEGIN;

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

CREATE TABLE learnloop.rag_doan (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nguon text NOT NULL CHECK (btrim(nguon) <> ''),
    tieu_de text NOT NULL CHECK (btrim(tieu_de) <> ''),
    thu_tu integer NOT NULL CHECK (thu_tu > 0),
    noi_dung text NOT NULL CHECK (btrim(noi_dung) <> ''),
    dia_diem_id text REFERENCES learnloop.dia_diem ON DELETE CASCADE,
    embedding_model text NOT NULL CHECK (btrim(embedding_model) <> ''),
    embedding public.vector(768) NOT NULL CHECK (public.vector_norm(embedding) > 0),
    UNIQUE (embedding_model, nguon, thu_tu)
);

CREATE INDEX rag_doan_dia_diem_idx ON learnloop.rag_doan (dia_diem_id);
CREATE INDEX rag_doan_cosine_idx ON learnloop.rag_doan
    USING hnsw (embedding public.vector_cosine_ops);

CREATE FUNCTION learnloop.tim_doan_rag(
    p_embedding public.vector, p_model text, p_gioi_han integer DEFAULT 5
)
RETURNS TABLE (
    id bigint, nguon text, tieu_de text, thu_tu integer, noi_dung text,
    dia_diem_id text, khoang_cach_cosine double precision
)
LANGUAGE plpgsql STABLE STRICT
SET hnsw.iterative_scan = 'strict_order'
AS $$
BEGIN
    IF public.vector_dims(p_embedding) <> 768 OR public.vector_norm(p_embedding) = 0 THEN
        RAISE EXCEPTION 'Embedding truy vấn phải có 768 chiều và khác vector 0'
            USING ERRCODE = '22023';
    END IF;
    IF p_gioi_han NOT BETWEEN 1 AND 50 THEN
        RAISE EXCEPTION 'Số đoạn truy xuất phải nằm trong khoảng 1 đến 50'
            USING ERRCODE = '22023';
    END IF;
    RETURN QUERY
    SELECT d.id, d.nguon, d.tieu_de, d.thu_tu, d.noi_dung, d.dia_diem_id,
           d.embedding OPERATOR(public.<=>) p_embedding
    FROM learnloop.rag_doan AS d
    WHERE d.embedding_model = p_model
    ORDER BY d.embedding OPERATOR(public.<=>) p_embedding
    LIMIT p_gioi_han;
END
$$;

COMMIT;
