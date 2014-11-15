--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET search_path = public, pg_catalog;

--
-- Name: find_officers_assigned_to_crime_type(text); Type: FUNCTION; Schema: public; Owner: profh
--

CREATE FUNCTION find_officers_assigned_to_crime_type(crime_name text) RETURNS SETOF record
    LANGUAGE sql
    AS $_$
select first_name, last_name, coalesce(units.name,'N/A') AS "Unit", cases.title, crimes.name
from crimes join cases using (crime_id) join assignments using (case_id) join officers using(officer_id) left join units using (unit_id) 
where crimes.name ~* $1
order by last_name, first_name, cases.title;
$_$;


ALTER FUNCTION public.find_officers_assigned_to_crime_type(crime_name text) OWNER TO profh;

--
-- Name: find_similiar_by_degree(character varying, double precision); Type: FUNCTION; Schema: public; Owner: profh
--

CREATE FUNCTION find_similiar_by_degree(param_name character varying, desired_degree double precision) RETURNS TABLE(sim_lname character varying, sim_fname character varying, sim_ln numeric, sim_fn numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
target_name VARCHAR(255);
degree_of_sim float;
BEGIN
target_name = param_name;
degree_of_sim = desired_degree;
RETURN QUERY
SELECT last_name AS "Last Name", first_name AS "First Name"
, ROUND(SIMILARITY(criminals.last_name, target_name)::numeric,3) AS "Similar Last Name"
, ROUND(SIMILARITY(criminals.first_name, target_name)::numeric,3) AS "Similar First Name"
FROM criminals 
WHERE SIMILARITY(criminals.last_name, target_name) > degree_of_sim 
OR SIMILARITY(criminals.first_name, target_name) > degree_of_sim 
ORDER BY "Similar Last Name" DESC, "Similar First Name" DESC, "Last Name", "First Name";
END;
$$;


ALTER FUNCTION public.find_similiar_by_degree(param_name character varying, desired_degree double precision) OWNER TO profh;

--
-- Name: update_date_closed(); Type: FUNCTION; Schema: public; Owner: profh
--

CREATE FUNCTION update_date_closed() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
num_cases INTEGER;
this_case INTEGER;
ending DATE;
opened_on DATE;
BEGIN
num_cases = (SELECT COUNT(*) FROM CASES);
FOR this_case IN 1 .. num_cases LOOP
opened_on = (select date_opened from cases where case_id = this_case);
ending = (select max(end_date) from assignments where assignments.case_id = this_case group by assignments.case_id);
IF opened_on < ending
THEN UPDATE cases SET date_closed = ending WHERE case_id = this_case;
END IF;
END LOOP;
END;
$$;


ALTER FUNCTION public.update_date_closed() OWNER TO profh;

--
-- Name: update_summary_table(); Type: FUNCTION; Schema: public; Owner: profh
--

CREATE FUNCTION update_summary_table() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
num_open integer;
    num_solved integer;
    num_batman integer;
BEGIN
num_open = (select count(*) from cases where date_closed is null);
num_solved = (select count(*) from cases where solved = true);
num_batman = (select count(*) from cases where batman_involved = true);
update case_summary set number_of_open_cases=num_open, number_of_solved_cases=num_solved, number_of_cases_with_batman=num_batman;
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_summary_table() OWNER TO profh;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: assignments; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE assignments (
    case_id integer NOT NULL,
    officer_id integer NOT NULL,
    start_date date NOT NULL,
    end_date date,
    CONSTRAINT assignments_check_date_order CHECK ((end_date >= start_date))
);


ALTER TABLE public.assignments OWNER TO profh;

--
-- Name: cases; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE cases (
    case_id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    crime_id integer NOT NULL,
    crime_location character varying(255),
    date_opened date NOT NULL,
    date_closed date,
    solved boolean DEFAULT false,
    batman_involved boolean DEFAULT false,
    CONSTRAINT cases_check_date_order CHECK ((date_closed >= date_opened))
);


ALTER TABLE public.cases OWNER TO profh;

--
-- Name: crimes; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE crimes (
    crime_id integer NOT NULL,
    name character varying(255) NOT NULL,
    degree integer DEFAULT 1,
    active boolean DEFAULT true
);


ALTER TABLE public.crimes OWNER TO profh;

--
-- Name: case_crimes_view; Type: VIEW; Schema: public; Owner: profh
--

CREATE VIEW case_crimes_view AS
    SELECT cases.case_id, cases.title, cases.description, crimes.name AS crime, crimes.degree, cases.crime_location, cases.date_opened, cases.date_closed, cases.solved, cases.batman_involved FROM (cases JOIN crimes USING (crime_id)) ORDER BY cases.case_id;


ALTER TABLE public.case_crimes_view OWNER TO profh;

--
-- Name: case_summary; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE case_summary (
    id integer NOT NULL,
    number_of_open_cases integer,
    number_of_solved_cases integer,
    number_of_cases_with_batman integer
);


ALTER TABLE public.case_summary OWNER TO profh;

--
-- Name: cases_case_id_seq; Type: SEQUENCE; Schema: public; Owner: profh
--

CREATE SEQUENCE cases_case_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cases_case_id_seq OWNER TO profh;

--
-- Name: cases_case_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: profh
--

ALTER SEQUENCE cases_case_id_seq OWNED BY cases.case_id;


--
-- Name: cases_case_id_seq; Type: SEQUENCE SET; Schema: public; Owner: profh
--

SELECT pg_catalog.setval('cases_case_id_seq', 51, true);


--
-- Name: crimes_crime_id_seq; Type: SEQUENCE; Schema: public; Owner: profh
--

CREATE SEQUENCE crimes_crime_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.crimes_crime_id_seq OWNER TO profh;

--
-- Name: crimes_crime_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: profh
--

ALTER SEQUENCE crimes_crime_id_seq OWNED BY crimes.crime_id;


--
-- Name: crimes_crime_id_seq; Type: SEQUENCE SET; Schema: public; Owner: profh
--

SELECT pg_catalog.setval('crimes_crime_id_seq', 16, true);


--
-- Name: criminals; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE criminals (
    criminal_id integer NOT NULL,
    first_name character varying(25) NOT NULL,
    last_name character varying(25) NOT NULL,
    alias character varying(255),
    convicted_felon boolean,
    super_criminal boolean
);


ALTER TABLE public.criminals OWNER TO profh;

--
-- Name: suspects; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE suspects (
    case_id integer NOT NULL,
    criminal_id integer NOT NULL,
    became_suspect_on date NOT NULL,
    dropped_as_suspect_on date,
    CONSTRAINT suspects_check_date_order CHECK ((dropped_as_suspect_on >= became_suspect_on))
);


ALTER TABLE public.suspects OWNER TO profh;

--
-- Name: criminal_cases_view; Type: VIEW; Schema: public; Owner: profh
--

CREATE VIEW criminal_cases_view AS
    SELECT criminals.last_name, criminals.first_name, COALESCE(criminals.alias, '--'::character varying) AS alias, suspects.case_id, cases.title, cases.description, crimes.name AS crime, crimes.degree, cases.crime_location, cases.date_opened, cases.date_closed, cases.solved, cases.batman_involved, suspects.became_suspect_on, suspects.dropped_as_suspect_on, criminals.convicted_felon, criminals.super_criminal FROM ((criminals LEFT JOIN suspects USING (criminal_id)) LEFT JOIN (cases JOIN crimes USING (crime_id)) USING (case_id)) ORDER BY criminals.last_name, criminals.first_name;


ALTER TABLE public.criminal_cases_view OWNER TO profh;

--
-- Name: criminals_criminal_id_seq; Type: SEQUENCE; Schema: public; Owner: profh
--

CREATE SEQUENCE criminals_criminal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.criminals_criminal_id_seq OWNER TO profh;

--
-- Name: criminals_criminal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: profh
--

ALTER SEQUENCE criminals_criminal_id_seq OWNED BY criminals.criminal_id;


--
-- Name: criminals_criminal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: profh
--

SELECT pg_catalog.setval('criminals_criminal_id_seq', 51, true);


--
-- Name: mongo_case_complete_view; Type: VIEW; Schema: public; Owner: profh
--

CREATE VIEW mongo_case_complete_view AS
    SELECT cs.case_id, cr.name AS crime_name, cs.crime_location, cs.date_opened, cs.date_closed, cs.solved, cs.batman_involved, COALESCE((SELECT array_agg((((((cx.first_name)::text || ', '::text) || (cx.last_name)::text) || ', '::text) || (COALESCE(cx.alias, ''::character varying))::text)) AS array_agg FROM (criminals cx JOIN suspects sus USING (criminal_id)) WHERE (sus.case_id = cs.case_id)), '{}'::text[]) AS suspects, COALESCE((SELECT array_agg(ao.officer_id) AS array_agg FROM assignments ao WHERE (ao.case_id = cs.case_id)), '{}'::integer[]) AS assigned_officers FROM (cases cs JOIN crimes cr USING (crime_id)) ORDER BY cs.case_id;


ALTER TABLE public.mongo_case_complete_view OWNER TO profh;

--
-- Name: mongo_case_criminal_view; Type: VIEW; Schema: public; Owner: gcpd
--

CREATE VIEW mongo_case_criminal_view AS
    SELECT cs.case_id, cr.name AS crime_name, cs.crime_location, cs.date_opened, cs.date_closed, cs.solved, cs.batman_involved, COALESCE((SELECT array_agg((((((cx.first_name)::text || ', '::text) || (cx.last_name)::text) || ', '::text) || (COALESCE(cx.alias, ''::character varying))::text)) AS array_agg FROM (criminals cx JOIN suspects sus USING (criminal_id)) WHERE (sus.case_id = cs.case_id)), '{}'::text[]) AS suspects FROM (cases cs JOIN crimes cr USING (crime_id)) ORDER BY cs.case_id;


ALTER TABLE public.mongo_case_criminal_view OWNER TO gcpd;

--
-- Name: officers; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE officers (
    officer_id integer NOT NULL,
    first_name character varying(25) NOT NULL,
    last_name character varying(25) NOT NULL,
    unit_id integer,
    rank character varying(255),
    joined_gcpd_on date NOT NULL,
    active boolean DEFAULT true,
    CONSTRAINT officers_check_rank CHECK (((rank)::text ~* '^(Commissioner|Detective|Lieutenant|Sergeant|Captain|Detective Sergeant|Supervisor)$'::text))
);


ALTER TABLE public.officers OWNER TO profh;

--
-- Name: units; Type: TABLE; Schema: public; Owner: profh; Tablespace: 
--

CREATE TABLE units (
    unit_id integer NOT NULL,
    name character varying(255) NOT NULL,
    active boolean DEFAULT true
);


ALTER TABLE public.units OWNER TO profh;

--
-- Name: mongo_officer_case_view; Type: VIEW; Schema: public; Owner: gcpd
--

CREATE VIEW mongo_officer_case_view AS
    SELECT o.officer_id, o.first_name, o.last_name, COALESCE(o.rank, 'Officer'::character varying) AS rank, o.joined_gcpd_on, COALESCE(u.name, 'N/A'::character varying) AS unit, COALESCE((SELECT array_agg(a1.case_id) AS array_agg FROM assignments a1 WHERE (a1.officer_id = o.officer_id)), '{}'::integer[]) AS cases FROM (officers o LEFT JOIN units u USING (unit_id));


ALTER TABLE public.mongo_officer_case_view OWNER TO gcpd;

--
-- Name: officer_assignments_view; Type: VIEW; Schema: public; Owner: profh
--

CREATE VIEW officer_assignments_view AS
    SELECT officers.officer_id, officers.first_name, officers.last_name, officers.unit_id, officers.rank, officers.joined_gcpd_on, officers.active, assignments.case_id, assignments.start_date, assignments.end_date FROM (officers LEFT JOIN assignments USING (officer_id));


ALTER TABLE public.officer_assignments_view OWNER TO profh;

--
-- Name: officer_units_view; Type: VIEW; Schema: public; Owner: profh
--

CREATE VIEW officer_units_view AS
    SELECT officers.officer_id, officers.first_name, officers.last_name, officers.rank, officers.joined_gcpd_on, officers.active AS "active officer", units.unit_id, units.name, units.active AS "active unit" FROM (officers LEFT JOIN units USING (unit_id));


ALTER TABLE public.officer_units_view OWNER TO profh;

--
-- Name: officers_officer_id_seq; Type: SEQUENCE; Schema: public; Owner: profh
--

CREATE SEQUENCE officers_officer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.officers_officer_id_seq OWNER TO profh;

--
-- Name: officers_officer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: profh
--

ALTER SEQUENCE officers_officer_id_seq OWNED BY officers.officer_id;


--
-- Name: officers_officer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: profh
--

SELECT pg_catalog.setval('officers_officer_id_seq', 12, true);


--
-- Name: units_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: profh
--

CREATE SEQUENCE units_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.units_unit_id_seq OWNER TO profh;

--
-- Name: units_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: profh
--

ALTER SEQUENCE units_unit_id_seq OWNED BY units.unit_id;


--
-- Name: units_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: profh
--

SELECT pg_catalog.setval('units_unit_id_seq', 6, true);


--
-- Name: case_id; Type: DEFAULT; Schema: public; Owner: profh
--

ALTER TABLE ONLY cases ALTER COLUMN case_id SET DEFAULT nextval('cases_case_id_seq'::regclass);


--
-- Name: crime_id; Type: DEFAULT; Schema: public; Owner: profh
--

ALTER TABLE ONLY crimes ALTER COLUMN crime_id SET DEFAULT nextval('crimes_crime_id_seq'::regclass);


--
-- Name: criminal_id; Type: DEFAULT; Schema: public; Owner: profh
--

ALTER TABLE ONLY criminals ALTER COLUMN criminal_id SET DEFAULT nextval('criminals_criminal_id_seq'::regclass);


--
-- Name: officer_id; Type: DEFAULT; Schema: public; Owner: profh
--

ALTER TABLE ONLY officers ALTER COLUMN officer_id SET DEFAULT nextval('officers_officer_id_seq'::regclass);


--
-- Name: unit_id; Type: DEFAULT; Schema: public; Owner: profh
--

ALTER TABLE ONLY units ALTER COLUMN unit_id SET DEFAULT nextval('units_unit_id_seq'::regclass);


--
-- Data for Name: assignments; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY assignments (case_id, officer_id, start_date, end_date) FROM stdin;
1	2	2012-09-09	2012-10-01
1	7	2012-09-09	2012-10-01
1	1	2012-09-09	2012-10-01
2	3	2012-05-12	2012-08-01
2	7	2012-05-12	2012-08-01
2	1	2012-05-12	2012-08-01
3	2	2012-06-26	2012-08-15
3	7	2012-06-26	2012-08-15
4	2	2012-08-12	2012-08-30
5	4	2012-07-15	2012-09-20
5	1	2012-09-15	2012-09-20
6	2	2012-06-24	2012-08-20
7	6	2012-08-05	2012-09-20
7	1	2012-09-05	2012-09-20
8	2	2012-08-15	2012-09-20
9	2	2012-07-20	2012-10-01
10	8	2012-07-09	2012-08-01
10	1	2012-08-01	2012-09-01
11	2	2012-08-12	2012-10-04
11	1	2012-08-12	2012-10-04
12	1	2012-08-22	2012-10-15
12	2	2012-08-26	2012-10-15
13	2	2012-05-09	2012-06-15
14	8	2012-08-12	2012-08-30
15	5	2012-04-20	2012-09-11
16	2	2012-06-15	2012-07-20
17	2	2011-06-14	2011-06-20
18	6	2012-10-12	2012-10-17
18	1	2012-10-12	2012-10-17
19	9	2011-12-07	2012-09-15
20	2	2011-03-02	2012-01-04
21	2	2011-12-09	2012-10-01
22	7	2011-08-15	2011-10-02
23	7	2011-09-09	2011-10-01
24	3	2011-10-22	2011-12-01
26	4	2012-09-12	2012-10-01
27	2	2012-08-26	2012-10-15
28	7	2011-12-13	2011-12-25
29	2	2012-05-20	2012-08-30
30	4	2012-04-15	2012-09-20
31	4	2012-07-31	2012-09-20
32	2	2011-07-14	2011-08-20
33	6	2012-01-25	2012-03-14
34	2	2012-07-05	2012-09-20
35	2	2012-05-06	2012-09-20
36	5	2011-06-15	\N
37	2	2012-01-09	\N
38	8	2012-10-09	\N
39	8	2012-09-03	\N
40	2	2011-10-31	\N
41	8	2012-09-18	\N
42	6	2012-02-05	\N
42	2	2012-02-05	\N
43	2	2011-06-11	\N
44	8	2011-10-25	\N
45	5	2012-07-10	\N
46	2	2012-08-25	2012-10-13
47	2	2011-08-23	2012-10-18
48	6	2012-06-26	\N
49	8	2011-06-12	\N
50	9	2012-04-10	\N
\.


--
-- Data for Name: case_summary; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY case_summary (id, number_of_open_cases, number_of_solved_cases, number_of_cases_with_batman) FROM stdin;
1	13	34	21
\.


--
-- Data for Name: cases; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY cases (case_id, title, description, crime_id, crime_location, date_opened, date_closed, solved, batman_involved) FROM stdin;
48	Case 48	\N	9	Murphy Ave	2011-12-12	\N	f	f
49	Case 49	\N	9	Near Gotham Bay	2012-03-03	\N	f	f
50	Case 50	\N	11	925 Rupert Street	2011-11-08	\N	f	f
36	Case 36	\N	10	Spring Bridge	2012-03-08	\N	f	f
37	Case 37	\N	1	Gotham Towers	2012-10-03	\N	f	f
38	Case 38	\N	3	923 Rupert Street	2012-07-23	\N	f	f
39	Case 39	\N	7	923 Rupet Street	2012-06-11	\N	f	f
40	Case 40	\N	10	Gotham Harbor	2011-12-21	\N	f	f
42	Case 42: Arkham	\N	4	Crest Hill	2012-05-13	\N	f	f
43	Case 43	\N	5	Harbor dock 1 on the bay	2012-05-29	\N	f	f
44	Case 44: Main Street Murderer	\N	1	191 Main Street	2012-09-14	\N	f	f
45	Case 45	\N	10	923 Rupert Street	2011-07-24	2012-11-07	f	f
41	Case 41	\N	12	Gotham City Zoo	2012-09-06	\N	f	f
51	Case 51: Harbor Murders	A series of brutal murders on the docks of Gotham Bay	1	On the docks by the bay	2012-11-10	\N	f	t
1	Case 1: Main Street Murders	\N	1	250 Main Street	2012-09-01	2012-10-01	t	t
4	Case 4	\N	1	Gotham Tower Apartments	2012-08-11	2012-08-30	t	t
5	Case 5	\N	9	Gotham Bay	2012-07-26	2012-09-20	t	t
6	Case 6	\N	8	Vincefinkel Bridge	2012-07-13	2012-08-20	t	t
7	Case 7	\N	4	923 Rupert Street	2012-09-16	2012-09-20	t	t
8	Case 8	\N	3	Wayne Tower	2012-09-02	2012-09-20	t	t
9	Case 9: Arkham	\N	6	Arkham Asylum	2012-07-10	2012-10-01	t	t
10	Case 10	\N	9	Arkham Asylum, by Crest Hill	2012-06-14	2012-09-01	t	t
11	Case 11	\N	8	Wayne Tower	2012-06-29	2012-10-04	t	t
12	Case 12	\N	12	Gotham Towers	2012-07-20	2012-10-15	t	t
13	Case 13	\N	5	First National Bank of Gotham	2012-04-19	2012-06-15	t	t
14	Case 14	\N	7	Robinson Park	2012-08-28	2012-08-30	t	t
15	Case 15	\N	6	288 Kane Street	2012-04-23	2012-09-11	t	t
18	Case 18	\N	12	Corner of Kane and Rupert Streets	2011-02-23	2012-10-17	t	t
19	Case 19: Howard Cain	\N	14	187 Main	2011-02-24	2012-09-15	f	t
20	Case 20	\N	6	Mooney Bridge	2011-09-02	2012-01-04	t	t
21	Case 21	\N	6	First National Bank of Gotham	2011-08-21	2012-10-01	t	f
26	Case 26	\N	5	Gotham Tower Apartments	2011-11-28	2012-10-01	t	f
27	Case 27	\N	5	Murphy Avenue	2012-07-23	2012-10-15	t	f
29	Case 29	\N	9	Just off Kane	2012-03-11	2012-08-30	t	f
30	Case 30	\N	10	Arkham Asylum	2012-08-10	2012-09-20	t	f
31	Case 31	\N	2	New Trigate Bridge	2012-02-17	2012-09-20	t	f
34	Case 34: Arkham	\N	10	Crest Hill	2012-08-05	2012-09-20	f	f
35	Case 35	\N	1	Ellsworth Building	2012-08-23	2012-09-20	f	f
46	Case 46	\N	4	Corner of Main and Murphy	2011-09-18	2012-10-13	t	f
47	Case 47	\N	6	Gotham Tower Apartments	2012-01-25	2012-10-18	t	f
2	Case 2	\N	1	751 Kane Street	2012-11-01	2012-11-07	t	t
3	Case 3	\N	1	Mooney Bridge	2012-09-08	2012-11-07	t	t
16	Case 16	\N	9	Arkham Asylum	2012-09-28	2012-11-07	t	t
17	Case 17	\N	13	Second National Bank of Gotham	2011-07-30	2012-11-07	t	t
22	Case 22	\N	4	Crest Hill	2011-11-11	2012-11-07	t	f
23	Case 23: Arkham	\N	3	Arkham Asylum	2012-03-24	2012-11-07	t	f
24	Case 24	\N	2	923 Rupert Street	2012-02-05	2012-11-07	t	f
25	Case 25	\N	3	Gotham Bay	2011-12-09	2012-11-07	t	f
32	Case 32	\N	4	Cain Street	2011-08-21	2012-11-07	t	f
33	Case 33	\N	3	Blackfire Shelter near Main Street	2012-08-31	2012-11-07	t	f
28	Case 28	\N	11	gotham harbor	2011-11-25	2011-12-25	t	f
\.


--
-- Data for Name: crimes; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY crimes (crime_id, name, degree, active) FROM stdin;
1	Murder	1	t
2	Assault	1	t
3	Battery	1	t
4	Rape	1	t
5	Robbery	1	t
6	Burglary	1	t
7	Theft	1	t
8	Drug Possession	1	t
9	Kidnapping	1	t
10	Arson	1	t
11	Conspiracy	1	t
12	Extortion	1	t
13	Fraud	1	t
14	Vandalism	1	t
15	Accessory	1	t
16	Manslaughter	1	t
\.


--
-- Data for Name: criminals; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY criminals (criminal_id, first_name, last_name, alias, convicted_felon, super_criminal) FROM stdin;
1	Selina	Kyle	Catwoman	f	f
2	Edmund	Dorrance	Bane	t	t
3	Jack	Napier	Joker	t	t
4	Victor	Fries	Mr. Freeze	t	t
5	Oswald	Cobblepot	Penguin	t	t
6	Edward	Nigma	Riddler	t	t
7	Jonathon	Crane	Scarecrow	t	t
8	Harvey	Dent	Two Face	t	t
9	Salvatore	Maroni	\N	f	f
10	Yuri	Chechen	\N	f	f
11	Michael	Gambol	\N	f	f
12	Carmine	Falconi	\N	t	f
13	Joe	Chill	\N	t	f
14	John	Daggett	\N	f	f
15	Ras	al Ghul	\N	f	t
16	Matthew	Johnson	\N	t	f
17	Jake	Friedman	\N	t	f
18	Jock	Terry	\N	t	f
19	Jacob	Ferrier	\N	t	f
21	Micheal	Michaledis	\N	t	f
22	Jonny	McGrady	\N	t	f
23	James	MacGrady	\N	t	f
24	Jeffery	McGrady	\N	t	f
25	Joseph	McGrady	\N	t	f
28	Timothy	Matthews	\N	t	f
29	Kameron	Gelfeld	\N	t	f
31	Kenny	Gelfield	\N	t	f
32	Keith	Gelfeld	\N	t	f
33	Kaitlin	Gefleld	\N	f	f
34	Kandy	Gelfeld	\N	t	f
35	Clyde	Kapinos	\N	t	f
37	Terrie	Hammond	\N	t	f
38	Mathew	Hamond	\N	t	f
39	Todd	Hicks	\N	t	f
40	George	Hemmond	\N	t	f
41	George	Hemmond	\N	t	f
42	Jamie	Jackson	\N	t	f
43	Jackie	Terrance	\N	t	f
44	Louis	Jakes	\N	t	f
45	David	Jacobson	\N	t	f
47	Donny	Lewis	\N	t	f
48	Clyd	Lewis	\N	t	f
49	Mattie	Icee	\N	t	f
20	Jacko	Breslin	\N	f	f
46	Don	Jacques	\N	t	f
27	Jiles	Mcgrady	\N	t	f
50	Merna	McKredy	\N	t	f
26	jacab	macgrady	\N	t	f
51	Klyde	Zorros	\N	t	f
30	kathy	gelfeld	\N	t	f
36	kristopher	gelfeldt	\N	t	f
\.


--
-- Data for Name: officers; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY officers (officer_id, first_name, last_name, unit_id, rank, joined_gcpd_on, active) FROM stdin;
1	Jim	Gordon	\N	Commissioner	2000-01-01	t
2	John	Blake	1	Detective Sergeant	2008-01-03	t
3	Maggie	Sawyer	1	Captain	2004-12-05	t
4	Josh	Azeveda	1	Detective	2009-05-01	t
5	Roman	Cavallo	5	\N	2011-02-01	t
6	George	Bilbao	4	Lieutenant	2008-06-01	t
7	Nora	Fields	\N	Supervisor	2002-03-01	t
8	Harvey	Bullock	1	Detective	2000-08-01	t
9	Gillian	Loeb	5	\N	2000-01-01	t
10	Kelvin	Mao	2	\N	2011-01-01	t
11	Jordan	Rich	5	\N	2012-01-01	t
12	Raymond	Willis	6	Detective	2009-11-01	t
\.


--
-- Data for Name: suspects; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY suspects (case_id, criminal_id, became_suspect_on, dropped_as_suspect_on) FROM stdin;
1	13	2012-09-09	2012-10-01
2	3	2012-05-12	2012-08-01
3	2	2012-06-26	2012-08-15
3	3	2012-06-26	2012-08-15
4	6	2012-08-12	2012-08-15
4	3	2012-08-15	2012-08-30
5	8	2012-07-15	2012-09-20
5	5	2012-08-23	2012-09-20
6	2	2012-06-24	2012-08-20
7	5	2012-08-05	2012-09-20
8	2	2012-08-15	2012-09-20
9	3	2012-07-20	2012-10-01
10	12	2012-07-09	2012-09-01
10	3	2012-08-01	2012-09-01
11	3	2012-08-12	2012-10-04
11	8	2012-08-12	2012-10-04
12	7	2012-08-22	2012-10-15
12	12	2012-08-26	2012-10-15
13	6	2012-05-09	2012-06-15
14	2	2012-08-12	2012-08-30
15	5	2012-04-20	2012-09-11
16	2	2012-06-15	2012-07-20
17	8	2011-06-14	2011-06-20
17	3	2011-06-14	2011-06-20
18	5	2012-10-12	2012-10-17
18	8	2012-10-12	2012-10-17
19	1	2011-12-07	2012-09-15
20	1	2011-03-02	2012-01-04
21	9	2011-12-09	2012-10-01
22	11	2011-08-15	2011-10-02
23	12	2011-09-09	2011-10-01
24	9	2011-10-22	2011-12-01
26	13	2012-09-12	2012-10-01
27	13	2012-08-26	2012-10-15
28	9	2011-12-13	2011-12-25
29	12	2012-05-20	2012-08-30
30	11	2012-04-15	2012-09-20
31	11	2012-07-31	2012-09-20
32	9	2011-07-14	2011-08-20
33	12	2012-01-25	2012-03-14
34	2	2012-07-05	2012-09-20
35	3	2012-05-06	2012-09-20
36	7	2011-06-15	\N
37	6	2012-01-09	\N
38	4	2012-10-09	\N
39	6	2012-09-03	\N
40	6	2011-10-31	\N
41	3	2012-09-18	\N
42	2	2012-02-05	\N
42	8	2012-02-12	\N
43	3	2011-06-11	\N
44	5	2011-10-25	\N
45	2	2012-07-10	\N
46	8	2012-08-25	2012-10-13
47	1	2011-08-23	2012-10-18
48	3	2012-06-26	\N
49	4	2011-06-12	\N
50	5	2012-04-10	\N
\.


--
-- Data for Name: units; Type: TABLE DATA; Schema: public; Owner: profh
--

COPY units (unit_id, name, active) FROM stdin;
1	Major Crimes	t
2	SWAT	t
3	Quick Response Team	t
4	Homicide	t
5	Patrol	t
6	Internal Affairs	t
\.


--
-- Name: assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (case_id, officer_id);


--
-- Name: case_summary_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY case_summary
    ADD CONSTRAINT case_summary_pkey PRIMARY KEY (id);


--
-- Name: cases_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (case_id);


--
-- Name: crimes_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY crimes
    ADD CONSTRAINT crimes_pkey PRIMARY KEY (crime_id);


--
-- Name: criminals_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY criminals
    ADD CONSTRAINT criminals_pkey PRIMARY KEY (criminal_id);


--
-- Name: officers_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY officers
    ADD CONSTRAINT officers_pkey PRIMARY KEY (officer_id);


--
-- Name: suspects_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY suspects
    ADD CONSTRAINT suspects_pkey PRIMARY KEY (case_id, criminal_id);


--
-- Name: units_pkey; Type: CONSTRAINT; Schema: public; Owner: profh; Tablespace: 
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_pkey PRIMARY KEY (unit_id);


--
-- Name: cases_crimes_idx; Type: INDEX; Schema: public; Owner: profh; Tablespace: 
--

CREATE INDEX cases_crimes_idx ON cases USING btree (crime_id);


--
-- Name: officers_idx_lowercaserank; Type: INDEX; Schema: public; Owner: profh; Tablespace: 
--

CREATE INDEX officers_idx_lowercaserank ON officers USING btree (lower((rank)::text));


--
-- Name: officers_names_idx; Type: INDEX; Schema: public; Owner: profh; Tablespace: 
--

CREATE INDEX officers_names_idx ON officers USING btree (lower((last_name)::text), lower((first_name)::text));


--
-- Name: officers_units_idx; Type: INDEX; Schema: public; Owner: profh; Tablespace: 
--

CREATE INDEX officers_units_idx ON officers USING btree (unit_id);


--
-- Name: revise_case_summary_table; Type: TRIGGER; Schema: public; Owner: profh
--

CREATE TRIGGER revise_case_summary_table AFTER INSERT OR DELETE OR UPDATE ON cases FOR EACH STATEMENT EXECUTE PROCEDURE update_summary_table();


--
-- Name: assignments_case_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY assignments
    ADD CONSTRAINT assignments_case_id_fk FOREIGN KEY (case_id) REFERENCES cases(case_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: assignments_officer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY assignments
    ADD CONSTRAINT assignments_officer_id_fk FOREIGN KEY (officer_id) REFERENCES officers(officer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cases_crime_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_crime_id_fk FOREIGN KEY (crime_id) REFERENCES crimes(crime_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: officers_unit_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY officers
    ADD CONSTRAINT officers_unit_id_fk FOREIGN KEY (unit_id) REFERENCES units(unit_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: suspects_case_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY suspects
    ADD CONSTRAINT suspects_case_id_fk FOREIGN KEY (case_id) REFERENCES cases(case_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: suspects_criminal_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: profh
--

ALTER TABLE ONLY suspects
    ADD CONSTRAINT suspects_criminal_id_fk FOREIGN KEY (criminal_id) REFERENCES criminals(criminal_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: public; Type: ACL; Schema: -; Owner: profh
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM profh;
GRANT ALL ON SCHEMA public TO profh;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: units; Type: ACL; Schema: public; Owner: profh
--

REVOKE ALL ON TABLE units FROM PUBLIC;
REVOKE ALL ON TABLE units FROM profh;
GRANT ALL ON TABLE units TO profh;


--
-- PostgreSQL database dump complete
--

