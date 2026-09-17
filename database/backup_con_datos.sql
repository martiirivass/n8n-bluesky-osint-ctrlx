--
-- PostgreSQL database dump
--

\restrict smnIpX1gTPQAyqg85ZljCviwEpYf4hDgmWpVsqt2K5GEVH1GCNGXYB0QM95OODA

-- Dumped from database version 18.3 (Debian 18.3-1.pgdg13+1)
-- Dumped by pg_dump version 18.3 (Debian 18.3-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: posts_bluesky; Type: TABLE; Schema: public; Owner: osint
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
    fecha_insercion timestamp without time zone DEFAULT now()
);


ALTER TABLE public.posts_bluesky OWNER TO osint;

--
-- Name: posts_bluesky_id_seq; Type: SEQUENCE; Schema: public; Owner: osint
--

CREATE SEQUENCE public.posts_bluesky_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.posts_bluesky_id_seq OWNER TO osint;

--
-- Name: posts_bluesky_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: osint
--

ALTER SEQUENCE public.posts_bluesky_id_seq OWNED BY public.posts_bluesky.id;


--
-- Name: posts_bluesky id; Type: DEFAULT; Schema: public; Owner: osint
--

ALTER TABLE ONLY public.posts_bluesky ALTER COLUMN id SET DEFAULT nextval('public.posts_bluesky_id_seq'::regclass);


--
-- Data for Name: posts_bluesky; Type: TABLE DATA; Schema: public; Owner: osint
--

COPY public.posts_bluesky (id, post_uri, post_cid, texto, autor_handle, autor_display_name, fecha_creacion, fecha_indexado, likes, reposts, replies, quotes, engagement_score, fuente_dominio, es_bridged, keyword_busqueda, fecha_insercion) FROM stdin;
1	at://did:plc:rcwcpm36224xrzvnkymyktgs/app.bsky.feed.post/3mujgixxp6w2j	bafyreiefbegqnbgp6wbb62tjlro36ihrk6iqjwk4aq3qaspa6vjccxhwhm	Argentina moderniza su defensa para enfrentar amenazas no convencionales y asegurar su soberanía regional\n\n🤖 IA: No es clickbait ✅\n👥 Usuarios: No es clickbait ✅\n\n#defensanacional #ciberseguridad #soberanía \n\n👇👇👇:	killbaitargentina.bsky.social	KillBait Argentina 🇦🇷	2026-09-02 07:38:08.656	2026-09-02 07:38:09.203	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-03 14:01:02.436869
0	at://did:plc:qvlourjmpwpq7bfzwmsdnb6c/app.bsky.feed.post/3muyglyd2u426	bafyreicycvfitylkqsv3aogi3eoodz4uw24i4wmvscupve4s6ncrouadwm	Explora los derechos de autor y ciberseguridad a través del acuerdo ARTI entre EE. UU. y Argentina, y su impacto en el software.\n\n#AcuerdoArti #Argentina #Ciberseguridad #DerechosDeAutor\n\nhttps://soycodigo.org/?p=29995	soycodigo.bsky.social	SoyCodigo	2026-09-08 06:49:45.078	2026-09-08 06:49:46.566	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-09 14:11:00.66199
2	at://did:plc:4dltatq7ihso6qvyyodpacqb/app.bsky.feed.post/3mv4xsfkmgc2b	bafyreifoyi7s32up5xdrrk4q7qjn6g3ltgqtmwcfspch377cn34cvxfcnq	Alerta de Crisis Digital: América Latina Enfrenta un Agujero de 329.000 Expertos en Ciberseguridad www.newstecnicas.com/2025/10/amer...	newstecnicas.com	NEWSTECNICAS | Tecnología	2026-09-10 02:08:13.766	2026-09-10 02:08:16.565	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-10 12:23:36.189629
6	at://did:plc:nc7xtwsybnrft2kfr3cczs3f/app.bsky.feed.post/3mveolp4okm2z	bafyreicff7ne7e5rpmvferbhiggdbsjnwyl5qjv3y4rvx55sq4mj6bhj2a	Argentina ante la infraestructura del futuro: cuando el mundo necesita energía, minerales y talento	infobae.bsky.social	Infobae	2026-09-13 03:44:43	2026-09-13 03:44:43.358	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-15 13:56:39.198329
\.


--
-- Name: posts_bluesky_id_seq; Type: SEQUENCE SET; Schema: public; Owner: osint
--

SELECT pg_catalog.setval('public.posts_bluesky_id_seq', 8, true);


--
-- Name: posts_bluesky posts_bluesky_pkey; Type: CONSTRAINT; Schema: public; Owner: osint
--

ALTER TABLE ONLY public.posts_bluesky
    ADD CONSTRAINT posts_bluesky_pkey PRIMARY KEY (id);


--
-- Name: posts_bluesky posts_bluesky_post_uri_key; Type: CONSTRAINT; Schema: public; Owner: osint
--

ALTER TABLE ONLY public.posts_bluesky
    ADD CONSTRAINT posts_bluesky_post_uri_key UNIQUE (post_uri);


--
-- PostgreSQL database dump complete
--

\unrestrict smnIpX1gTPQAyqg85ZljCviwEpYf4hDgmWpVsqt2K5GEVH1GCNGXYB0QM95OODA

