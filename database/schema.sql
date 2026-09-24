--
-- Schema de la tabla posts_bluesky (sin datos)
-- Extraído de database/backup_con_datos.sql
--

CREATE TABLE public.posts_bluesky (
    id integer NOT NULL,
    post_uri text,
    post_cid text,
    texto text,
    autor_handle text,
    autor_display_name text,
    fecha_creacion timestamp without time zone,
    fecha_indexado timestamp without time zone,
    likes integer,
    reposts integer,
    replies integer,
    quotes integer,
    engagement_score numeric,
    fuente_dominio text,
    es_bridged boolean,
    keyword_busqueda text,
    fecha_insercion timestamp without time zone DEFAULT now(),
    pais text,
    posible_falso_positivo_geografico boolean DEFAULT false,
    pagina_recoleccion integer
);

CREATE SEQUENCE public.posts_bluesky_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.posts_bluesky_id_seq OWNED BY public.posts_bluesky.id;

ALTER TABLE ONLY public.posts_bluesky ALTER COLUMN id SET DEFAULT nextval('public.posts_bluesky_id_seq'::regclass);

ALTER TABLE ONLY public.posts_bluesky
    ADD CONSTRAINT posts_bluesky_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.posts_bluesky
    ADD CONSTRAINT posts_bluesky_post_uri_key UNIQUE (post_uri);
