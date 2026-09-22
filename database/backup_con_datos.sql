--
-- PostgreSQL database dump
--

\restrict kXvJWrIlWQT2CwD7ji4sbqACYBc2bmPIu4Xg6QdhWddqapEQguHdtQjOQCpYMdP

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
12	at://did:plc:c6i2jtoavfdfl4tmxfsu772l/app.bsky.feed.post/3mw3bjicaxf2p	bafyreiakrbwxncwo5anvi74upeirivt2kv65yvw6cdocy6sz3mflxyjw54	Six separate ransomware crews posted eight Argentine organisations to their leak sites in the week to 20 September, including the country's Ministry of Education. It is the highest weekly total we have recorded for Argentina, and no single crew is driving it.\n\n#Qilin #databreach #infosec	intelfusions.com	IntelFusions	2026-09-22 03:22:03.986	2026-09-22 03:22:04.964	0	0	0	0	0	\N	f	ransomware argentina	2026-09-22 14:43:05.366093
2	at://did:plc:4dltatq7ihso6qvyyodpacqb/app.bsky.feed.post/3mv4xsfkmgc2b	bafyreifoyi7s32up5xdrrk4q7qjn6g3ltgqtmwcfspch377cn34cvxfcnq	Alerta de Crisis Digital: América Latina Enfrenta un Agujero de 329.000 Expertos en Ciberseguridad www.newstecnicas.com/2025/10/amer...	newstecnicas.com	NEWSTECNICAS | Tecnología	2026-09-10 02:08:13.766	2026-09-10 02:08:16.565	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-10 12:23:36.189629
15	at://did:plc:p464uedvuxtzckhrm4pfwxa5/app.bsky.feed.post/3mt4fovfwzs2j	bafyreidxb56sy6mbbm5e3khfxwflkf7i3izognc3tfxltehci3pklmj7i4	Argentina’s Córdoba Police Reportedly Exposed in Dark Web Data Breach Claim + Video\n\nA New Cybersecurity Warning From Argentina A new dark web claim is putting Argentina’s cybersecurity posture under scrutiny after Dark Web Intelligence reported what it described as a data breach exposure involving…	undercodenews.bsky.social	Undercode News	2026-08-15 09:53:44	2026-08-15 09:53:46.269	0	0	0	0	0	\N	f	data breach argentina	2026-09-22 14:46:58.194198
6	at://did:plc:nc7xtwsybnrft2kfr3cczs3f/app.bsky.feed.post/3mveolp4okm2z	bafyreicff7ne7e5rpmvferbhiggdbsjnwyl5qjv3y4rvx55sq4mj6bhj2a	Argentina ante la infraestructura del futuro: cuando el mundo necesita energía, minerales y talento	infobae.bsky.social	Infobae	2026-09-13 03:44:43	2026-09-13 03:44:43.358	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-15 13:56:39.198329
10	at://did:plc:dy3ogxeacsq3sj42scafsgtk/app.bsky.feed.post/3mvzpovn2vo2j	bafyreigg3v744nu6tmleu3j73ljrlidjygiunhbvocwadcf7gfg2hnwff4	Video Columna de Ciberseguridad – El peligro silencioso del SEO malicioso y las webs truchas en Argentina\n\nBienvenidos a una nueva entrega de nuestra columna semanal de ciberseguridad en Infosertec y Radiogeek. Esta semana nos metemos de lleno en una amenaza que explota un reflejo cotidiano y…	arielmcorg.bsky.social	Ariel Corgatelli	2026-09-21 12:30:17	2026-09-21 12:30:19.365	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-22 14:41:50.261369
11	at://did:plc:ntxklgzhav3ilrmci2it5dux/app.bsky.feed.post/3mvrvzs7cww2m	bafyreidubaduwmp6cgwwzn3zfiwpya7m7cyh26jtdjnwovewi4e2c7nkcm	🚨Cyber Alert ‼️\n\n🇦🇷Argentina - 𝗖𝗲𝗿𝗲𝘀 𝗧𝗼𝗹𝘃𝗮𝘀\n\nQilin hacking group claims to have breached Ceres Tolvas.\n\nThreat actor: Qilin\nSector: Agriculture / Forestry / Fishing\nData exposure (claimed): Not specified\nData type: Not specified\nObserved: Sep 18, 2026\nStatus: Pending verification\nESIX©: 5.40	hackmanac.com	Hackmanac	2026-09-18 10:02:28.672	2026-09-18 10:02:29.458	0	0	1	0	1.5	\N	f	hacking argentina	2026-09-22 14:42:52.095062
16	at://did:plc:jzjc2ptgw7tqu6zwiylqywea/app.bsky.feed.post/3mudjj32cdk23	bafyreiemeewmkqj265ktatnroqxylliyb3dum6cfe7dr5q22ne2wfa2tzm	Oops. No wonder I got such a low score in school cert geography. Sorry Argentina.	stanrivett.bsky.social	Stan Rivett	2026-08-30 23:15:54.911	2026-08-30 23:15:57.007	1	0	0	0	1	\N	f	CERT argentina	2026-09-22 14:48:07.857615
17	at://did:plc:btxg2ljuv7xu6ehjyfhut4w2/app.bsky.feed.post/3mmw4ie2lcc2s	bafyreiddb5dtlhwbyksp7hsml5bz35z5gezaazskoso2jjnnyltqoijkpi	Grido sufre filtración de 4,9 millones de clientes en Sudamérica | 20xxnoticias.com/tech/grido-s...\n#Tech #TechNews	20xxnoticias.bsky.social	20XX Videogame & Tech News	2026-05-28 13:21:54.166	2026-05-28 13:21:57.862	0	0	0	0	0	\N	f	filtración de datos argentina	2026-09-22 14:48:40.267535
18	at://did:plc:2asyj2u6h3avr5diuiyzwucd/app.bsky.feed.post/3moy7jvk7cs27	bafyreihruahrhhldhqw3e2ekdynzgpmfpqare7hffvmj3wq7k6uuu7sec4	Matriz de referencia normativa BCRA sobre ciberseguridad, fraude, PSP y servicios financieros digitales\n\nVía: @seguinfo.bsky.social	dragstersystems.bsky.social	Dragster Systems	2026-06-23 20:12:10.015	2026-06-23 20:12:12.46	0	1	0	0	2	\N	f	BCRA ciberseguridad	2026-09-22 14:49:06.058578
14	at://did:plc:fyitqypzz6qaax7ve46hsw52/app.bsky.feed.post/3mvmiynvk5726	bafyreigbuw24pp4gipfxwqjl7iyv2ssq3p6zgsxubf5ikkqxugzvfkozpm	A new Casbaneiro banking trojan campaign hits Latin America. Learn how the Casbaneiro banking trojan evades detection and targets bank logins.\n\n#Casbaneiro #BankingTrojan #Malware #Cybersecurity #InfoSec	securityonline.bsky.social	Daily CyberSecurity	2026-09-16 06:25:51	2026-09-16 06:25:54.462	0	0	0	0	0	\N	f	malware argentina	2026-09-22 14:45:34.402791
20	at://did:plc:i5vyfd3dagho6xghhsktmaxx/app.bsky.feed.post/3mlaga7c5a3e2	bafyreia3h3jlz7bdvuhufmeg7jhze4krpmjcxozmwuejt3clz6gkxdzowq		noticiasargentinas.com.web.brid.gy	Agencia Noticias Argentinas - Periodismo. Fotoperiodismo. Agenc…	2026-05-07 04:52:32.243	2026-05-07 04:52:55.564	0	0	0	0	0	\N	t	seguridad informática argentina	2026-09-22 14:49:58.396914
13	at://did:plc:ityws36v26td6mkrfz65ya3l/app.bsky.feed.post/3mvqkaipf5s2i	bafyreiesh5666hxluqwvyhrhb4p3vr5qgjdpewoi7obtvxvbagka2avkda	Grupo de ciberespionaje vinculado a China centra sus operaciones en América Latina edomexaldia.com/grupo-de-cib...	edomexaldia.bsky.social	Edomex al Día 	2026-09-17 20:58:49.212	2026-09-17 20:58:49.869	0	0	0	0	0	\N	f	ciberataque argentina	2026-09-22 14:45:20.652773
\.


--
-- Name: posts_bluesky_id_seq; Type: SEQUENCE SET; Schema: public; Owner: osint
--

SELECT pg_catalog.setval('public.posts_bluesky_id_seq', 21, true);


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

\unrestrict kXvJWrIlWQT2CwD7ji4sbqACYBc2bmPIu4Xg6QdhWddqapEQguHdtQjOQCpYMdP

