--
-- PostgreSQL database dump
--

\restrict u9sJ59TKDJVfzpuBlEDqFoZTIkeJswyCGtJ0pe69YXnm5xfghXrJLH0S7zJyluF

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
    fecha_insercion timestamp without time zone DEFAULT now(),
    pais text
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

COPY public.posts_bluesky (id, post_uri, post_cid, texto, autor_handle, autor_display_name, fecha_creacion, fecha_indexado, likes, reposts, replies, quotes, engagement_score, fuente_dominio, es_bridged, keyword_busqueda, fecha_insercion, pais) FROM stdin;
14	at://did:plc:fyitqypzz6qaax7ve46hsw52/app.bsky.feed.post/3mvmiynvk5726	bafyreigbuw24pp4gipfxwqjl7iyv2ssq3p6zgsxubf5ikkqxugzvfkozpm	A new Casbaneiro banking trojan campaign hits Latin America. Learn how the Casbaneiro banking trojan evades detection and targets bank logins.\n\n#Casbaneiro #BankingTrojan #Malware #Cybersecurity #InfoSec	securityonline.bsky.social	Daily CyberSecurity	2026-09-16 06:25:51	2026-09-16 06:25:54.462	0	0	0	0	0	\N	f	malware argentina	2026-09-22 14:45:34.402791	argentina
15	at://did:plc:p464uedvuxtzckhrm4pfwxa5/app.bsky.feed.post/3mt4fovfwzs2j	bafyreidxb56sy6mbbm5e3khfxwflkf7i3izognc3tfxltehci3pklmj7i4	Argentina’s Córdoba Police Reportedly Exposed in Dark Web Data Breach Claim + Video\n\nA New Cybersecurity Warning From Argentina A new dark web claim is putting Argentina’s cybersecurity posture under scrutiny after Dark Web Intelligence reported what it described as a data breach exposure involving…	undercodenews.bsky.social	Undercode News	2026-08-15 09:53:44	2026-08-15 09:53:46.269	0	0	0	0	0	\N	f	data breach argentina	2026-09-22 14:46:58.194198	argentina
16	at://did:plc:jzjc2ptgw7tqu6zwiylqywea/app.bsky.feed.post/3mudjj32cdk23	bafyreiemeewmkqj265ktatnroqxylliyb3dum6cfe7dr5q22ne2wfa2tzm	Oops. No wonder I got such a low score in school cert geography. Sorry Argentina.	stanrivett.bsky.social	Stan Rivett	2026-08-30 23:15:54.911	2026-08-30 23:15:57.007	1	0	0	0	1	\N	f	CERT argentina	2026-09-22 14:48:07.857615	argentina
1	at://did:plc:rcwcpm36224xrzvnkymyktgs/app.bsky.feed.post/3mujgixxp6w2j	bafyreiefbegqnbgp6wbb62tjlro36ihrk6iqjwk4aq3qaspa6vjccxhwhm	Argentina moderniza su defensa para enfrentar amenazas no convencionales y asegurar su soberanía regional\n\n🤖 IA: No es clickbait ✅\n👥 Usuarios: No es clickbait ✅\n\n#defensanacional #ciberseguridad #soberanía \n\n👇👇👇:	killbaitargentina.bsky.social	KillBait Argentina 🇦🇷	2026-09-02 07:38:08.656	2026-09-02 07:38:09.203	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-03 14:01:02.436869	argentina
0	at://did:plc:qvlourjmpwpq7bfzwmsdnb6c/app.bsky.feed.post/3muyglyd2u426	bafyreicycvfitylkqsv3aogi3eoodz4uw24i4wmvscupve4s6ncrouadwm	Explora los derechos de autor y ciberseguridad a través del acuerdo ARTI entre EE. UU. y Argentina, y su impacto en el software.\n\n#AcuerdoArti #Argentina #Ciberseguridad #DerechosDeAutor\n\nhttps://soycodigo.org/?p=29995	soycodigo.bsky.social	SoyCodigo	2026-09-08 06:49:45.078	2026-09-08 06:49:46.566	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-09 14:11:00.66199	argentina
17	at://did:plc:btxg2ljuv7xu6ehjyfhut4w2/app.bsky.feed.post/3mmw4ie2lcc2s	bafyreiddb5dtlhwbyksp7hsml5bz35z5gezaazskoso2jjnnyltqoijkpi	Grido sufre filtración de 4,9 millones de clientes en Sudamérica | 20xxnoticias.com/tech/grido-s...\n#Tech #TechNews	20xxnoticias.bsky.social	20XX Videogame & Tech News	2026-05-28 13:21:54.166	2026-05-28 13:21:57.862	0	0	0	0	0	\N	f	filtración de datos argentina	2026-09-22 14:48:40.267535	argentina
18	at://did:plc:2asyj2u6h3avr5diuiyzwucd/app.bsky.feed.post/3moy7jvk7cs27	bafyreihruahrhhldhqw3e2ekdynzgpmfpqare7hffvmj3wq7k6uuu7sec4	Matriz de referencia normativa BCRA sobre ciberseguridad, fraude, PSP y servicios financieros digitales\n\nVía: @seguinfo.bsky.social	dragstersystems.bsky.social	Dragster Systems	2026-06-23 20:12:10.015	2026-06-23 20:12:12.46	0	1	0	0	2	\N	f	BCRA ciberseguridad	2026-09-22 14:49:06.058578	argentina
20	at://did:plc:i5vyfd3dagho6xghhsktmaxx/app.bsky.feed.post/3mlaga7c5a3e2	bafyreia3h3jlz7bdvuhufmeg7jhze4krpmjcxozmwuejt3clz6gkxdzowq		noticiasargentinas.com.web.brid.gy	Agencia Noticias Argentinas - Periodismo. Fotoperiodismo. Agenc…	2026-05-07 04:52:32.243	2026-05-07 04:52:55.564	0	0	0	0	0	\N	t	seguridad informática argentina	2026-09-22 14:49:58.396914	argentina
13	at://did:plc:ityws36v26td6mkrfz65ya3l/app.bsky.feed.post/3mvqkaipf5s2i	bafyreiesh5666hxluqwvyhrhb4p3vr5qgjdpewoi7obtvxvbagka2avkda	Grupo de ciberespionaje vinculado a China centra sus operaciones en América Latina edomexaldia.com/grupo-de-cib...	edomexaldia.bsky.social	Edomex al Día 	2026-09-17 20:58:49.212	2026-09-17 20:58:49.869	0	0	0	0	0	\N	f	ciberataque	2026-09-22 14:45:20.652773	argentina
12	at://did:plc:c6i2jtoavfdfl4tmxfsu772l/app.bsky.feed.post/3mw3bjicaxf2p	bafyreiakrbwxncwo5anvi74upeirivt2kv65yvw6cdocy6sz3mflxyjw54	Six separate ransomware crews posted eight Argentine organisations to their leak sites in the week to 20 September, including the country's Ministry of Education. It is the highest weekly total we have recorded for Argentina, and no single crew is driving it.\n\n#Qilin #databreach #infosec	intelfusions.com	IntelFusions	2026-09-22 03:22:03.986	2026-09-22 03:22:04.964	0	0	0	0	0	\N	f	ransomware argentina	2026-09-22 14:43:05.366093	argentina
2	at://did:plc:4dltatq7ihso6qvyyodpacqb/app.bsky.feed.post/3mv4xsfkmgc2b	bafyreifoyi7s32up5xdrrk4q7qjn6g3ltgqtmwcfspch377cn34cvxfcnq	Alerta de Crisis Digital: América Latina Enfrenta un Agujero de 329.000 Expertos en Ciberseguridad www.newstecnicas.com/2025/10/amer...	newstecnicas.com	NEWSTECNICAS | Tecnología	2026-09-10 02:08:13.766	2026-09-10 02:08:16.565	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-10 12:23:36.189629	argentina
6	at://did:plc:nc7xtwsybnrft2kfr3cczs3f/app.bsky.feed.post/3mveolp4okm2z	bafyreicff7ne7e5rpmvferbhiggdbsjnwyl5qjv3y4rvx55sq4mj6bhj2a	Argentina ante la infraestructura del futuro: cuando el mundo necesita energía, minerales y talento	infobae.bsky.social	Infobae	2026-09-13 03:44:43	2026-09-13 03:44:43.358	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-15 13:56:39.198329	argentina
10	at://did:plc:dy3ogxeacsq3sj42scafsgtk/app.bsky.feed.post/3mvzpovn2vo2j	bafyreigg3v744nu6tmleu3j73ljrlidjygiunhbvocwadcf7gfg2hnwff4	Video Columna de Ciberseguridad – El peligro silencioso del SEO malicioso y las webs truchas en Argentina\n\nBienvenidos a una nueva entrega de nuestra columna semanal de ciberseguridad en Infosertec y Radiogeek. Esta semana nos metemos de lleno en una amenaza que explota un reflejo cotidiano y…	arielmcorg.bsky.social	Ariel Corgatelli	2026-09-21 12:30:17	2026-09-21 12:30:19.365	0	0	0	0	0	\N	f	ciberseguridad argentina	2026-09-22 14:41:50.261369	argentina
11	at://did:plc:ntxklgzhav3ilrmci2it5dux/app.bsky.feed.post/3mvrvzs7cww2m	bafyreidubaduwmp6cgwwzn3zfiwpya7m7cyh26jtdjnwovewi4e2c7nkcm	🚨Cyber Alert ‼️\n\n🇦🇷Argentina - 𝗖𝗲𝗿𝗲𝘀 𝗧𝗼𝗹𝘃𝗮𝘀\n\nQilin hacking group claims to have breached Ceres Tolvas.\n\nThreat actor: Qilin\nSector: Agriculture / Forestry / Fishing\nData exposure (claimed): Not specified\nData type: Not specified\nObserved: Sep 18, 2026\nStatus: Pending verification\nESIX©: 5.40	hackmanac.com	Hackmanac	2026-09-18 10:02:28.672	2026-09-18 10:02:29.458	0	0	1	0	1.5	\N	f	hacking argentina	2026-09-22 14:42:52.095062	argentina
28	at://did:plc:u6celkmubfsmbus5m3aqcrla/app.bsky.feed.post/3mvtt4dhzft24	bafyreicdekqpbomhlfqnqiuwomw3wjznjv724tanwks4ykxskd4kt5p3ka	LockBit5 reportedly targeted Forus, a Santiago-based Chilean apparel provider, with claims of encryption or data theft disrupting operations in Chile. #Chile #Forus #Ransomware	hendryadrian.bsky.social	Cybersecurity News Everyday	2026-09-19 04:15:32	2026-09-19 04:15:32.559	0	0	0	0	0	\N	f	ransomware	2026-09-23 14:08:21.051624	chile
27	at://did:plc:lefutsiwlmitoldxvjf4bo2e/app.bsky.feed.post/3ml4c7pod4j26	bafyreiflbgnyix426n7llt3qkacsjl7v34im3bhj3blyuhjjatbf6ekzgq	💻La publicación de antecedentes como la dirección y la ficha médica de algunos usuarios ha alertado sobre un supuesto ciberataque. Las autoridades chilenas han descartado una falla de seguridad masiva, aunque han admitido un caso de vulneración	elpaischile.bsky.social	EL PAÍS Chile	2026-05-05 13:30:01	2026-05-05 13:30:02.972	0	2	0	1	6	\N	f	ciberataque	2026-09-23 14:08:09.998632	chile
30	at://did:plc:pcby6eofaxrqogqqhgah3zag/app.bsky.feed.post/3mw4kqw3nw22x	bafyreihx4e3pjqcazxdggrdyivlkz6opcl53k7ybdulio5rdkgm6onrzke	🔐 El 1 de diciembre entra en vigencia en Chile la Ley 21.719. ¿Tu empresa sabe dónde están sus datos y quién accede a ellos?\n\nCon Kiteworks puedes controlar, proteger y mantener la trazabilidad de cada flujo de información sensible.\n\n#Kiteworks #ProtecciónDeDatos #Ciberseguridad	seguridadamerica.bsky.social	Seguridad América	2026-09-22 15:39:56.976	2026-09-22 15:40:03.469	2	1	0	0	4	\N	f	ciberseguridad	2026-09-23 14:08:38.76788	chile
31	at://did:plc:6jesddx35jvddg73u3qa6rmc/app.bsky.feed.post/3m65qzij5r427	bafyreib6apuxx6corktggr3gpsvej4iw23qo6jrlyle5juk6nzqymsh564	Día de la Seguridad Informática: Que fin de año no nos sorprenda, por Francisco Silva, Country Manager Chile-Perú de Kingston Technology - https://www.tabulado.net/dia-de-la-seguridad-informatica-que-fin-de-ano-no-nos-sorprenda-por-francisco-silva-country-manager-chile-peru-de-kingston-technology/	tabulado.bsky.social	Tabulado	2025-11-21 17:00:07.492	2025-11-21 17:00:08.733	1	0	0	0	1	\N	f	seguridad informatica	2026-09-23 14:09:01.504595	chile
32	at://did:plc:xlaa2jlptd6sd5wbefkr4yv4/app.bsky.feed.post/3mms32hjpcc2a	bafyreiejy4necos5cso7kqwehlqllhzxq3svy3jcy5t4aokdxxpg4hudja	www.linkedin.com/posts/nofear...	albertohill.com	Alberto Daniel Hill	2026-05-26 22:45:35.35	2026-05-26 22:45:42.666	0	0	0	0	0	\N	f	ciberseguridad	2026-09-23 14:09:15.234284	uruguay
33	at://did:plc:xlaa2jlptd6sd5wbefkr4yv4/app.bsky.feed.post/3mb2n6cyza22f	bafyreifaw5w6d2mlpnql6yygfrm3u73pt4tt4o734fqyn5attk4guxaf5q	El Secuestro Digital del Banco Hipotecario: Crónica de un Ciberataque Anunciado cybermidnight.club/el-secuestro...	albertohill.com	Alberto Daniel Hill	2025-12-28 15:28:50.551	2025-12-28 15:29:01.733	1	0	0	0	1	\N	f	ciberataque	2026-09-23 14:09:36.155679	uruguay
34	at://did:plc:erqcnbfqfpaf3fuuszspmhnk/app.bsky.feed.post/3murxb5zbu42e	bafyreidbuxhj2u25idzmhqhb7jtfacnq4b7uab6d3gin2cg3cysimpmej4	Berlin launches a crisis response after a ransomware attack leaks government data. Silicon Valley job cuts hit record highs as firms pivot to artificial intelligence. British museum to return colonial-era remains to the Naga people. Uruguay declares emergency over bird flu outbreak.	news.invalid-handle.com	Invalid Handle News	2026-09-05 16:59:16.562	2026-09-05 16:59:18.474	0	0	0	0	0	\N	f	ransomware	2026-09-23 14:09:43.028513	uruguay
35	at://did:plc:u5d54hkw4ysuqtuvcj6cmsin/app.bsky.feed.post/3mvri7zfyhg2x	bafyreicjolx5znlkcklmlax5usya7ydhynaivnxaotxju7aqxt3t23isxi	New claim on the shame-site for #ransomware / #datatheft group #Panzer.\n\nOrganization: INOVAPY\nLocation: #Paraguay\nIndustry: #SoftwareDevelopment\n\n\nLearn more: https://ecrime.ch/	ecrime.ch		2026-09-18 05:55:25.382	2026-09-18 05:55:25.558	1	0	0	0	1	\N	f	ransomware	2026-09-23 14:09:50.62685	paraguay
36	at://did:plc:qszt5r7fwu77nufv4sza2n2l/app.bsky.feed.post/3mambbeyzsk2d	bafyreihe2wslhne3c6cnraxokkjsozwl3l2ulgnmw5ffbdja2oy4wj46ra	Paraguay: Terport - Terminales Portuarias S.A con ataque de ransomware y filtración de datos.\n\nwww.security-chu.com/2025/12/Para...\n\n#ciberseguridad #Paraguay #DarkWeb #ransomware #ciberataque #databreach	chum1ng0.bsky.social	Chum1ng0 - Security Research	2025-12-22 22:18:32.072	2025-12-22 22:18:36.833	1	1	0	0	3	\N	f	ciberataque	2026-09-23 14:09:59.870525	paraguay
37	at://did:plc:pp365jrmietyaopo3mnmszot/app.bsky.feed.post/3mllp3ilcnzu2	bafyreic4t37qm2urz6emrworxqcr4gfegnyodgratn3urkjk6tldmfd7v4	Durante la visita oficial de Santiago Peña a Taiwán, ambos países firmaron acuerdos clave en inteligencia artificial, ciberseguridad, justicia y desarrollo económico, consolidando una relación bilateral cada vez más profunda	index.uhnplus.com.ap.brid.gy	UHN PLUS	2026-05-11 16:30:06	2026-05-11 16:30:25.474	0	0	0	0	0	\N	t	ciberseguridad	2026-09-23 14:10:07.138023	paraguay
38	at://did:plc:eu6c5awc4fjd32kap3fugsh6/app.bsky.feed.post/3m36uouebcc2e	bafyreif4fmbhpogdf5n2pkvg6gqdjdr4mh7klvaj2aiyve4357urhhrwiy	Excepto su celular que suele cambiar aveces y esta conectado a Internet a través del celular. No se como es en Japón si suelen cambiar las PC cada vez que la versión de Windows no tiene soporte de seguridad pero en Paraguay no es común eso, al menos que sea en área de informática o seguridad.	bsdmoe.bsky.social	エルさん (Eru-san)	2025-10-14 23:22:50.997	2025-10-14 23:22:55.528	2	0	1	0	3.5	\N	f	seguridad informatica	2026-09-23 14:10:31.445669	paraguay
39	at://did:plc:6gvrwagnh643wqylpt3f6nqa/app.bsky.feed.post/3m64urss5q42h	bafyreihbkfvcpuakiqnsbrltziru33cbnr4nwuudfg334fnf43hk7eygeq	📢 ¡Inscripciones abiertas para la "Jornada sobre la aplicación del Reglamento europeo sobre criptoactivos, MiCA"!\n\n🗓️ 3 diciembre 2025, 12:00–14:30\n📍 Auditorio sede CNMV Barcelona (C/ Bolívia 56)\nℹ️ Programación: https://cutt.ly/Jte0O9Lh\n📝 INCRÍBETE: https://cutt.ly/dte0PQxk	cnmv.bsky.social	CNMV	2025-11-21 08:34:45.182	2025-11-21 08:34:46.232	0	0	1	0	1.5	\N	f	ciberseguridad	2026-09-23 14:10:47.902743	bolivia
40	at://did:plc:qszt5r7fwu77nufv4sza2n2l/app.bsky.feed.post/3lv4yo75nl22a	bafyreicumvtbpxf67wee6zvzy43w2d2p5okx75shatfz7eskq3bmgcbq2i	#ciberataque: Sin confirmar, Beast ransomware ataca a una compañia de seguros boliviana?\n\nwww.security-chu.com/2025/07/cibe... \n\n#ciberseguridad #ransomware #Bolivia	chum1ng0.bsky.social	Chum1ng0 - Security Research	2025-07-29 20:57:34.482	2025-07-29 20:57:44.105	1	1	0	0	3	\N	f	ciberataque	2026-09-23 14:13:42.525013	bolivia
41	at://did:plc:u5d54hkw4ysuqtuvcj6cmsin/app.bsky.feed.post/3mtv3n5w4qb22	bafyreifekxssitxgcfoekcd3cijxfyezn3m3uh32f4uqzakaiugrxlb5ii	New claim on the shame-site for #ransomware / #datatheft group #Qilin.\n\nOrganization: Consultores de Seguros S.A. / CONSEGSA\nLocation: #Bolivia,PlurinationalStateof\nIndustry: #Insurance\nStaff: 51-200 employees\n\n\nLearn more: https://ecrime.ch/	ecrime.ch		2026-08-25 05:30:23.338	2026-08-25 05:30:23.668	1	0	0	0	1	\N	f	ransomware	2026-09-23 14:14:02.774515	bolivia
42	at://did:plc:6qfst2rcvntjtekm4vvemiqu/app.bsky.feed.post/3mvsm2lu2kt52	bafyreiglcv3hcdgpxbjfjdc7orqywyheknp5qscbitpkpygowrnh7ieyzy		telesintese.com.br.web.brid.gy	Início - TeleSíntese [Unofficial]	2026-09-18 16:09:24	2026-09-18 16:36:47.665	0	0	0	0	0	\N	t	cibersegurança	2026-09-23 14:14:25.743643	brasil
43	at://did:plc:u6celkmubfsmbus5m3aqcrla/app.bsky.feed.post/3mw6mgrcbww2f	bafyreif4q5r3jr33mc26hzjxt7srimxrdfgft3lmqeyhafhbsjb4vb2weq	Ransomware tied to emperador reportedly hit Brazil's Receita Federal systems, exfiltrating thousands of files with personnel and customer data and accessing gov.br user data, including passwords. #Brazil #Ransomware #GovBR	hendryadrian.bsky.social	Cybersecurity News Everyday	2026-09-23 11:15:23	2026-09-23 11:15:24.061	0	0	0	0	0	\N	f	ransomware	2026-09-23 14:14:36.483463	brasil
\.


--
-- Name: posts_bluesky_id_seq; Type: SEQUENCE SET; Schema: public; Owner: osint
--

SELECT pg_catalog.setval('public.posts_bluesky_id_seq', 43, true);


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

\unrestrict u9sJ59TKDJVfzpuBlEDqFoZTIkeJswyCGtJ0pe69YXnm5xfghXrJLH0S7zJyluF

