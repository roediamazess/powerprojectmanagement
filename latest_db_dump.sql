--
-- PostgreSQL database dump
--

\restrict qtn8wLnnZYivi790bfKDW9KwAENAQA1pUumMjznR1l9rki9JHczoW3ehdaPkeml

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: propagate_arrangement_schedule_dates(); Type: FUNCTION; Schema: public; Owner: ppm
--

CREATE FUNCTION public.propagate_arrangement_schedule_dates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
          UPDATE arrangement_pickups
             SET pickup_start_date = NEW.start_date,
                 pickup_end_date = NEW.end_date,
                 updated_at = now()
           WHERE schedule_id = NEW.id;
          RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.propagate_arrangement_schedule_dates() OWNER TO ppm;

--
-- Name: sync_arrangement_pickup_dates(); Type: FUNCTION; Schema: public; Owner: ppm
--

CREATE FUNCTION public.sync_arrangement_pickup_dates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
          SELECT start_date, end_date
            INTO NEW.pickup_start_date, NEW.pickup_end_date
            FROM arrangement_schedules
           WHERE id = NEW.schedule_id;
          RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.sync_arrangement_pickup_dates() OWNER TO ppm;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO ppm;

--
-- Name: arrangement_batches; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.arrangement_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    status_id uuid NOT NULL,
    min_requirement_points smallint DEFAULT 0 NOT NULL,
    max_requirement_points smallint DEFAULT 0 NOT NULL,
    pickup_start_at timestamp with time zone,
    pickup_end_at timestamp with time zone,
    created_by uuid NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_arrangement_batches_pickup_window CHECK ((((pickup_start_at IS NULL) AND (pickup_end_at IS NULL)) OR ((pickup_start_at IS NOT NULL) AND (pickup_end_at IS NOT NULL) AND (pickup_start_at < pickup_end_at)))),
    CONSTRAINT ck_arrangement_batches_points_range CHECK ((min_requirement_points <= max_requirement_points))
);


ALTER TABLE public.arrangement_batches OWNER TO ppm;

--
-- Name: arrangement_jobsheet_entries; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.arrangement_jobsheet_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    period_id uuid NOT NULL,
    user_id uuid NOT NULL,
    work_date date NOT NULL,
    code_id uuid NOT NULL,
    note text,
    created_by uuid NOT NULL,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.arrangement_jobsheet_entries OWNER TO ppm;

--
-- Name: arrangement_jobsheet_periods; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.arrangement_jobsheet_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_arrangement_jobsheet_periods_date_range CHECK ((start_date <= end_date))
);


ALTER TABLE public.arrangement_jobsheet_periods OWNER TO ppm;

--
-- Name: arrangement_pickups; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.arrangement_pickups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    schedule_id uuid NOT NULL,
    user_id uuid NOT NULL,
    points smallint DEFAULT 1 NOT NULL,
    status_id uuid NOT NULL,
    picked_at timestamp with time zone DEFAULT now() NOT NULL,
    picked_by uuid NOT NULL,
    approved_at timestamp with time zone,
    approved_by uuid,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancel_reason text,
    pickup_start_date date NOT NULL,
    pickup_end_date date NOT NULL,
    pickup_range daterange GENERATED ALWAYS AS (daterange(pickup_start_date, pickup_end_date, '[]'::text)) STORED,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.arrangement_pickups OWNER TO ppm;

--
-- Name: arrangement_schedules; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.arrangement_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid,
    schedule_type_id uuid NOT NULL,
    note text,
    start_date date NOT NULL,
    end_date date NOT NULL,
    slot_count smallint DEFAULT 1 NOT NULL,
    status_id uuid NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_arrangement_schedules_date_range CHECK ((start_date <= end_date)),
    CONSTRAINT ck_arrangement_schedules_slot_count CHECK ((slot_count > 0))
);


ALTER TABLE public.arrangement_schedules OWNER TO ppm;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.audit_logs (
    id bigint NOT NULL,
    actor_user_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    before jsonb,
    after jsonb,
    meta jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_logs OWNER TO ppm;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: ppm
--

ALTER TABLE public.audit_logs ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: backup_runs; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.backup_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requested_by uuid,
    status text DEFAULT 'QUEUED'::text NOT NULL,
    file_path text,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.backup_runs OWNER TO ppm;

--
-- Name: health_score_answers; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_answers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    survey_id uuid NOT NULL,
    question_id uuid NOT NULL,
    selected_option_id uuid,
    value_date date,
    value_text text,
    note text,
    score_value numeric(8,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_answers OWNER TO ppm;

--
-- Name: health_score_question_options; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_question_options (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_id uuid NOT NULL,
    label text NOT NULL,
    score_value numeric(8,2) DEFAULT 0 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_question_options OWNER TO ppm;

--
-- Name: health_score_questions; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    section_id uuid NOT NULL,
    module text,
    question_text text NOT NULL,
    answer_type text NOT NULL,
    scoring_rule text,
    weight numeric(8,2) DEFAULT 1 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    required boolean DEFAULT true NOT NULL,
    note_instruction text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_questions OWNER TO ppm;

--
-- Name: health_score_sections; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    name text NOT NULL,
    weight numeric(8,2) DEFAULT 1 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_sections OWNER TO ppm;

--
-- Name: health_score_surveys; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_surveys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    template_version integer DEFAULT 1 NOT NULL,
    partner_id uuid,
    project_id uuid,
    year smallint NOT NULL,
    quarter smallint NOT NULL,
    status text DEFAULT 'Draft'::text NOT NULL,
    score_total numeric(8,2),
    score_by_category jsonb,
    score_by_scope jsonb,
    score_by_module jsonb,
    created_by uuid,
    submitted_at timestamp with time zone,
    share_token text,
    public_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_surveys OWNER TO ppm;

--
-- Name: health_score_templates; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.health_score_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    status text DEFAULT 'Active'::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.health_score_templates OWNER TO ppm;

--
-- Name: holidays; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.holidays (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.holidays OWNER TO ppm;

--
-- Name: lookup_categories; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.lookup_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lookup_categories OWNER TO ppm;

--
-- Name: lookup_values; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.lookup_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    value text NOT NULL,
    label text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_id uuid
);


ALTER TABLE public.lookup_values OWNER TO ppm;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sender_id uuid NOT NULL,
    recipient_id uuid NOT NULL,
    subject text,
    body text NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.messages OWNER TO ppm;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    body text,
    url text,
    read_at timestamp with time zone,
    actor_user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.notifications OWNER TO ppm;

--
-- Name: partner_contacts; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.partner_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    role_key text NOT NULL,
    name text,
    email public.citext,
    phone text,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.partner_contacts OWNER TO ppm;

--
-- Name: partners; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.partners (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cnc_id text NOT NULL,
    name text NOT NULL,
    status_id uuid,
    star smallint,
    room text,
    outlet text,
    system_live date,
    address text,
    area text,
    sub_area text,
    implementation_type_id uuid,
    system_version_id uuid,
    partner_type_id uuid,
    partner_group_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_visit date,
    last_visit_type text,
    last_project text,
    last_project_type text
);


ALTER TABLE public.partners OWNER TO ppm;

--
-- Name: permissions; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.permissions OWNER TO ppm;

--
-- Name: project_pic_assignments; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.project_pic_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    pic_user_id uuid,
    start_date date,
    end_date date,
    assignment_id uuid,
    status_id uuid,
    release_state_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.project_pic_assignments OWNER TO ppm;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    cnc_id text,
    name text NOT NULL,
    type_id uuid,
    status_id uuid,
    start_date date,
    end_date date,
    spreadsheet_id text,
    spreadsheet_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.projects OWNER TO ppm;

--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.role_permissions (
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


ALTER TABLE public.role_permissions OWNER TO ppm;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.roles OWNER TO ppm;

--
-- Name: time_boxings_no_seq; Type: SEQUENCE; Schema: public; Owner: ppm
--

CREATE SEQUENCE public.time_boxings_no_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.time_boxings_no_seq OWNER TO ppm;

--
-- Name: time_boxings; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.time_boxings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    no bigint DEFAULT nextval('public.time_boxings_no_seq'::regclass) NOT NULL,
    information_date date NOT NULL,
    type_id uuid NOT NULL,
    priority_id uuid NOT NULL,
    status_id uuid NOT NULL,
    user_id uuid NOT NULL,
    partner_id uuid,
    project_id uuid,
    description text,
    action_solution text,
    due_date date,
    completed_at timestamp with time zone,
    deleted_at timestamp with time zone,
    deleted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    user_position character varying(255)
);


ALTER TABLE public.time_boxings OWNER TO ppm;

--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL
);


ALTER TABLE public.user_roles OWNER TO ppm;

--
-- Name: users; Type: TABLE; Schema: public; Owner: ppm
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    profile_photo_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO ppm;

--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.alembic_version (version_num) FROM stdin;
0012_add_holidays
\.


--
-- Data for Name: arrangement_batches; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.arrangement_batches (id, name, status_id, min_requirement_points, max_requirement_points, pickup_start_at, pickup_end_at, created_by, approved_by, approved_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: arrangement_jobsheet_entries; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.arrangement_jobsheet_entries (id, period_id, user_id, work_date, code_id, note, created_by, updated_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: arrangement_jobsheet_periods; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.arrangement_jobsheet_periods (id, name, slug, start_date, end_date, is_default, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: arrangement_pickups; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.arrangement_pickups (id, schedule_id, user_id, points, status_id, picked_at, picked_by, approved_at, approved_by, cancelled_at, cancelled_by, cancel_reason, pickup_start_date, pickup_end_date, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: arrangement_schedules; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.arrangement_schedules (id, batch_id, schedule_type_id, note, start_date, end_date, slot_count, status_id, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.audit_logs (id, actor_user_id, action, entity_type, entity_id, before, after, meta, created_at) FROM stdin;
1	92fb134a-68bc-4409-a20d-8fa3775a720f	create	partner	6fbb4e76-fbbf-46be-9e0a-a0220772981f	null	{"name": "Partner Audit", "cnc_id": "CNC-AUDIT-1"}	null	2026-04-13 03:39:11.127714+00
2	92fb134a-68bc-4409-a20d-8fa3775a720f	create	compliance_survey	a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	null	{"year": 2026, "quarter": 2, "partner_id": null, "project_id": null}	null	2026-04-13 03:40:05.078058+00
3	92fb134a-68bc-4409-a20d-8fa3775a720f	queue	backup_run	097de19c-c403-4294-a8da-0d1db554399b	null	null	null	2026-04-13 03:58:33.261147+00
4	92fb134a-68bc-4409-a20d-8fa3775a720f	backup_run	backup_run	097de19c-c403-4294-a8da-0d1db554399b	null	null	{"status": "SUCCEEDED"}	2026-04-13 04:01:57.889677+00
5	92fb134a-68bc-4409-a20d-8fa3775a720f	create	compliance_survey	44cd9ede-4a3d-4860-86b9-1a314f4496c5	null	{"year": 2026, "quarter": 3, "partner_id": null, "project_id": null}	null	2026-04-13 04:19:15.163272+00
6	92fb134a-68bc-4409-a20d-8fa3775a720f	answer	compliance_survey	a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	null	null	{"question_id": "dc215732-0c54-4bbf-9501-3acda5c4de5a"}	2026-04-13 04:20:03.347466+00
7	92fb134a-68bc-4409-a20d-8fa3775a720f	answer	compliance_survey	a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	null	null	{"question_id": "dc215732-0c54-4bbf-9501-3acda5c4de5a"}	2026-04-13 04:20:42.686139+00
8	92fb134a-68bc-4409-a20d-8fa3775a720f	answer	compliance_survey	a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	null	null	{"question_id": "dc215732-0c54-4bbf-9501-3acda5c4de5a"}	2026-04-13 04:21:23.311367+00
9	92fb134a-68bc-4409-a20d-8fa3775a720f	update	user	9ca1f3c9-54a0-4c05-9e31-ce2aabbca236	{"name": "Dewi", "is_active": true}	{"name": "Dewi", "is_active": false}	null	2026-04-14 09:21:15.128539+00
10	92fb134a-68bc-4409-a20d-8fa3775a720f	update	user	9ca1f3c9-54a0-4c05-9e31-ce2aabbca236	{"name": "Dewi", "is_active": false}	{"name": "Dewi", "is_active": true}	null	2026-04-14 09:21:18.625752+00
11	92fb134a-68bc-4409-a20d-8fa3775a720f	update	user	92fb134a-68bc-4409-a20d-8fa3775a720f	{"name": "Komeng"}	{"name": "Komeng"}	null	2026-04-14 09:43:32.053729+00
\.


--
-- Data for Name: backup_runs; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.backup_runs (id, requested_by, status, file_path, started_at, finished_at, error, created_at, updated_at) FROM stdin;
097de19c-c403-4294-a8da-0d1db554399b	92fb134a-68bc-4409-a20d-8fa3775a720f	SUCCEEDED	/var/backups/ppm/backup_097de19c-c403-4294-a8da-0d1db554399b_20260413_040156.sql.gz	2026-04-13 04:01:56.698103+00	2026-04-13 04:01:57.892789+00	\N	2026-04-13 03:58:33.274846+00	2026-04-13 04:01:57.892803+00
\.


--
-- Data for Name: health_score_answers; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_answers (id, survey_id, question_id, selected_option_id, value_date, value_text, note, score_value, created_at, updated_at) FROM stdin;
ca924830-7da9-467f-8f97-55cd89ae6477	a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	dc215732-0c54-4bbf-9501-3acda5c4de5a	60002ec9-3825-4a64-a144-b1eafacc6a31	\N	\N	\N	100.00	2026-04-13 04:20:03.347466+00	2026-04-13 04:21:23.323307+00
\.


--
-- Data for Name: health_score_question_options; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_question_options (id, question_id, label, score_value, sort_order, created_at, updated_at) FROM stdin;
60002ec9-3825-4a64-a144-b1eafacc6a31	dc215732-0c54-4bbf-9501-3acda5c4de5a	Yes	100.00	10	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
5df9a2c4-1f53-4367-88f0-0866d26647ec	dc215732-0c54-4bbf-9501-3acda5c4de5a	Partially	50.00	20	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
4df1f38d-8b44-46fb-9f39-d7e313e7da2a	dc215732-0c54-4bbf-9501-3acda5c4de5a	No	0.00	30	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
955aa5ac-2aad-440f-bbbe-6c9ae8a65a35	d1f877ca-7e0d-4d5d-86ff-352cdaaf8f3a	Stable	100.00	10	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
2735c4ca-688f-4be6-a254-b6780c78afd6	d1f877ca-7e0d-4d5d-86ff-352cdaaf8f3a	Minor issues	70.00	20	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
a3ce4331-7e57-4ca3-a7e6-3fd5ea66d3d5	d1f877ca-7e0d-4d5d-86ff-352cdaaf8f3a	Frequent issues	30.00	30	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
631e53a3-9b6b-4d92-a5c1-dc58e1509bf1	d9373abe-5f88-4427-9b47-a96fb800ea1e	On track	100.00	10	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
a51993c7-b508-4cc6-8d1e-bf15ca80f634	d9373abe-5f88-4427-9b47-a96fb800ea1e	Slight delay	70.00	20	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
acf992db-dc99-419c-b218-5f45436e7d27	d9373abe-5f88-4427-9b47-a96fb800ea1e	Delayed	30.00	30	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
575f8683-c8da-4e3c-82fd-90e03a671b7c	9cb14de3-d8bc-45e3-8ca4-fe7a5a2bf092	High	100.00	10	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
4bdfa476-e651-44da-96c6-0ef52dd91daa	9cb14de3-d8bc-45e3-8ca4-fe7a5a2bf092	Medium	70.00	20	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
a47568ee-8e0e-4071-ae13-d013f5289b16	9cb14de3-d8bc-45e3-8ca4-fe7a5a2bf092	Low	30.00	30	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
\.


--
-- Data for Name: health_score_questions; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_questions (id, section_id, module, question_text, answer_type, scoring_rule, weight, sort_order, required, note_instruction, created_at, updated_at) FROM stdin;
dc215732-0c54-4bbf-9501-3acda5c4de5a	bba4c22b-2843-4242-a12d-031b1482a620	Support	SLA response met?	single_choice	\N	1.00	10	t	\N	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
d1f877ca-7e0d-4d5d-86ff-352cdaaf8f3a	bba4c22b-2843-4242-a12d-031b1482a620	System	System stability (incidents) under control?	single_choice	\N	1.00	20	t	\N	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
d9373abe-5f88-4427-9b47-a96fb800ea1e	0af2adf1-eec1-4a82-84d9-fa1e180b98fc	Project	Milestones on track?	single_choice	\N	1.00	10	t	\N	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
9cb14de3-d8bc-45e3-8ca4-fe7a5a2bf092	0af2adf1-eec1-4a82-84d9-fa1e180b98fc	Stakeholder	Stakeholder satisfaction (latest quarter)	single_choice	\N	1.00	20	t	\N	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
\.


--
-- Data for Name: health_score_sections; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_sections (id, template_id, name, weight, sort_order, created_at, updated_at) FROM stdin;
bba4c22b-2843-4242-a12d-031b1482a620	97563476-68f4-4fba-92f3-0ce06b7a52ad	Operations	0.50	10	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
0af2adf1-eec1-4a82-84d9-fa1e180b98fc	97563476-68f4-4fba-92f3-0ce06b7a52ad	Delivery	0.50	20	2026-04-13 04:18:29.243074+00	2026-04-13 04:18:29.243074+00
\.


--
-- Data for Name: health_score_surveys; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_surveys (id, template_id, template_version, partner_id, project_id, year, quarter, status, score_total, score_by_category, score_by_scope, score_by_module, created_by, submitted_at, share_token, public_enabled, created_at, updated_at) FROM stdin;
44cd9ede-4a3d-4860-86b9-1a314f4496c5	97563476-68f4-4fba-92f3-0ce06b7a52ad	1	\N	\N	2026	3	Draft	\N	\N	\N	\N	92fb134a-68bc-4409-a20d-8fa3775a720f	\N	AVbGm54P4GFp-NV8j4YO5w	t	2026-04-13 04:19:15.181352+00	2026-04-13 04:19:15.181358+00
a1aa2ecd-0c97-49ad-ba22-1b4079aa4a5b	97563476-68f4-4fba-92f3-0ce06b7a52ad	1	\N	\N	2026	2	Draft	100.00	{"Operations": 100.0}	\N	{"Support": 100.0}	92fb134a-68bc-4409-a20d-8fa3775a720f	\N	pwc7r9O4e4udIL5Zs5aW5g	t	2026-04-13 03:40:05.08975+00	2026-04-13 03:40:05.089756+00
\.


--
-- Data for Name: health_score_templates; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.health_score_templates (id, name, status, version, created_by, created_at, updated_at) FROM stdin;
97563476-68f4-4fba-92f3-0ce06b7a52ad	Compliance Template	Active	1	\N	2026-04-13 03:38:20.246306+00	2026-04-13 03:38:20.246306+00
\.


--
-- Data for Name: holidays; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.holidays (id, name, date, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: lookup_categories; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.lookup_categories (id, key, created_at, updated_at) FROM stdin;
96c82193-ea8b-4615-9c92-c67bacf9d284	arrangement.batch_status	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
9189770a-c1b4-45d4-a21c-e8801f392b05	arrangement.schedule_status	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
83048fd2-f3fe-4987-b982-02dd274cce86	arrangement.pickup_status	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
58e23b84-7ded-44f2-a5a3-7832c53c743a	arrangement.schedule_type	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
9426b4d3-fdf9-4043-9d19-8c5502c765c8	arrangement.jobsheet_code	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	time_boxing.type	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00
42cccfef-665f-4caf-8937-bf7f80e4e586	time_boxing.priority	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00
f47f7a34-ba68-4cb0-a588-439825841c84	time_boxing.status	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00
dbe0ee7c-0a78-46f7-8c88-c4669127827c	partner.status	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00
cbe28d61-c1e9-4b0c-bdb9-38298cf2adf4	project.status	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00
9668af5d-ace9-4323-91d3-f5604fa62227	partner.implementation_type	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00
c2947a13-34e4-4722-ad23-3d27498fcb10	partner.system_version	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00
a4c52a36-a590-4cdd-8a18-9249a3462252	partner.type	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00
8a3e711d-e193-4dea-b3e5-fbb73328eaec	partner.group	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00
10ecf6e0-efb3-4bbd-a67a-434f3fb8cce7	project.type	2026-04-15 04:03:01.750641+00	2026-04-15 04:03:01.750641+00
388863df-dd57-4853-8e57-aee51688453b	partner.area	2026-04-15 04:16:49.868387+00	2026-04-15 04:16:49.868387+00
0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	partner.sub_area	2026-04-15 04:16:49.868387+00	2026-04-15 04:16:49.868387+00
\.


--
-- Data for Name: lookup_values; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.lookup_values (id, category_id, value, label, sort_order, is_active, created_at, updated_at, parent_id) FROM stdin;
543005b4-6639-4add-88f6-311f6ffdf353	96c82193-ea8b-4615-9c92-c67bacf9d284	OPEN	Open	10	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
b343f4bc-85e4-41ac-9e77-ea0b554b07ed	96c82193-ea8b-4615-9c92-c67bacf9d284	APPROVED	Approved	20	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
983d7795-6f5b-42a9-9de8-f7479f010051	96c82193-ea8b-4615-9c92-c67bacf9d284	CLOSED	Closed	30	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
e5a999a7-4fdf-40f8-a2e2-b8db29af8289	9189770a-c1b4-45d4-a21c-e8801f392b05	OPEN	Open	10	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
864ff8fe-585d-4210-a923-1621abb32767	9189770a-c1b4-45d4-a21c-e8801f392b05	CLOSED	Closed	20	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
27ad5055-71f4-4fa5-8691-4ba724f87f9c	83048fd2-f3fe-4987-b982-02dd274cce86	PICKED	Picked	10	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
4312fa52-dd99-4fe5-a02f-ad21062b9eb6	83048fd2-f3fe-4987-b982-02dd274cce86	APPROVED	Approved	20	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
891c3822-0ee2-4f9e-bb04-b117ef6bcc20	83048fd2-f3fe-4987-b982-02dd274cce86	CANCELLED	Cancelled	30	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
91a430ba-fa8a-4e09-869c-a793b0ed45c9	58e23b84-7ded-44f2-a5a3-7832c53c743a	IMPLEMENTATION	Implementation	10	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
7dddcc89-a7ec-4280-b324-816a38565361	58e23b84-7ded-44f2-a5a3-7832c53c743a	VISIT	Visit	20	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
cd74aa56-85d6-47e3-91f5-8bd992c3e85f	58e23b84-7ded-44f2-a5a3-7832c53c743a	TRAINING	Training	30	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
dcde1705-8533-42e5-b4a3-f326d766c712	58e23b84-7ded-44f2-a5a3-7832c53c743a	SUPPORT	Support	40	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
cdc8b67a-21b8-43ce-b544-f1601312fbae	58e23b84-7ded-44f2-a5a3-7832c53c743a	OTHER	Other	50	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
4532907f-9261-4147-b1a2-f5f386d60141	9426b4d3-fdf9-4043-9d19-8c5502c765c8	WFO	WFO	10	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
b3c81cd0-1fd4-409c-8787-953e15244fdd	9426b4d3-fdf9-4043-9d19-8c5502c765c8	WFH	WFH	20	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
645fd86c-e6a6-4100-abc2-96c8c3b80be2	9426b4d3-fdf9-4043-9d19-8c5502c765c8	OFF	OFF	30	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
7ed01cd1-2c57-4d6f-b0cc-b3c266664990	9426b4d3-fdf9-4043-9d19-8c5502c765c8	SICK	SICK	40	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
da1073b8-1d0e-48ad-80b4-68b879100b6f	9426b4d3-fdf9-4043-9d19-8c5502c765c8	LEAVE	LEAVE	50	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
d5119dd8-9d24-4ccc-a130-2af5d560e83c	9426b4d3-fdf9-4043-9d19-8c5502c765c8	OTHER	OTHER	60	t	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00	\N
eab1c9f0-d34a-4d33-865f-e3bdf4e07338	dbe0ee7c-0a78-46f7-8c88-c4669127827c	ACTIVE	Active	10	t	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00	\N
87638c76-2429-441c-805e-b7b3a9752257	dbe0ee7c-0a78-46f7-8c88-c4669127827c	INACTIVE	Inactive	20	t	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00	\N
578c536b-bb30-4509-9720-095f15e071b5	cbe28d61-c1e9-4b0c-bdb9-38298cf2adf4	OPEN	Open	10	t	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00	\N
609f997c-f480-4da6-a452-d1bca6931c2e	cbe28d61-c1e9-4b0c-bdb9-38298cf2adf4	IN_PROGRESS	In Progress	20	t	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00	\N
7c4e65f1-7894-4acd-a434-6da3918c6356	cbe28d61-c1e9-4b0c-bdb9-38298cf2adf4	DONE	Done	30	t	2026-04-13 02:28:37.775746+00	2026-04-13 02:28:37.775746+00	\N
fbd83ddd-be5c-498a-81b3-aefb207dc124	9668af5d-ace9-4323-91d3-f5604fa62227	OPENING_RESTAURANT	Opening Restaurant	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
942eb834-f99f-43e8-ab0a-9eb6eaa14a58	c2947a13-34e4-4722-ad23-3d27498fcb10	CLOUD	Cloud	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
2496cfed-551c-4436-8a72-daf301050ac3	a4c52a36-a590-4cdd-8a18-9249a3462252	RESTAURANT	Restaurant	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
f85f20a6-40e9-4ae5-bfd5-c4643bae806f	9668af5d-ace9-4323-91d3-f5604fa62227	OPENING_HOTEL	Opening Hotel	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a4c52a36-a590-4cdd-8a18-9249a3462252	HOTEL	Hotel	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	c2947a13-34e4-4722-ad23-3d27498fcb10	DESKTOP	Desktop	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
4b2cb85d-fa37-486c-86d6-809621c484a9	8a3e711d-e193-4dea-b3e5-fbb73328eaec	CEMARA	Cemara	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
1fd30f9f-a081-4709-89d1-17e941c0e2a7	c2947a13-34e4-4722-ad23-3d27498fcb10	XPRESS	Xpress	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
9fd7de6c-317c-43e0-be51-e50d9088fcf3	8a3e711d-e193-4dea-b3e5-fbb73328eaec	THE_ALTS	The Alts	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
5ae684b3-a3d8-4703-a001-21035b54871c	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PHINISI_HOSPITALITY_CLARION_CLARO_MALEO_MAKASSAR	Phinisi Hospitality (Clarion Claro Maleo) Makassar	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
94c9f0bb-3e2a-42dd-a4fe-b779dbf31155	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SAMALI	Samali	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	8a3e711d-e193-4dea-b3e5-fbb73328eaec	EKOSISTEM_HOTEL_RESORT	Ekosistem Hotel & Resort	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
3271c59d-2f4d-4aae-b0ec-01ab476a54b1	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ARION_PARAMITA	Arion Paramita	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
68350c01-b4d1-4246-a289-c79b0160300b	8a3e711d-e193-4dea-b3e5-fbb73328eaec	AEROWISATA_HOTEL_MANAGEMENT	Aerowisata Hotel Management	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PARADOR_PARAMOUNT	Parador (Paramount)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
dcff7137-e65e-4721-bfa2-577ac260fbeb	9668af5d-ace9-4323-91d3-f5604fa62227	OPENING_EDUCATION	Opening Education	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
c5443aff-0d00-4df3-aad8-0d130850ee76	a4c52a36-a590-4cdd-8a18-9249a3462252	EDUCATION	Education	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
188c5960-7fa3-486a-b594-43ad321e00ce	8a3e711d-e193-4dea-b3e5-fbb73328eaec	REVEUR_HOSPITALITY	Reveur Hospitality	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
d7018e52-3eb7-4075-8a6b-202c7dbfc083	8a3e711d-e193-4dea-b3e5-fbb73328eaec	BATIQA_HOTEL_MANAGEMENT	Batiqa Hotel Management	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
3185a01f-eeee-49eb-aac9-4d3fad065460	a4c52a36-a590-4cdd-8a18-9249a3462252	VILLA	Villa	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
24e8eaf5-f179-4623-a5c1-44bbed901060	8a3e711d-e193-4dea-b3e5-fbb73328eaec	BAWAH_RESERVE	Bawah Reserve	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
e29102e0-0c78-4671-883a-80770c2d5b00	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ELENA	Elena	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
722ab05a-3a74-4a61-a16c-6b5fa5a7c6ff	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_FIDELIO	Migration from Fidelio	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
6109cf5a-d464-4597-82ae-44c0c2343552	8a3e711d-e193-4dea-b3e5-fbb73328eaec	LUXSO_VILLA_RESORT_MANAGEMENT	Luxso Villa & Resort Management	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
d0cf407a-7618-4450-b798-046ca14576d4	c2947a13-34e4-4722-ad23-3d27498fcb10	LITE	Lite	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
c1e3d369-277a-49f2-b8a5-7623da5865b6	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PRIMAHOTEL_MANAJEMEN_D_PRIMA	Primahotel Manajemen (D'Prima)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
e8771417-8cfb-4742-9239-b361765db63f	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_VHP	Migration from VHP	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
b526f24e-e110-4359-bb8c-d5da3d91f380	8a3e711d-e193-4dea-b3e5-fbb73328eaec	DAFAM_HOTEL_MANAGEMENT_DHM	Dafam Hotel Management (DHM)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
72a2fc8f-c7ba-4bed-90c1-96c5b6910530	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SANGO_HOTEL_MANAGEMENT	Sango Hotel Management	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
c9b3de12-b053-45fa-a5d3-305cbace4d03	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HOTEL_INTERNATIONAL_MANAGEMENT_HIM	Hotel International Management (HIM)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
44afd187-51f4-4801-860b-5ccdbe8f9a18	8a3e711d-e193-4dea-b3e5-fbb73328eaec	DEWARNA	Dewarna	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
e1e794bc-7bbf-468c-81bb-7e4bb2968308	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM	Migration from	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
d7fa6284-cd6b-4bad-996e-e5fd20beac3a	8a3e711d-e193-4dea-b3e5-fbb73328eaec	NAVAL	Naval	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
ff784809-b9f5-48bf-b3dc-ab533399751e	8a3e711d-e193-4dea-b3e5-fbb73328eaec	EL_HOTEL_INTERNATIONAL	eL Hotel International	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	8a3e711d-e193-4dea-b3e5-fbb73328eaec	JHL_COLLECTIONS	JHL Collections	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
c06866bb-60c5-41a5-ae4d-ee95edd2887d	8a3e711d-e193-4dea-b3e5-fbb73328eaec	FOSIA_HOTEL_MANAGEMENT	Fosia Hotel Management	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
034b1b75-4130-4e20-ba0c-690a835e80e0	8a3e711d-e193-4dea-b3e5-fbb73328eaec	BIG_BIRD	BIG - BIRD	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
8aea9f79-7c88-4d37-a2e7-04534b32b83e	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_COMANCHE	Migration from Comanche	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
b48c6277-d81d-4afe-a226-44f8b5b85019	a4c52a36-a590-4cdd-8a18-9249a3462252	CONVENTION	Convention	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
bd01bc16-4a9a-4c1f-bf7c-9292295270b4	8a3e711d-e193-4dea-b3e5-fbb73328eaec	DIARA_HOTEL_GROUP	Diara Hotel Group	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
b412cb84-7d39-4125-8d5b-7a0f14fc0504	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HOTEL_INDONESIA_PROPERTI_HIPRO	Hotel Indonesia Properti (HIPro)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
26c188d8-2bea-46f8-81e0-4d48ef95f4a6	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_MYOH	Migration from MYOH	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	8a3e711d-e193-4dea-b3e5-fbb73328eaec	MORA_GROUP	Mora Group	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
787810e4-5b4b-4129-adb0-0a5c67546a56	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SOVIA	Sovia	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
4523b31a-174a-4d40-aee8-02d12cc97824	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SWISS_BELHOTEL_INDONESIA	Swiss-belhotel Indonesia	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
726728c9-9b7e-4f73-b253-ed4da52676b9	8a3e711d-e193-4dea-b3e5-fbb73328eaec	WHIZ	Whiz	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
cf69fe67-ee71-437f-b8b6-d9017e93b10e	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ZURI_HOSPITALITY_MANAGEMENT_ZHM	Zuri Hospitality Management (ZHM)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
ea77a5c4-ded3-48bb-8d8c-0b825e85d6ce	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PADJADJARAN	Padjadjaran	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
1529fdc1-4ae1-454f-8e37-154a6948134d	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ADHI_KARYA_GRANDHIKA_INDONESIA	Adhi Karya (GranDhika Indonesia)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
b6de363a-4dc6-4712-964c-f6156ba64afa	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SINTESA	Sintesa	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
5b9ab11f-d885-4a87-8006-4ac5637bbcdf	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HERMES	Hermes	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
8bca21b7-bb1b-4581-9934-5c2aeb49783a	a4c52a36-a590-4cdd-8a18-9249a3462252	HEAD_QUARTER	Head Quarter	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
045a1448-ffb6-46a2-8101-a7361bd47550	8a3e711d-e193-4dea-b3e5-fbb73328eaec	CIPUTRA	Ciputra	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
eff96100-ce07-47c1-9365-e90088ee8562	8a3e711d-e193-4dea-b3e5-fbb73328eaec	DMC_HOSPITALITY_DINAMIKA_MULTI_COMPANY	DMC Hospitality (Dinamika Multi Company)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
6b3bb293-f0f7-4d4c-aa72-9e8c407d1ba2	8a3e711d-e193-4dea-b3e5-fbb73328eaec	BINTANG_LIMA_INDOLUXE	Bintang Lima (Indoluxe)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
a70f3070-a500-4a3a-8207-7a292edc2a4d	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ARCS_HOUSE_JAMBULUWUK	ARCS House (Jambuluwuk)	0	t	2026-04-14 07:55:10.324866+00	2026-04-14 07:55:10.324866+00	\N
4f67719b-8dec-4d7d-a0d6-dc336951d15c	c2947a13-34e4-4722-ad23-3d27498fcb10	ECOS	ECOS	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
c4f0c088-78c2-434b-9565-42683a4dbd16	8a3e711d-e193-4dea-b3e5-fbb73328eaec	WIKA_REALTY	WIKA Realty	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
7508fc4c-86ea-4d4e-bba1-31bb7982310a	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HOTEL_INDONESIA_GROUP_HIG	Hotel Indonesia Group (HIG)	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
74e6cb74-89c9-4d21-8410-2b77c74d6cd8	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_REALTA	Migration from Realta	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
c003422c-c07a-4f8d-8f94-c8b529273669	8a3e711d-e193-4dea-b3e5-fbb73328eaec	RAMAYANA_BALI	Ramayana Bali	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
0f8b16f7-fe11-4265-81f3-9436fd5aa50f	8a3e711d-e193-4dea-b3e5-fbb73328eaec	KYRIAD	Kyriad	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
290e5d8a-c56f-4e69-b3da-26805a82b2ac	8a3e711d-e193-4dea-b3e5-fbb73328eaec	LABERSA	Labersa	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
1c0e57d6-6695-41b8-8678-cf44bef057d0	8a3e711d-e193-4dea-b3e5-fbb73328eaec	LIVING_ASIA	Living Asia	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
669515b7-0c7c-4064-bd1b-95133b574a84	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SYAH_ESTABLISHMENT_HEAD_OFFICE_GUNAWARMAN	Syah Establishment Head Office (Gunawarman)	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
1520e95b-70d9-4240-97ab-002d96d08614	8a3e711d-e193-4dea-b3e5-fbb73328eaec	MORITZ_CORPORATION	Moritz Corporation	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
ee78c157-577a-429f-ade0-9a0e4d504506	9668af5d-ace9-4323-91d3-f5604fa62227	OPENING_CONVENTION	Opening Convention	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
2613c0c2-bb62-4be3-a25d-a5389041eedf	8a3e711d-e193-4dea-b3e5-fbb73328eaec	DISCOVERY	Discovery	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
3545ee81-be6c-44fd-b5ed-65d101d5a853	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PP_HOSPITALITY_PARK	PP Hospitality (Park)	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
4b85b056-1bd0-4cda-b8e6-b1bd9184d17b	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PANDANARAN_HOSPITALITY_MANAGEMENT	Pandanaran Hospitality Management	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
4d61701d-ad6c-4c88-9dd7-635396b0b475	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PANGERAN	Pangeran	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
da2341a4-4289-4431-a330-343e969ef15b	8a3e711d-e193-4dea-b3e5-fbb73328eaec	PARKSIDE	Parkside	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
a7d0fd6c-57cc-49c3-ba41-1e19020148e1	8a3e711d-e193-4dea-b3e5-fbb73328eaec	ARTOTEL_INDONESIA	Artotel Indonesia	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
0c02f3fc-beb4-4708-87c1-143077a8cfe7	9668af5d-ace9-4323-91d3-f5604fa62227	MIGRATION_FROM_PYXSIS	Migration from Pyxsis	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
2aed36c5-71e5-48da-9e73-994e5f234213	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SAHIRA	Sahira	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
51d71edf-55ca-4773-9e80-02519c048c5a	8a3e711d-e193-4dea-b3e5-fbb73328eaec	INTI_KERAMIK_PT_IKAI_TBK	Inti Keramik (PT. IKAI Tbk)	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
5552e1dc-feb4-4b89-b870-4d58f90bb88e	8a3e711d-e193-4dea-b3e5-fbb73328eaec	KARANIYA_EXPERIENCE_WINAWAN	Karaniya Experience (Winawan)	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
b7c14d25-8f3f-4270-ad99-82d1d6edb675	9668af5d-ace9-4323-91d3-f5604fa62227	NEW_EDUCATION	New Education	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
cbcafb66-f196-45e7-9a06-0625b32ad82c	8a3e711d-e193-4dea-b3e5-fbb73328eaec	SOTIS_HOSPITALITY_MANAGEMENT	Sotis Hospitality Management	0	t	2026-04-14 07:55:11.419338+00	2026-04-14 07:55:11.419338+00	\N
36b8a4d6-236a-4d39-b0d1-ada48e2a4e5a	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HORISON	Horison	0	t	2026-04-14 07:55:12.311553+00	2026-04-14 07:55:12.311553+00	\N
820da907-4ad2-4998-b3fd-c1f72cd43ba1	8a3e711d-e193-4dea-b3e5-fbb73328eaec	MEDIA	Media	0	t	2026-04-14 07:55:12.311553+00	2026-04-14 07:55:12.311553+00	\N
6a1269c4-3df7-4e2e-a787-32f82c0c46d8	8a3e711d-e193-4dea-b3e5-fbb73328eaec	HOTEL_INDONESIA_NATOUR_HIN_INNA	Hotel Indonesia Natour (HIN-INNA)	0	t	2026-04-14 07:55:12.311553+00	2026-04-14 07:55:12.311553+00	\N
656620cd-66d8-466b-9dc8-5d49d2a0647e	8a3e711d-e193-4dea-b3e5-fbb73328eaec	NAKULA_HOTEL_MANAGEMENT	Nakula Hotel Management	0	t	2026-04-14 07:55:12.311553+00	2026-04-14 07:55:12.311553+00	\N
42290ca3-70ab-445b-8b6f-7a92e7b06f76	dbe0ee7c-0a78-46f7-8c88-c4669127827c	freeze	Freeze	3	t	2026-04-14 17:35:33.15978+00	2026-04-14 17:35:33.15978+00	\N
ef31b8f4-84cf-48e6-a94b-06f84f2f818a	388863df-dd57-4853-8e57-aee51688453b	Bali	Bali	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
b6726b6f-1fc5-40d5-9ba2-f3115884146c	388863df-dd57-4853-8e57-aee51688453b	Lampung	Lampung	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
a095dd2b-f2e1-43f2-8d98-a71ab3adb111	388863df-dd57-4853-8e57-aee51688453b	Kepulauan Riau	Kepulauan Riau	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
1c6d8638-1e6f-4190-aadd-d201d22f7b7b	388863df-dd57-4853-8e57-aee51688453b	Sumatera Barat	Sumatera Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
e6640492-640e-4f53-a7e8-b765e07657b5	388863df-dd57-4853-8e57-aee51688453b	Jawa Barat	Jawa Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
e2abef77-d47b-4962-b44e-ed87aad380bd	388863df-dd57-4853-8e57-aee51688453b	Kepulauan Bangka Belitung	Kepulauan Bangka Belitung	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
d7ac720a-d493-4522-ace4-e19358fb8f70	388863df-dd57-4853-8e57-aee51688453b	Nusa Tenggara Timur	Nusa Tenggara Timur	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
d9b82e88-e571-4873-94d0-ae27051bbbf6	388863df-dd57-4853-8e57-aee51688453b	Kalimantan Selatan	Kalimantan Selatan	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
c5386ff6-93f9-4aa0-ad7d-86d19a0d7d68	388863df-dd57-4853-8e57-aee51688453b	Kalimantan Timur	Kalimantan Timur	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
d25eba46-0b98-415c-9457-4639aa7e82d4	388863df-dd57-4853-8e57-aee51688453b	Papua Barat	Papua Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
60e06895-650b-463c-a1bc-56961f461de3	388863df-dd57-4853-8e57-aee51688453b	Cambodia	Cambodia	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
7add4258-c35c-4728-9a71-c30d19c0f3a0	388863df-dd57-4853-8e57-aee51688453b	Jambi	Jambi	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
7a01f091-1c7b-4787-977f-2b33ae89712a	388863df-dd57-4853-8e57-aee51688453b	Laos	Laos	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
c85d2d31-0191-4b1b-9926-32713b313b23	388863df-dd57-4853-8e57-aee51688453b	Riau	Riau	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
aa133406-d970-402b-9f57-55a6775ada35	388863df-dd57-4853-8e57-aee51688453b	Jawa Tengah	Jawa Tengah	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
6e871d4c-0153-48d2-ab72-fca8e1c35039	388863df-dd57-4853-8e57-aee51688453b	Sulawesi Tenggara	Sulawesi Tenggara	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
3c00a00c-ad30-45a5-ab34-330c54b0b90a	388863df-dd57-4853-8e57-aee51688453b	Daerah Istimewa Yogyakarta	Daerah Istimewa Yogyakarta	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
f3dd4047-f2aa-4cab-b33e-910cfdc33550	388863df-dd57-4853-8e57-aee51688453b	Kalimantan Barat	Kalimantan Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
631fe4e4-e545-4d4f-89fc-ac3835583682	388863df-dd57-4853-8e57-aee51688453b	Jawa Timur	Jawa Timur	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
7535a4d2-b24d-418d-b189-1db21ce46ba8	388863df-dd57-4853-8e57-aee51688453b	Sulawesi Selatan	Sulawesi Selatan	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
a6cf6093-680f-4cc8-ab44-8512e23a975c	388863df-dd57-4853-8e57-aee51688453b	Sumatera Utara	Sumatera Utara	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
c8b531bb-211f-46cf-83c5-8f384fa5e5d5	388863df-dd57-4853-8e57-aee51688453b	Kalimantan Utara	Kalimantan Utara	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
aa409099-cc04-4dc6-ae59-ef5c27f0f857	388863df-dd57-4853-8e57-aee51688453b	Sulawesi Utara	Sulawesi Utara	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
5fe32125-873c-4cbd-8633-1b5d0c01066f	388863df-dd57-4853-8e57-aee51688453b	Sumatera Selatan	Sumatera Selatan	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
0614b208-6900-4131-89b8-75346dd63119	388863df-dd57-4853-8e57-aee51688453b	Papua	Papua	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
670a2022-8d14-4cfe-b1a9-3866ca069e69	388863df-dd57-4853-8e57-aee51688453b	Papua Tengah	Papua Tengah	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
a9e9969a-8807-46ef-aade-604a1c95bbee	388863df-dd57-4853-8e57-aee51688453b	Nusa Tenggara Barat	Nusa Tenggara Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
2db7be1e-4275-4308-928e-99f0858891d8	388863df-dd57-4853-8e57-aee51688453b	Sulawesi Tengah	Sulawesi Tengah	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
df9a12fe-dfa0-4398-9a16-a180130d2636	388863df-dd57-4853-8e57-aee51688453b	Nanggroe Aceh Darussalam	Nanggroe Aceh Darussalam	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
ec3d989f-6a90-4764-b3a2-35e881bb9a35	388863df-dd57-4853-8e57-aee51688453b	Bangka Belitung	Bangka Belitung	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
2e13513b-7787-4786-b927-168fa14c3cb9	388863df-dd57-4853-8e57-aee51688453b	Sulawesi Barat	Sulawesi Barat	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
01f03809-988a-407b-9fa3-d64ff8308a3f	388863df-dd57-4853-8e57-aee51688453b	Maluku	Maluku	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
004ffb36-8474-42cd-8266-2ca7a920c811	388863df-dd57-4853-8e57-aee51688453b	Papua Barat Daya	Papua Barat Daya	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
650d4f4e-0f48-4765-9362-3609e5cc0955	388863df-dd57-4853-8e57-aee51688453b	Banten	Banten	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
29c13f4a-c75e-4a00-89bd-82f49ba1daa2	388863df-dd57-4853-8e57-aee51688453b	Kalimantan Tengah	Kalimantan Tengah	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
e43d7c8e-40c1-4554-a96f-84b502bea12a	388863df-dd57-4853-8e57-aee51688453b	DKI Jakarta	DKI Jakarta	0	t	2026-04-15 09:14:12.683527+00	2026-04-15 09:14:12.683527+00	\N
80738fd0-6419-4aa5-806e-2b51819a9a0f	f47f7a34-ba68-4cb0-a588-439825841c84	Brain Dump	Brain Dump	0	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
f4b8221c-12b2-4828-845a-2b70712d403a	f47f7a34-ba68-4cb0-a588-439825841c84	Priority List	Priority List	1	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
2c8453fc-c6dc-469d-a8ca-b0606bc18dba	f47f7a34-ba68-4cb0-a588-439825841c84	Time Boxing	Time Boxing	2	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
94647a1c-2d0f-43f0-a2d9-9db1aee119bd	f47f7a34-ba68-4cb0-a588-439825841c84	Completed	Completed	3	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	42cccfef-665f-4caf-8937-bf7f80e4e586	Normal	Normal	0	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
e1606b31-e3c7-4096-8921-a3baf56542d1	42cccfef-665f-4caf-8937-bf7f80e4e586	High	High	1	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
af7012da-fe1e-4aaa-b079-14fcf3bc7b21	42cccfef-665f-4caf-8937-bf7f80e4e586	Urgent	Urgent	2	t	2026-04-15 11:23:32.992623+00	2026-04-15 11:23:32.992623+00	\N
0321f388-55b9-4bf1-a08e-93c7048a37cf	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	INCIDENT	Incident	10	t	2026-04-15 12:23:00.898164+00	2026-04-15 12:23:00.898164+00	\N
88e0c5bb-2f3f-4ed4-b2da-b72d6dd11e86	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	REQUEST	Request	20	t	2026-04-15 12:23:00.898164+00	2026-04-15 12:23:00.898164+00	\N
0a771a02-0299-4e57-a823-b12c1c7d4a8a	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	TASK	Task	30	t	2026-04-15 12:23:00.898164+00	2026-04-15 12:23:00.898164+00	\N
b309563c-ada2-4e07-8f9f-4a55c3db2a3d	42cccfef-665f-4caf-8937-bf7f80e4e586	LOW	Low	10	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
bfdc4110-6a67-4825-913d-741c66462880	42cccfef-665f-4caf-8937-bf7f80e4e586	MEDIUM	Medium	20	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
d1ec1039-9568-4fc1-98c7-b7056b7b0968	42cccfef-665f-4caf-8937-bf7f80e4e586	HIGH	High	30	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
28f45c81-ccc6-4c81-bded-9dc6b68be34b	42cccfef-665f-4caf-8937-bf7f80e4e586	URGENT	Urgent	40	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
de4e94a0-9755-47b6-a210-33a934f86fa2	f47f7a34-ba68-4cb0-a588-439825841c84	OPEN	Open	10	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
b282b6f1-83ac-47e3-bc44-7c9156b36bbf	f47f7a34-ba68-4cb0-a588-439825841c84	IN_PROGRESS	In Progress	20	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
e6a9181b-a8b4-4091-a387-9bb7092e79ce	f47f7a34-ba68-4cb0-a588-439825841c84	DONE	Done	30	t	2026-04-15 11:35:56.939472+00	2026-04-15 11:35:56.939472+00	\N
8df1e174-6803-4772-8d55-d0158eedd8c8	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	General	General	0	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
80d464a5-3f48-45ee-be61-cbeaa72e545f	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Medan	Kota Medan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a6cf6093-680f-4cc8-ab44-8512e23a975c
67673ce1-80f8-48d3-b129-d4181cb8b771	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Semarang	Kota Semarang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
91001f84-4374-4e3d-9013-4a165127c601	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kupaten Manggarai Barat	Kupaten Manggarai Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d7ac720a-d493-4522-ace4-e19358fb8f70
4d392df2-b803-4dca-83fb-b5b615cd5a18	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Badung	Kabupaten Badung	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
cc572594-30ee-4472-ba4c-e9be877758a0	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Tangerang	Kabupaten Tangerang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
7728f73f-29af-4d80-8ed1-0519fa26be2a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kecamatan Cikarang Utara	Kecamatan Cikarang Utara	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
417aa06d-4aac-47d5-9b50-71c6b46495f8	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jakarta Pusat	Kota Jakarta Pusat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
fa3b2888-b724-4e39-9288-b38ed5b56940	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Lombok Utara	Kabupaten Lombok Utara	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a9e9969a-8807-46ef-aade-604a1c95bbee
18674517-23aa-4dfa-8131-18427faf325f	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Manado	Kota Manado	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa409099-cc04-4dc6-ae59-ef5c27f0f857
45a306ed-98af-43a3-ad65-77730f20ee26	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Makassar	Kota Makassar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	7535a4d2-b24d-418d-b189-1db21ce46ba8
e74146de-ef98-4595-9dd0-15e0e3ea3423	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Yogyakarta	Kota Yogyakarta	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	3c00a00c-ad30-45a5-ab34-330c54b0b90a
375bd1be-c19e-452d-a300-d2575c3d500d	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jakarta Selatan	Kota Jakarta Selatan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
eb7c0347-45ac-471f-8ea9-4f5aa25b2e8e	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Bogor	Kota Bogor	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
a02d5ead-d940-4ac4-b1f4-47bd647f215a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jakarta Barat	Kota Jakarta Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
bed2bac6-f7cf-4407-a6f0-821cdc3834eb	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Bandar Lampung	Kota Bandar Lampung	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	b6726b6f-1fc5-40d5-9ba2-f3115884146c
bd531751-da0f-42d0-a13f-8bd40719ece7	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Bekasi	Kota Bekasi	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
faa6b515-927b-4f56-9e20-058c7fcaf295	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Tangerang	Kota Tangerang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
7a6a28f6-81a2-46d9-ab0e-7336c3f7984b	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Tasikmalaya	Kabupaten Tasikmalaya	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
e28771f0-4abd-472e-bfc8-4878b53def8d	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Ambon	Kota Ambon	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	01f03809-988a-407b-9fa3-d64ff8308a3f
65703379-a81d-491b-afe6-e647d6b68119	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Pekalongan	Kabupaten Pekalongan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
cf6d2149-9c5a-418c-bead-c9e1d2c87817	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Sukabumi	Kabupaten Sukabumi	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
bf5e3f09-e952-4efe-830b-cdef1f5f3148	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Surabaya	Kota Surabaya	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
5064fc30-421b-43b1-9098-fec6c7de3355	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Pekanbaru	Kota Pekanbaru	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c85d2d31-0191-4b1b-9926-32713b313b23
e36b8939-011c-45b9-bcab-dd687d607f1a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Karawang	Kabupaten Karawang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
7b6b394a-7dc6-4904-8adf-3c7f16936530	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Cirebon	Kota Cirebon	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
692185c7-1c66-4ca0-90b0-ee723ea5fff2	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Belitung	Kabupaten Belitung	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ec3d989f-6a90-4764-b3a2-35e881bb9a35
9a539607-aa6e-4e9e-ab46-070e52cd2782	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Bandung	Kota Bandung	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
e897f63d-ba91-4927-b678-9684d94a6235	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Magelang	Kabupaten Magelang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
d08b9d0d-58b4-46b2-b355-b0bf0f919cd2	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Kepulauan Anambas	Kabupaten Kepulauan Anambas	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a095dd2b-f2e1-43f2-8d98-a71ab3adb111
473d4603-df43-46e0-93a2-fe47346730fa	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bengkalis	Kabupaten Bengkalis	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c85d2d31-0191-4b1b-9926-32713b313b23
97b23cca-32e6-41b7-b896-e5a7151badff	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Biak	Kabupaten Biak	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	0614b208-6900-4131-89b8-75346dd63119
d9e85614-d723-43b5-b5c6-e462977b9b82	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Malang	Kota Malang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
fdfe37ca-ddf7-4683-9cf2-94cad6e9b6aa	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Mamuju	Kabupaten Mamuju	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	2e13513b-7787-4786-b927-168fa14c3cb9
455abee0-41a5-4096-aa12-e8f124d8d82a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jakarta Utara	Kota Jakarta Utara	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
e83531cc-5c81-454c-b369-bd91128068ef	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Vientiane	Vientiane	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	7a01f091-1c7b-4787-977f-2b33ae89712a
8f4ae704-e44e-480f-a33d-58c0883c5274	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jayapura	Kota Jayapura	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	0614b208-6900-4131-89b8-75346dd63119
6ddb67f3-de3f-4f24-94a3-4c254d75b098	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Preah Sihanouk	Preah Sihanouk	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	60e06895-650b-463c-a1bc-56961f461de3
2c76294c-a7b2-4036-95c6-f648076c9636	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Kupang	Kota Kupang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d7ac720a-d493-4522-ace4-e19358fb8f70
c16863bc-9ba6-456e-830b-6402aed1d35c	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Balikpapan	Kota Balikpapan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c5386ff6-93f9-4aa0-ad7d-86d19a0d7d68
ec0cdc31-67ed-4ed5-8ba4-7c9954d11289	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupate Mimika	Kabupate Mimika	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	670a2022-8d14-4cfe-b1a9-3866ca069e69
829f904f-6761-424b-ad49-29a5f3ccd684	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Kendari	Kota Kendari	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	6e871d4c-0153-48d2-ab72-fca8e1c35039
a3e9b90d-4388-40fb-8789-623db662bcaa	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Gianyar	Kabupaten Gianyar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
3742fd9a-e37f-4657-babc-b0f9528db991	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Banjarmasin	Kota Banjarmasin	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d9b82e88-e571-4873-94d0-ae27051bbbf6
232d8f44-b35d-4a6d-8c74-571aed597124	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Manokwari	Kabupaten Manokwari	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d25eba46-0b98-415c-9457-4639aa7e82d4
6a831a57-e42c-443e-bb7f-b27dd78507fc	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Pontianak	Kota Pontianak	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	f3dd4047-f2aa-4cab-b33e-910cfdc33550
6c182b7e-855c-4ddb-9e1f-07b6bb3e453b	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Gunung Kidul	Kabupaten Gunung Kidul	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	3c00a00c-ad30-45a5-ab34-330c54b0b90a
6d8f17ae-4e5f-4425-b937-49d45e20f733	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Denpasar	Kota Denpasar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
6beacb73-425f-45b9-b764-ef059c8794c6	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Cilegon	Kota Cilegon	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
456a3f12-4145-421f-8f2b-8248b160d2de	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bekasi	Kabupaten Bekasi	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
ad203958-11fa-4b23-a8fe-934603e2cbbe	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Palembang	Kota Palembang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	5fe32125-873c-4cbd-8633-1b5d0c01066f
f7a5a467-62bc-447f-a3e9-3d3b49e36e2c	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bogor	Kabupaten Bogor	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
86e8c9c3-a4e5-4da0-94a9-ec4a9761ce18	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bintan	Kabupaten Bintan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a095dd2b-f2e1-43f2-8d98-a71ab3adb111
b97e1a0a-0575-4465-a588-c65059fd3c2a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Sleman	Kabupaten Sleman	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	3c00a00c-ad30-45a5-ab34-330c54b0b90a
d2894a8e-5d44-40ed-b8a1-040f4887658e	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Buleleng	Kabupaten Buleleng	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
a55ac7ab-80a6-412a-a714-5f2a7e3b0ca0	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Surakarta	Kota Surakarta	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
e01a7dc7-32a4-44c7-bab2-9a8965dbd52f	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Cianjur	Kabupaten Cianjur	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
2b909e0e-81ce-48aa-b4b1-b75e02890448	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Cilacap	Kabupaten Cilacap	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
bc9d0ca1-37a2-4b82-93a1-367de01261bf	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Kebumen	Kabupaten Kebumen	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
fe796280-7e80-4f76-a44c-a0d8d4064d8e	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	PIC Assignment	PIC Assignment	1	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
a9f04a75-22c4-48ce-9cf0-26407cea3780	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Lombok Tengah	Kabupaten Lombok Tengah	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a9e9969a-8807-46ef-aade-604a1c95bbee
1ea9910b-d29a-42b8-8be5-ce171fcced68	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Batu	Kota Batu	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
43b0170e-9c4a-402b-8dc9-fbecb73bb58a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Pasuruan	Kabupaten Pasuruan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
e908664e-5835-4b6c-a8f4-9a76dc692e49	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Padang	Kota Padang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	1c6d8638-1e6f-4190-aadd-d201d22f7b7b
a5550f70-cf9d-43b6-8dc5-92fc4d2bdf92	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Batam	Kota Batam	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a095dd2b-f2e1-43f2-8d98-a71ab3adb111
e4c5df22-1a48-42dc-959d-e93a09356f91	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bandung Barat	Kabupaten Bandung Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
f4c16d07-4aa9-41eb-bf43-943a45f02539	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Bojonegoro	Kabupaten Bojonegoro	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
02b6e7a0-b056-47a1-a760-b99c11942dbe	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jakarta Timur	Kota Jakarta Timur	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
58ce3f79-efa7-485a-be24-11e4125fb0e5	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Palu	Kota Palu	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	2db7be1e-4275-4308-928e-99f0858891d8
60d907c7-3a8d-411e-9aa8-1a8928abe295	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Pematang Siantar	Kota Pematang Siantar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a6cf6093-680f-4cc8-ab44-8512e23a975c
9ed9946d-c882-489f-b143-bb939d06ac61	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Samosir	Kabupaten Samosir	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a6cf6093-680f-4cc8-ab44-8512e23a975c
7e67e3ed-d9be-494f-9b2a-d6321bf4a29d	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kecamatan Batu	Kecamatan Batu	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
7f633801-b475-4db7-9f0b-8cbc19ed59b7	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Lombok Barat	Kabupaten Lombok Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a9e9969a-8807-46ef-aade-604a1c95bbee
7fbc8c5f-e450-43e2-86ea-1e7138d252e1	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Tarakan	Kota Tarakan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c8b531bb-211f-46cf-83c5-8f384fa5e5d5
5e0b4223-2a4a-4ec1-9343-4c3937100a1e	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Banda Aceh	Kota Banda Aceh	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	df9a12fe-dfa0-4398-9a16-a180130d2636
013fb5f3-5c71-430a-af63-d5e39e19f140	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Banyuwangi	Kabupaten Banyuwangi	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
dcecc31e-c96b-4499-902a-6934657899a1	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Jember	Kabupaten Jember	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
78ad6c20-7853-4763-a283-d816b3885431	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Lubuk Linggau	Kota Lubuk Linggau	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	5fe32125-873c-4cbd-8633-1b5d0c01066f
eff778ba-25aa-4f80-affe-9215fa6778d8	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Mataram	Kota Mataram	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a9e9969a-8807-46ef-aade-604a1c95bbee
6ea8ecc6-4570-4da8-8d46-64fdd0b38d71	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Magelang	Kota Magelang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
841da1f9-0366-437e-b286-c101f51a6da4	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Jayapura	Kabupaten Jayapura	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	0614b208-6900-4131-89b8-75346dd63119
567f3b1b-ea5a-49cc-b000-6128b80a9b9d	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Banjar Baru	Kota Banjar Baru	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d9b82e88-e571-4873-94d0-ae27051bbbf6
8f2887bb-337e-4a1a-a49b-3f153a977568	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Ketapang	Kabupaten Ketapang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	f3dd4047-f2aa-4cab-b33e-910cfdc33550
a470f531-020a-404a-b8dc-66c68f2a50c9	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Muara Enim	Kabupaten Muara Enim	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	5fe32125-873c-4cbd-8633-1b5d0c01066f
f3eaac3b-c483-4d4a-a279-8c218b5d9be7	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Aceh Tengah	Kabupaten Aceh Tengah	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	df9a12fe-dfa0-4398-9a16-a180130d2636
7efec633-fece-4ac8-a0f2-fec011560da0	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Tangerang Selatan	Kota Tangerang Selatan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
d5604fea-b254-4840-b582-3a4243a98091	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Sawahlunto	Kota Sawahlunto	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	1c6d8638-1e6f-4190-aadd-d201d22f7b7b
36265608-b5b6-4eaf-a2e3-655ae99a5d80	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Semarang	Kabupaten Semarang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
419fe275-dc01-43c9-86a6-2e92c43bed79	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Kulon Progo	Kabupaten Kulon Progo	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	3c00a00c-ad30-45a5-ab34-330c54b0b90a
e51f3bee-100c-494d-b3f8-154aaeede3f8	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Banyumas	Kabupaten Banyumas	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
91cde412-6d7b-4249-bf55-5ebd521af1f0	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Biak Numfor	Kabupaten Biak Numfor	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	0614b208-6900-4131-89b8-75346dd63119
3ee36688-c7eb-47f0-9eb2-c2af15fa8d25	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Serang	Kabupaten Serang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
35bc85df-4676-4c2e-93cd-41569e8df072	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Serang	Kota Serang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	650d4f4e-0f48-4765-9362-3609e5cc0955
016fa175-04ea-4fd4-bdb3-86b49930da40	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Kempar	Kabupaten Kempar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c85d2d31-0191-4b1b-9926-32713b313b23
0eafba3a-3385-42f6-99ef-b32102a586df	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Samarinda	Kota Samarinda	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c5386ff6-93f9-4aa0-ad7d-86d19a0d7d68
1e1bd999-7c01-4985-9007-6a17c381ca9d	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Tegal	Kota Tegal	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
7ac5f7fb-5561-4a6d-8cb4-92a4907798d6	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Manggarai Barat	Kabupaten Manggarai Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d7ac720a-d493-4522-ace4-e19358fb8f70
efb9c684-a05a-4d8c-8620-842d8e1d191f	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Garut	Kabupaten Garut	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e6640492-640e-4f53-a7e8-b765e07657b5
c073e9bb-e328-4155-b76f-2dd074329ad9	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Palangka Raya	Kota Palangka Raya	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	29c13f4a-c75e-4a00-89bd-82f49ba1daa2
8edc0fb4-5bb4-4896-a584-627fd74a5847	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Blora	Kabupaten Blora	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
e91fb321-3213-4f49-a7ca-74a203734486	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Dumai	Kota Dumai	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c85d2d31-0191-4b1b-9926-32713b313b23
cc343d0d-c6f1-49c8-8a6e-e69d4a46a278	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Toba	Kabupaten Toba	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a6cf6093-680f-4cc8-ab44-8512e23a975c
c30921e4-e6ca-432c-a6bd-850fce6413b9	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Gresik	Kabupaten Gresik	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
355ae8ef-730a-4410-a597-199656078c04	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Paser	Kabupaten Paser	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c5386ff6-93f9-4aa0-ad7d-86d19a0d7d68
fde35038-2617-4e8b-a69c-03b8cbb935c2	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Sidoarjo	Kabupaten Sidoarjo	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	631fe4e4-e545-4d4f-89fc-ac3835583682
ebc15f28-d225-4246-b5f7-01cef399c200	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Jambi	Kota Jambi	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	7add4258-c35c-4728-9a71-c30d19c0f3a0
48310401-612f-40e5-9fdf-0a0a2e754f5e	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Sorong	Kota Sorong	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	004ffb36-8474-42cd-8266-2ca7a920c811
88dc1d1c-2f09-42f4-ac50-f9086e9d5a65	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Sumba Barat	Kabupaten Sumba Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	d7ac720a-d493-4522-ace4-e19358fb8f70
2d1386f1-238f-4773-b73d-39c52d8fa5a2	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Pekalongan	Kota Pekalongan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	aa133406-d970-402b-9f57-55a6775ada35
231addea-d85a-4686-9592-91f9ca62f7d5	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Lampung Tengah	Kabupaten Lampung Tengah	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	b6726b6f-1fc5-40d5-9ba2-f3115884146c
ec7de804-3ed4-484d-8d2e-5946afac62c9	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Simalungun	Kabupaten Simalungun	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	a6cf6093-680f-4cc8-ab44-8512e23a975c
5283a76c-2f77-4a9c-bef3-1cfe717bc31c	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Karangasem	Kabupaten Karangasem	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
f91ee375-dce2-4d58-9c6c-a0d69d791894	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Tabanan	Kabupaten Tabanan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
b194ea9a-8360-4f2d-9cef-cc05874c696a	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Jakarta Barat	Jakarta Barat	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	e43d7c8e-40c1-4554-a96f-84b502bea12a
0c6d6625-c0f1-4043-a043-4263e06734ed	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Ogan Komering Ulu	Kabupaten Ogan Komering Ulu	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	5fe32125-873c-4cbd-8633-1b5d0c01066f
c63f404f-079a-4dc7-87b9-a0192b1a1792	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Aceh Timur	Kabupaten Aceh Timur	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	df9a12fe-dfa0-4398-9a16-a180130d2636
2d61eef0-5d66-438b-9561-1c0ebb267bda	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Banggai	Kabupaten Banggai	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	2db7be1e-4275-4308-928e-99f0858891d8
ba9ae7a1-6925-45fd-b55b-f5bf995cee24	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Klungkung	Kabupaten Klungkung	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ef31b8f4-84cf-48e6-a94b-06f84f2f818a
f1a905b9-bbaa-4d75-9c28-697444484359	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Pangkal Pinang	Kota Pangkal Pinang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	ec3d989f-6a90-4764-b3a2-35e881bb9a35
fa296ae7-7764-4188-a6c9-f77ea9dcbe54	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Pelalawan	Kabupaten Pelalawan	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	c85d2d31-0191-4b1b-9926-32713b313b23
8ba7fb03-b0a9-4f3e-bce9-ed19dbf63707	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kota Singkawang	Kota Singkawang	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	f3dd4047-f2aa-4cab-b33e-910cfdc33550
acaed3e0-8aa5-4fbf-8894-ce61f15daf5e	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Sihanoukville	Sihanoukville	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	60e06895-650b-463c-a1bc-56961f461de3
cb4c8940-f232-4d78-bc3a-14444aca7a20	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Merauke	Kabupaten Merauke	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	0614b208-6900-4131-89b8-75346dd63119
ae554a7d-73ce-432b-8eec-0cfb9c4c60e8	0bceb6b5-0061-4f6e-ae23-0dec5d7384fd	Kabupaten Aceh Besar	Kabupaten Aceh Besar	0	t	2026-04-15 09:14:12.782531+00	2026-04-15 09:14:12.782531+00	df9a12fe-dfa0-4398-9a16-a180130d2636
ced36e5b-8236-47c1-ad25-1cf4323d0f81	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Update to Management	Update to Management	2	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
03d05e24-dd4e-4fba-b257-5cb0f78817e8	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Work Order	Work Order	3	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
19476d60-7dff-4973-91e3-f156c656b1c3	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Submission Maintenance	Submission Maintenance	4	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
906fd8d5-bc3a-46d3-94a7-b1914d65ec47	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Green Plan	Green Plan	5	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
07ca6d21-5843-4856-8667-10a2cf3df1f6	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Team Meeting	Team Meeting	6	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
4fe4b040-17c0-4763-94aa-4764c69bf2da	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Hotel Meeting	Hotel Meeting	7	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
64537827-c8db-41cc-a854-c0e3d0641928	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Project Preparation	Project Preparation	8	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
c77e712d-f987-483c-8005-a9e61873b006	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Flower Board	Flower Board	9	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
3980a337-dc61-4d8e-961d-a80b8e615a7b	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Request for Quotation	Request for Quotation	10	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
666b1a27-7e84-43cf-a4bb-f7f8d846773e	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	MAP	MAP	11	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
c5166ed9-cb08-4495-8138-457ecc03fcd8	9b61b4a3-5f17-43dc-9d0d-cfdb47fda1e8	Others Project	Others Project	12	t	2026-04-15 11:41:25.823068+00	2026-04-15 11:41:25.823068+00	\N
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.messages (id, sender_id, recipient_id, subject, body, read_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.notifications (id, user_id, type, title, body, url, read_at, actor_user_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: partner_contacts; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.partner_contacts (id, partner_id, role_key, name, email, phone, is_primary, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: partners; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.partners (id, cnc_id, name, status_id, star, room, outlet, system_live, address, area, sub_area, implementation_type_id, system_version_id, partner_type_id, partner_group_id, created_at, updated_at, last_visit, last_visit_type, last_project, last_project_type) FROM stdin;
330ab9d2-5035-41b2-9cc5-2d1de3c25f43	CNC-004	Partner Demo 4	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-04-13 02:35:05.063287+00	2026-04-13 02:35:05.063287+00	\N	\N	\N	\N
6fbb4e76-fbbf-46be-9e0a-a0220772981f	CNC-AUDIT-1	Partner Audit	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-04-13 03:39:11.127714+00	2026-04-13 03:39:11.127714+00	\N	\N	\N	\N
13c64d50-41f8-42d2-9433-8f12dd554e58	509	GranDhika Setiabudi Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	123	3	2016-07-25	Jl. Dr. Mansyur No.169, Tj. Rejo, Kec. Medan Sunggal, Kota Medan, Sumatera Utara 20122	Sumatera Utara	Kota Medan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1529fdc1-4ae1-454f-8e37-154a6948134d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-20	Retraining	20/11/2025	Retraining
1b2cf149-7130-4c06-84aa-ae025d650835	526	GranDhika Pemuda Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	136	5	2016-11-22	Jl. Pemuda No.80-82, Kembangsari, Kec. Semarang Tengah, Kota Semarang, Jawa Tengah 50133	Jawa Tengah	Kota Semarang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1529fdc1-4ae1-454f-8e37-154a6948134d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-03-01	Maintenance	01/03/2026	Maintenance
2086a617-8d3a-436b-ac19-4c7bac4e0d8a	1044	69 Resort - Labuan Bajo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	22	5	2025-01-09	Labuan Bajo, Kec. Komodo, Kabupaten Manggarai Barat, Nusa Tenggara Timur – 86754	Nusa Tenggara Timur	Kupaten Manggarai Barat	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
29997ef2-f8e8-42f3-a659-d3476dddf020	998	32do Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2024-04-11	Jl. Lebak Sari Jl. Petitenget No.77, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	fbd83ddd-be5c-498a-81b3-aefb207dc124	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
2c20bf6f-b3db-40f3-b521-83930411e7e0	905	Herloom Serviced Residence-Carstensz BSD	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	138	5	2023-03-15	Jl. Jenderal Sudirman No.1, Cihuni, Kec. Pagedangan, Kabupaten Tangerang, Banten 15332	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-08	Maintenance	27/01/2026	On Line Training
3ea91cc7-1d77-4c4c-8aa2-6d628a49940c	122	Grand Cikarang Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	168	0	2011-03-01	Cikarang Industrial Estate I, Pasirgombong, Jl. Jababeka Raya, Kec. Cikarang Utara, Jawa Barat, 17530	Jawa Barat	Kecamatan Cikarang Utara	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b2cb85d-fa37-486c-86d6-809621c484a9	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-14	Maintenance	14/02/2026	Maintenance
406069f5-f721-48f5-aeb7-5e5364ea211f	812	Dafam Express Jaksa Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	104	3	2019-09-19	Jl. Jaksa No.27-29, Kb. Sirih, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10340•(021) 3102229	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-13	Retraining	13/09/2024	Retraining
481b453a-fbe6-4dda-8789-1dcae8d27688	314	Jambuluwuk Oceano Gili Trawangan Resort Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	95	1	2013-05-01	Jl. Pantai Gili Trawangan, Gili Indah, Pemenang, Kabupaten Lombok Utara, Nusa Tenggara Barat 83352	Nusa Tenggara Barat	Kabupaten Lombok Utara	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2013-06-20	Implementation	05/03/2025	Remote Installation
4e8ee62d-e32d-49dc-912e-1ab45b032849	278	Jambuluwuk Residence Menteng	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	31	\N	\N	Jl. Riau No. 5-7, Menteng - Jakarta Pusat 10350	DKI Jakarta	Kota Jakarta Pusat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	8bca21b7-bb1b-4581-9934-5c2aeb49783a	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-05	Maintenance	05/02/2026	Maintenance
4ef9b947-b0f8-4d12-b8e0-5e02cc0f89f8	392	HO-JKT Swiss Belhotel Papua Jayapura	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Graha Multi Modern, Jl. Cikini Raya No. 44, Jakarta Pusat - 10330	DKI Jakarta	Kota Jakarta Pusat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	8bca21b7-bb1b-4581-9934-5c2aeb49783a	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
522f8bb9-1565-4ace-bc5b-d20142bd0a1d	614	Griya Sintesa Manado	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	188	\N	2016-01-01	Jl. Jend Sudirman, Gunung Wenang, Pinaesaan, Wenang, Pinaesaan Wenang Pinaesaan Wenang, Pinaesaan, Kec. Wenang, Kota Manado, Sulawesi Utara 95123	Sulawesi Utara	Kota Manado	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b6de363a-4dc6-4712-964c-f6156ba64afa	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-02-12	Implementation	12/02/2016	Implementation
53ef48ea-c971-4d1f-b010-be01123ba36a	335	Arbor Biz Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	80	3	2013-07-10	Kima Square, Jl. Perintis Kemerdekaan KM.16, Daya, Kec. Biringkanaya, Kota Makassar, Sulawesi Selatan 90242	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-02-11	Maintenance	12/02/2025	Remote Installation
55042e83-234f-4d59-a9e0-dec63121a536	327	Grand Zuri Malioboro Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	144	3	2013-06-01	Jl. P. Mangkubumi No.18, Gowongan, Kec. Jetis, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55233	Daerah Istimewa Yogyakarta	Kota Yogyakarta	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-06-02	Maintenance	02/06/2019	Maintenance
06c1134f-ed38-4049-9a98-24b6b58caf36	143	Arion Suites Hotel Kemang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	94	0	2011-01-08	Jl. Kemang Raya No.7, RT.4/RW.1, Bangka, Kec. Mampang Prpt., Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12730	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3271c59d-2f4d-4aae-b0ec-01ab476a54b1	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-28	Maintenance	28/01/2026	Maintenance
2538a4fe-1f75-4766-a645-ade363a78f61	96	Asana Grand Pangrango Bogor-Aero	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	97	1	2013-03-15	Padjadjaran Rd No.32, Babakan, Central Bogor, Bogor City, West Java 16143	Jawa Barat	Kota Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-04-12	Maintenance	12/04/2025	Maintenance
2d746ee9-a099-455f-8f72-570f0cccf21c	82	Arwana Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	107	5	2010-01-01	Jl. Mangga Besar Selatan No.8, RT.13/RW.1, Kec. Taman Sari, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11150	DKI Jakarta	Kota Jakarta Barat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-21	Maintenance	21/01/2026	Maintenance
42e81d91-2d3e-4982-b44b-ccec37a310e3	72	Arinas Hotel Lampung (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	1	59	0	2019-04-23	Jalan Raden Intan No.35 Gunung Sari, Tj. Karang, Engal, Kota Bandar Lampung, Lampung 35213	Lampung	Kota Bandar Lampung	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
4b82052d-f2d3-4658-934a-c29620c1640d	1005	Avenzel Hotel and Convention Cibubur	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	250	10	2024-01-09	Jl. Raya Kranggan No.69, RT.002/RW.016, Cibubur, Kec. Jatisampurna, Kota Bks, Jawa Barat 17433	Jawa Barat	Kota Bekasi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-16	Retraining	16/08/2025	Retraining
4f112e84-47af-40a5-8852-77d81faa8e75	455	Grand Inna Medan (Dharma Deli)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	132	3	2014-08-01	Jl. Balai Kota No.2, Pusat Kota, Kec. Medan Bar., Kota Medan, Sumatera Utara 20111	Sumatera Utara	Kota Medan	26c188d8-2bea-46f8-81e0-4d48ef95f4a6	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-07-05	Upgrade	05/07/2023	Upgrade
4fa4b72f-2589-45ca-85ef-74e48bde118f	448	D'Primahotel Mahkota Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	59	\N	2014-08-02	Kompleks Ruko Taman Mahkota Mutiara Blok A2 No. 21-23A, Kec. Benda Kel. Benda Tangerang Banten	Banten	Kota Tangerang	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-12-06	Maintenance	06/12/2024	Maintenance
50d82684-efb7-4ba7-bd4e-78673c0b13f9	503	GranDhika Iskandarsyah Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	238	5	2015-07-22	Jl. Iskandarsyah Raya No.65, RT.5/RW.2, Melawai, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1529fdc1-4ae1-454f-8e37-154a6948134d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-21	Maintenance	21/12/2025	Maintenance
dd7af610-fd9a-4624-8e34-2c7b6af7ae8e	753	Grand Metro Hotel Tasikmalaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	137	3	2018-06-11	Jl. HZ. Mustofa No.263, Nagarawangi, Kec. Cihideung, Kab. Tasikmalaya, Jawa Barat 46124	Jawa Barat	Kabupaten Tasikmalaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-01-13	Maintenance	13/01/2019	Maintenance
6b4b3c27-95a3-4d90-8631-c6c0494a9de6	1008	Cocana Resort Gili Trawangan - Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	83	5	2024-11-01	Jl. Pantai Gili Trawangan, Gili Indah, Kec. Pemenang, Kabupaten Lombok Utara, Nusa Tenggara Bar. 83352	Nusa Tenggara Barat	Kabupaten Lombok Utara	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	6109cf5a-d464-4597-82ae-44c0c2343552	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-20	Maintenance	21/01/2026	On Line Training
6c03ef5c-c8f6-4339-ab81-9c60e4427783	539	Guesthouse Rejeki I, II, III Ambon (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	1	124	1	2016-02-27	Kel Honipopu, Sirimau, Kota Ambon, Maluku	Maluku	Kota Ambon	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-03-05	Implementation	05/03/2016	Implementation
dc3b2adc-ac7c-4058-bba3-cf67544322a5	697	Dafam Marlin Hotel Pekalongan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	39	3	2017-06-01	Jl. Raya Wiradesa No.25, Mayangan, Kec. Wiradesa, Kabupaten Pekalongan, Jawa Tengah 51152	Jawa Tengah	Kabupaten Pekalongan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-19	Retraining	19/11/2024	Retraining
decf1005-1c8e-4f73-8688-4bfb571f28e6	451	Grand Inna Samudera Beach Sukabumi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	103	2	2015-01-05	Jl. Raya Cisolok - Pelabuhanratu, Cikakak, Kec. Pelabuhanratu, Kabupaten Sukabumi, Jawa Barat 43365	Jawa Barat	Kabupaten Sukabumi	26c188d8-2bea-46f8-81e0-4d48ef95f4a6	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-26	Retraining	26/03/2024	Retraining
f4bedd24-25c4-4afb-90cd-f0505d5db9c5	1031	Arjuna Hotel & Casino	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	236	9	2025-05-28	Sihanoukville\nCambodia	\N	\N	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-20	Implementation	20/06/2025	Implementation
09d1c995-b9f4-4f8c-aece-4d13305cbccd	746	Batiqa Hotel Darmo Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	87	3	2018-05-05	Jl. Darmokali No.60, Darmo, Wonokromo, Surabaya\nJawa Timur 60241	Jawa Barat	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-24	Retraining	24/08/2025	Retraining
153833ac-09c6-4372-a3ec-9fbea3465067	627	Batiqa Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	133	3	2016-05-04	Jl. Jenderal Sudirman No.17, Simpang Tiga, Kec. Bukit Raya, Kota Pekanbaru, Riau 28284	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-20	Retraining	20/09/2025	Retraining
1a1d5552-9ff6-4926-bc4f-a8383e5cf285	968	Batiqa Hotel Karawang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	137	3	2023-09-01	Kawasan Industri Suryacipta, Jl. Surya Utama No.C-1, Kutamekar, Kec. Ciampel, Karawang, Jawa Barat 41363	Jawa Barat	Kabupaten Karawang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-10-20	Implementation	06/02/2024	On Line Training
2dd6eedd-9089-49f8-898e-9d069063f707	989	Bentani Hotel & Residence - Cirebon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	95	9	2024-07-01	Jl. Siliwangi No.69, Kesenden, Kec. Kejaksan, Kota Cirebon, Jawa Barat 45121	Jawa Barat	Kota Cirebon	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-28	Retraining	29/01/2026	On Line Training
34ca9efe-bf13-41e9-b5e9-a952c34da562	662	Batiqa Hotel Cirebon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	108	0	2017-04-01	Jl. DR. Cipto Mangunkusumo No.99, Sunyaragi, Kec. Kesambi, Kota Cirebon, Jawa Barat 45131	Jawa Barat	Kota Cirebon	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-15	Retraining	15/02/2026	Retraining
5743892e-0f81-4c21-9a4f-80c841f8c6eb	960	Dafam Hotel Belitung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	65	5	2023-06-29	Jl. Tj. Pandan - Tj. Kelayang, Keciput, Sijuk, Kabupaten Belitung, Kepulauan Bangka Belitung 33414	Bangka Belitung	Kabupaten Belitung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-02	Maintenance	17/02/2025	Remote Installation
6cc363d7-3ac7-4bbd-b0a4-010eef6e8044	820	D'Primahotel Losari Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	115	5	2019-12-01	Jl. Pattimura No. 9, Baru, Kec. Ujung Pandang, Kota Makassar, Sulawesi Selatan 90174	Sulawesi Selatan	Kota Makassar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-04	Maintenance	04/10/2024	Maintenance
6f438ceb-6a33-40b0-a19e-65fea916b129	512	d'primahotel Petitenget Seminyak	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	112	2	2023-03-17	Jalan Petitenget No.168, Kerobokan Kelod, Seminyak, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-23	Maintenance	23/08/2024	Maintenance
7060de76-65e4-4ae8-99b1-38e0e4f253ec	833	Jambuluwuk Thamrin Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	71	5	2020-01-04	Jl. Riau No.5-7, Gondangdia, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10350	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-05-16	Implementation	15/01/2026	On Line Training
733d8dfe-4574-4d55-8927-148c1654bb46	336	Grand Pacific Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	58	3	2013-07-01	Jl. HOS Tjokroaminoto No.100, Pasir Kaliki, Kec. Cicendo, Kota Bandung, Jawa Barat 40115	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
590f4406-2530-4795-b3bf-117c779b1fec	271	Parador Hotel & Resorts	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Paramount Plaza, Gading, Jl. Boulevard Raya Gading Serpong No.Kav. 1, Serpong, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-21	Retraining	04/06/2024	On Line Training
59852e82-a483-4a9b-a709-960d5211edc3	1023	Moritz Hills Borobudur Resort & Spa Magelang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	18	2	2025-02-21	Jl. Borobudur Ngadiharjo, Dusun Bumisegoro\nKab. Magelang, Jawa Tengah Indonesia	Jawa Tengah	Kabupaten Magelang	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1520e95b-70d9-4240-97ab-002d96d08614	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-17	Implementation	02/03/2025	Remote Installation
59f66ab9-7bc1-4782-b84c-fa0fa9c79e16	337	Avira Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	37	2	2014-01-01	Jalan Adiyaksa No.18A, Masale, Panakkukang, Pandang, Kec. Panakkukang, Kota Makassar, Sulawesi Selatan 90232	Sulawesi Selatan	Kota Makassar	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2015-05-19	Maintenance	22/04/2019	Special Request
5ab0ec3e-25d8-472d-8e1a-3e09cca36676	922	Bawah Reserve Resort	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2023-01-01	Pulau Bawah, Desa Kiabu, Kecamatan Siantan\nSelatan Kebupatan Kepulauan Anambas, Provinsi Kepulauan Riau	Kepulauan Riau	Kabupaten Kepulauan Anambas	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	3185a01f-eeee-49eb-aac9-4d3fad065460	24e8eaf5-f179-4623-a5c1-44bbed901060	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-03-09	Implementation	09/03/2023	Implementation
5d29e288-fd25-492e-82ea-cd72cbd079ce	437	Bali Paragon Resort Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	400	5	2015-05-15	Jl. Raya Kampus Unud, Jimbaran, Bali, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	188c5960-7fa3-486a-b594-43ad321e00ce	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-08-12	Maintenance	12/08/2023	Maintenance
df4594b0-8e84-4b3d-839d-ff12eda22c5b	170	Grand Zuri Duri	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	111	\N	2009-12-31	Jl. Hangtuah No. 26, Babussalam, Kec. Mandau, Kabupaten Bengkalis, Riau 28784	Riau	Kabupaten Bengkalis	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-21	Maintenance	21/07/2025	Maintenance
e108ac30-6437-42b3-894d-aedc7c1c61fe	699	Asana Biak Hotel Papua-Aero	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	47	3	2018-01-02	Jl. M Yamin No.04, Mandala, Biak Kota, Kabupaten Biak Numfor, Papua 98111	Papua	Kabupaten Biak	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	68350c01-b4d1-4246-a289-c79b0160300b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-05-08	Retraining	08/05/2023	Retraining
e1226384-731f-473c-8029-f3528f134095	344	Atria Hotel Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	178	5	2013-01-10	Jl. Letjend S. Parman No.87 - 89, Purwantoro, Kec. Blimbing, Kota Malang, Jawa Timur 65122	Jawa Timur	Kota Malang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-10-02	Maintenance	22/02/2024	Remote Installation
e159759c-5e59-491e-bb0c-f8a01f9d0260	89	Java Paragon Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	304	0	2009-12-21	Jl. Mayjen Sungkono No.101-103, Dukuh Pakis, Kec. Dukuhpakis, Kota SBY, Jawa Timur 60224	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	188c5960-7fa3-486a-b594-43ad321e00ce	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-19	Maintenance	19/11/2025	Maintenance
e47fd0a5-ad6a-4af0-9ad6-c732564b9c6e	440	Grand Maleo Hotel & Convention Mamuju	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	131	3	2014-08-06	Jl. Yos Sudarso No.51, Binanga, Kec. Mamuju, Kabupaten Mamuju, Sulawesi Barat 91511	Sulawesi Barat	Kabupaten Mamuju	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-07-31	Retraining	31/07/2024	Retraining
e6022d14-9ac2-44c6-9b6f-e1201010572e	64	Bali Rich Luxury Villas & Spa Seminyak	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	29	0	2007-01-01	Jl. Mertanadi No.29, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
59d1c969-9c85-4481-b2f2-35376c0356dc	936	Khas Malioboro Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	141	5	2023-01-16	Jl. Gadean No.3, Ngupasan, Kec. Gondomanan, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55122	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-02-04	Implementation	04/02/2023	Implementation
59e31f95-3412-487c-aa14-60a023fd7953	3	Power Pro HQ	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Gading Kirana Utara Blok F10 No. 20-21, Kelapa Gading Barat, Kelapa Gading, Jakarta Utara 14240 - Indonesia	DKI Jakarta	Kota Jakarta Utara	\N	\N	\N	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
5a10ac13-a66a-4cbc-ada9-f747274172e5	214	Settha Palace Hotel Laos (Belmon Int'l Hotel)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	29	2	2012-09-01	6 Pang Kham Street, Vientiane, Laos	Laos	Vientiane	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2012-10-14	Implementation	14/10/2012	Implementation
5a808269-a953-4284-8a63-86f804bcd6b0	1053	Swiss-Belboutique Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	122	5	\N	Jl. Jend. Sudirman No.69, Terban, Kec. Gondokusuman, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55224	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-12	Implementation	30/12/2025	Remote Installation
5b6538ff-0ab5-4be3-9a2d-626dc9c38aa5	769	Sutasoma Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	111	6	2018-10-12	Jl. Darmawangsa III No. 2, RT.006/RW.001, Pulo, Kebayoran Baru, Jakarta Selatan 12160	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-04-05	Maintenance	05/04/2023	Maintenance
5c5427ba-a685-41cb-8074-c2b26c6606ce	872	Suni Hotel Abepura Jayapura	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	142	8	2021-07-01	Jl. Baru Ps. Lama Abepura, Wai Mhorock, Kec. Abepura, Kota Jayapura, Papua 99225	Papua	Kota Jayapura	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	da2341a4-4289-4431-a330-343e969ef15b	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-05-28	Maintenance	28/05/2025	Maintenance
5ef5350c-7ad0-4c4a-9332-178016739f28	984	Khayangan Beach Club Sihanoukville - Cambodia	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	0	6	2024-03-01	Otres Marina Road, 833, Preah Sihanouk 18000, Kamboja	Cambodia	Preah Sihanouk	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-29	Retraining	12/12/2025	On Line Training
0bfd2ffc-2b50-4410-b413-a610bf418901	51	Cambridge Hotel Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	242	0	2008-10-18	Jl. S. Parman No.217, Petisah Tengah, Kec. Medan Petisah, Kota Medan, Sumatera Utara 20152	Sumatera Utara	Kota Medan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-17	Maintenance	17/09/2024	Maintenance
1d6ab38b-d853-4994-9c86-254f5b880ed7	139	Claro Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	585	15	2011-09-01	Jl. A. P. Pettarani No.03, Mannuruki, Kec. Tamalate, Kota Makassar, Sulawesi Selatan 90221	Sulawesi Selatan	Kota Makassar	722ab05a-3a74-4a61-a16c-6b5fa5a7c6ff	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-21	Maintenance	21/11/2025	Maintenance
311ab5e1-2013-49d4-a797-8cd55293b10d	1033	Commodious Hotel Kupang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	50	\N	2025-09-30	Jl. Perintis Kemerdekaan III, Klp. Lima, Kec. Klp. Lima, Kota Kupang, Nusa Tenggara Tim. 85228	Nusa Tenggara Timur	Kota Kupang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-01	Implementation	01/10/2025	Implementation
37e21909-0b75-4739-a85f-9535017a3826	402	Crown Prince Hotel Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	211	3	2014-04-01	Jl. Basuki Rahmat No.123-127, Embong Kaliasin, Kec. Genteng, Kota SBY, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-03	Maintenance	03/03/2025	Maintenance
3d13d842-5e60-4209-9d8a-e0d7d96519dd	993	d'primahotel Bandar Balikpapan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	96	1	2024-10-10	Jl. Jend Sudirman No. 11, Komplek Ruko Bandar No.5-15 Blok G, Klandasan Ulu, Kec. Balikpapan Kota, Kota Balikpapan, Kalimantan Timur 76112	Kalimantan Timur	Kota Balikpapan	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-31	Implementation	31/10/2024	Implementation
3df873fa-6d6d-4280-b601-7e3ee5e66ca7	406	Cendrawasih 66 Hotel Timika	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	87	2	2014-04-01	Kwamki, Kec. Mimika Baru, Kabupaten Mimika, Papua Tengah 99971	Papua Tengah	Kabupate Mimika	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	e29102e0-0c78-4671-883a-80770c2d5b00	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2021-02-05	Maintenance	05/02/2021	Maintenance
4446e7b1-8c5a-4ba7-a9d9-9b1717bb57de	353	Claro Hotel & Convention Kendari	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	258	6	2013-12-19	Jl. Edi Sabara No.89, Lahundape, Kendari Bar., Kota Kendari, Sulawesi Tenggara 93121	Sulawesi Tenggara	Kota Kendari	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-16	Upgrade	16/02/2025	Upgrade
6007c381-dd8c-4767-80e0-607b334b9b6d	937	Khas Tugu Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	132	5	2023-01-16	Jl. Pangeran Diponegoro No.99, Bumijo, Kec. Jetis, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55231	Daerah Istimewa Yogyakarta	Kota Yogyakarta	74e6cb74-89c9-4d21-8410-2b77c74d6cd8	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-02-08	Implementation	08/02/2023	Implementation
61faabce-57c6-4338-93a6-422f0f4342d0	856	Kupu Kupu Barong2 Villas & Spa Ubud Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	55	0	2020-10-30	Jl. Raya Kedewatan, Kedewatan, Kecamatan Ubud, Kabupaten Gianyar, Bali 80571	Bali	Kabupaten Gianyar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-04-17	Retraining	17/04/2023	Retraining
62b304ee-e439-4b87-a092-0f5d56fed544	35	Swiss-Belhotel Borneo Banjarmasin	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	140	6	\N	Jl. Pangeran Antasari No.86A, Kelayan Luar, Kec. Banjarmasin Tim., Kota Banjarmasin, Kalimantan Selatan 70241	Kalimantan Selatan	Kota Banjarmasin	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-03-23	Maintenance	30/04/2025	On Line Training
64e4a60a-6e9e-477e-a57d-c4b9f5bbbe43	130	Mansinam Beach Resort Manokwari	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	45	\N	2011-04-30	Jl. Pasir Putih No.7, Pasir Putih, Kec. Manokwari Tim., Kabupaten Manokwari, Papua Bar. 98313	Papua Barat	Kabupaten Manokwari	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2021-09-15	Maintenance	15/09/2021	Maintenance
6562a9b5-31e7-4966-b0ff-845908d01b5c	28	Kapuas Dharma (2)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	190	2	\N	Jl. Budi Karya, Benua Melayu Darat, Kec. Pontianak Sel., Kota Pontianak, Kalimantan Barat 78243	Kalimantan Barat	Kota Pontianak	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-02	Maintenance	02/08/2024	Maintenance
69043bf5-9691-4ff9-ad36-dd3e33f8268b	176	Kristal Hotel Kupang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	139	0	2011-12-01	Jl. Timor Raya No.59, Pasir Panjang, Kec. Kota Lama, Kota Kupang, Nusa Tenggara Tim. 85228	Nusa Tenggara Timur	Kota Kupang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-19	Maintenance	19/10/2025	Maintenance
69234248-4f45-4f2c-a70f-8a00f817c11d	1006	Jungwok Resort - Gunung Kidul	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	40	3	2024-11-01	Jl. Terminal Jungwok, Pendowo, Jepitu, Kec. Girisubo, Kabupaten Gunungkidul, Daerah Istimewa Yogyakarta 55883	Daerah Istimewa Yogyakarta	Kabupaten Gunung Kidul	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-25	Retraining	25/07/2025	Retraining
75a857bd-5deb-42e1-bb6f-2011931be26e	395	Intesa School of Hospitality (15 User)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	35	\N	\N	 Jl. Harjono No.122, Gunungketur, Pakualaman, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55111	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2013-12-19	Implementation	19/12/2013	Implementation
75e27541-f57d-46cd-915d-8d5aa7c58d51	1060	eL Hotel & Resort Bali - Sanur	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	94	3	\N	Wisma Werdhapura, Jalan Kusuma Sari No. 1, Sanur, Denpasar Selatan, Kota Denpasar, Bali.	Bali	Kota Denpasar	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ff784809-b9f5-48bf-b3dc-ab533399751e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-04-09	Implementation	09/04/2026	Implementation
4ab0bfe1-cc8f-443a-b76f-7caa425c8137	1038	d'prima Wellness Terminal 1A	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	50	1	2025-07-01	Lobby Kedatangan, Terminal 1 A, Bandara Soekarno Hatta\nKota Tangerang, Banten 15126	Banten	Kota Tangerang	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-26	Maintenance	26/11/2025	Maintenance
534cc1ad-8120-45e5-98d7-7d67b8ea89bf	1039	d'prima Wellness Terminal 3	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	81	1	2025-07-01	Bandar Udara Internasional Soekarno–Hatta Terminal 3, Gate 4D 2nd Floor, Kota Tangerang, Banten 15126	Banten	Kota Tangerang	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-27	Maintenance	27/11/2025	Maintenance
e7f19974-46d7-44d3-b648-fb83d8ae3d19	669	Greenotel Hotel Cilegon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	91	3	2016-12-01	Komplek Cilegon Green Megablock, Jl. Ahmad Yani No.33-34, Cibeber, Kec. Cibeber, Kota Cilegon, Banten 42426	Banten	Kota Cilegon	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-02-19	Retraining	19/02/2023	Retraining
eb156bac-69d5-42a9-ae61-05bec2345f4c	87	Grand Zuri Jababeka	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	130	0	2010-03-01	Jl. Niaga Raya Blok AA No.2, Pasirsari, Cikarang Sel., Kabupaten Bekasi, Jawa Barat 17530	Jawa Barat	Kabupaten Bekasi	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-24	Maintenance	29/01/2026	On Line Training
ec286442-05d7-45e4-b0b9-4bc5226bd7d6	688	Bumi Surabaya City Resort	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	243	13	2017-05-01	Jl. Jend Basuki Rakhmat No.106-128, Embong Kaliasin, Kec. Genteng, Kota SBY, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-08	Maintenance	08/02/2026	Maintenance
efa6a160-eede-4a5f-a907-9cceb9b67149	180	Algoritma Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	117	0	2011-09-09	Jl. Dr. M. Isa No.988, Duku, Kec. Ilir Tim. II, Kota Palembang, Sumatera Selatan 30114	Sumatera Selatan	Kota Palembang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	9fd7de6c-317c-43e0-be51-e50d9088fcf3	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-08-13	Maintenance	13/08/2019	Maintenance
f2c98d0d-3a03-4972-8d24-69cd82177586	516	Atria Residence Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	125	3	2016-01-09	Jl. Boulevard Raya Gading Serpong No.Kav. 3, Gading, Kec. Serpong, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2021-02-19	Retraining	27/08/2024	On Line Training
537a0e3b-1893-417f-b998-edade4af164f	747	Visesa Ubud Resort Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	126	7	2018-05-01	Desa Visesa, Jl. Suweta, Bentuyung Sakti, Kecamatan Ubud, Kabupaten Gianyar, Bali 80571	Bali	Kabupaten Gianyar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-08-09	Maintenance	18/02/2026	On Line Training
02a40fc5-2eb3-435b-b579-da0bda50cbce	974	d'primahotel Jemursari (Surabaya)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	140	3	2023-11-30	 Jl. Raya Prapen No.22, Panjang Jiwo, Kec. Tenggilis Mejoyo, Surabaya, Jawa Timur 60299	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-30	Maintenance	30/08/2024	Maintenance
0e2d762b-5a39-4589-84c0-32889de17d3b	837	Dafam Enkadeli Thamrin Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	51	3	2021-04-01	Jl. Sunda No.8, RW.4, Gondangdia, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10350	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-08	Maintenance	08/01/2026	Maintenance
76039869-cdcb-4945-9c9d-a0ee61315202	672	Grand Sovia Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	93	3	2017-02-01	Jl. Kebon Kawung No.16, Pasir Kaliki, Kec. Cicendo, Kota Bandung, Jawa Barat 40171	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	787810e4-5b4b-4129-adb0-0a5c67546a56	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2017-03-31	Implementation	31/03/2017	Implementation
76378350-8edc-4feb-a630-865ea1904f9e	504	Fame Hotel Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	144	3	2020-02-27	Jl. Gading Serpong Boulevard No.30, Curug Sangereng, Kecamatan Kelapa Dua, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-13	Maintenance	13/10/2024	Maintenance
76ef4565-1b47-4a5a-82e8-3732c528e995	611	Grand Diara Hotel Cisarua	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	80	3	2015-12-24	Jl. Raya Puncak No.7, http://rw.km/ 77, Leuwimalang, Kec. Cisarua, Kabupaten Bogor, Jawa Barat 16750	Jawa Barat	Kabupaten Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	bd01bc16-4a9a-4c1f-bf7c-9292295270b4	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-05-17	Maintenance	17/05/2024	Maintenance
22add061-44d9-4e1c-988e-a28cd2d77fc2	109	Dafam Hotel Semarang (Owned)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	110	1	2010-11-18	Jl. Imam Bonjol No.188, Sekayu, Kec. Semarang Tengah, Kota Semarang, Jawa Tengah 50132	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-01-23	Maintenance	04/03/2023	Remote Installation
2939f9bf-4615-485d-998b-741eb34ce4a3	607	D'Primahotel Melawai Blok M	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	98	1	2023-02-18	Jl. Melawai IX No. 02 blok M/3 Persil Nomor 73, Kby, RT.3/RW.1, Melawai, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-06	Maintenance	06/09/2024	Maintenance
2fa69722-680e-4bd6-9eab-497a55fbbb53	858	Dafam Hotel Management - Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Sales Regional Jakarta,\nDafam Express Jaksa Jakarta, Ground Floor\nJalan Jaksa No. 27-29 Kebon Sirih\nJakarta Pusat 10340 | DKI Jakarta - Indonesia	\N	\N	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
3803832d-3181-49a0-8ecb-c2980837acb7	915	D'Primahotel Seminyak Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	76	\N	2022-09-23	Jl. Kayu Jati No.16, Seminyak, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-23	Maintenance	23/08/2024	Maintenance
f2d88ae8-2510-45da-8b72-e72e0688a6cf	923	d'primahotel Lagoi Bintan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	56	2	2023-01-21	Jl. Kota Kapur, Sebong Lagoi, Kec. Tlk. Sebong, Kabupaten Bintan, Kepulauan Riau 29152	Kepulauan Riau	Kabupaten Bintan	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-09	Maintenance	09/08/2024	Maintenance
f6e43b7d-45e1-4b6c-9af0-c8ef0b449c2d	162	Dewarna Hotel Arifin Malang (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	46	2	2012-03-01	Jl. Zainul Arifin No.55, Sukoharjo, Kec. Klojen, Kota Malang, Jawa Timur 65119	Jawa Timur	Kota Malang	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	44afd187-51f4-4801-860b-5ccdbe8f9a18	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-05-24	\N	24/05/2023	On Line Training
f77f5122-d280-432d-829b-4ec434915d74	657	Fame Hotel Sunset Road Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	90	3	2016-12-01	Jl. Sunset Road No.9, Legian, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-14	Retraining	14/09/2025	Retraining
fac8ff2d-d230-4719-9386-297ff9f23db4	767	HO-eL Royale Yogyakarta (SAKA)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Palagan Tentara Pelajar KM 8 No. 3, Sariharjo Ngaglik, Sleman\nDI - Yogyakarta	Daerah Istimewa Yogyakarta	Kabupaten Sleman	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ff784809-b9f5-48bf-b3dc-ab533399751e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2021-06-18	Retraining	18/06/2021	Retraining
7758a137-6fa8-4fb1-95f1-2fb72b701a80	1043	Hotel Lamora Sagan - Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	90	4	2025-07-18	Jl. Prof. Dr. Ir. Herman Johannes No.1, Terban, Kec. Gondokusuman, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55223	Daerah Istimewa Yogyakarta	Kota Yogyakarta	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-03-04	Retraining	04/03/2026	Retraining
7a3f7887-d7cc-46a7-936a-80bae395abb0	305	Afindo Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	18	0	2013-01-04	Jl. Wahid Hasyim St No.183 B, RT.14/RW.6, Kebon Kacang, Tanah Abang, Central Jakarta City, Jakarta 10240	DKI Jakarta	Kota Jakarta Pusat	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-16	Maintenance	06/01/2026	Others
6a50668c-a924-46b2-a5db-a3e563deb0cd	1001	Mewangi Boutique Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	41	3	2024-12-21	Jl. Karang Tineung Indah No.11, Cipedes, Kec. Sukajadi, Kota Bandung, Jawa Barat 40162	Jawa Barat	Kota Bandung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-17	Retraining	17/10/2025	Retraining
6a877b50-7856-474d-9006-7623cc046295	492	Ozone Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	95	0	2015-02-04	Jl. Pantai Indah Utara 3 No.40, Kapuk Muara, Kec. Penjaringan, Kota Jkt Utara, Daerah Khusus Ibukota Jakarta 14460	DKI Jakarta	Kota Jakarta Utara	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-13	Retraining	13/06/2025	Retraining
6c3b3b67-8285-4ada-86b3-9a21ebec64ce	1025	SMK 1 Singaraja	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	52	5	2025-02-16	Jl. Pramuka No.6, Banjar Bali, Kec. Buleleng, Kabupaten Buleleng, Bali 81113	Bali	Kabupaten Buleleng	b7c14d25-8f3f-4270-ad99-82d1d6edb675	d0cf407a-7618-4450-b798-046ca14576d4	c5443aff-0d00-4df3-aad8-0d130850ee76	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-02-16	Implementation	16/02/2025	Implementation
6e62f2da-5747-45e5-a677-eec07040dd0d	1017	Mahalaya The Legacy Hotel - Solo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	53	3	2025-01-01	Jl. Letjen S. Parman No.32, Setabelan, Kec. Banjarsari, Kota Surakarta, Jawa Tengah 57133	Jawa Tengah	Kota Surakarta	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-09	Implementation	09/02/2025	Implementation
6ea0510b-cd42-430c-be02-554ed42fb5e1	256	Pandanaran Hotel Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	171	6	2013-01-01	Jl. Pandanaran No.58, Pekunden, Kec. Semarang Tengah, Kota Semarang, Jawa Tengah 50134	Jawa Tengah	Kota Semarang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b85b056-1bd0-4cda-b8e6-b1bd9184d17b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-11-18	Maintenance	19/03/2021	Remote Installation
7311ac1b-a53f-4e68-b30b-483d8a79c800	134	Palace Hotel Cipanas	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	194	1	2011-09-01	Jl. Raya Cipanas KM.81,2 - Puncak, Cipanas, Kabupaten Cianjur -\nJawa Barat 43253	Jawa Barat	Kabupaten Cianjur	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	2613c0c2-bb62-4be3-a25d-a5389041eedf	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-07-28	Maintenance	28/07/2024	Maintenance
fe247e5a-a102-4fae-a065-76e186a78517	409	Inna Sindhu Beach Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	43	1	2023-05-25	Jl. Pantai Sindhu No.14, Sanur, Kec. Denpasar Sel., Kota Denpasar, Bali 80228	Bali	Kota Denpasar	26c188d8-2bea-46f8-81e0-4d48ef95f4a6	\N	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-06-05	Upgrade	05/06/2023	Upgrade
fe3f349d-ee5d-488f-9602-67e5ced242b0	181	Dafam Hotel Cilacap (Owned)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	1110	1	2011-08-01	Jl. Dr. Wahidin Sudiro Husodo No.5-15, Dafam Cilacap, Sidakaya, Kec. Cilacap Sel., Kabupaten Cilacap, Jawa Tengah 53211	Jawa Tengah	Kabupaten Cilacap	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-08	Maintenance	08/02/2026	Maintenance
fee94a51-1310-4063-aedb-dae30e501021	172	Angkasa Garden Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	79	2	2012-06-10	Jalan Setia Budi No.107, Pesisir, Kec. Lima Puluh, Kota Pekanbaru, Riau 28141	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-10-02	Retraining	02/10/2023	Retraining
feffa84d-77ec-47cc-b465-b4d4fcb7f1e0	63	Great Western Resort Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	126	0	2008-11-15	Jl. MH. Thamrin, RT.007/RW.001, North Panunggangan, Pinang, Tangerang City, Banten 15143	Banten	Kota Tangerang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-16	Maintenance	16/06/2025	Maintenance
ffdc785f-da43-4192-928f-5dee3f5d64de	541	Grand Kolopaking	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	72	3	2015-08-15	Jl. Ahmad Yani No.31, Dukuh, Kebumen, Kec. Kebumen, Kabupaten Kebumen, Jawa Tengah 54311	Jawa Tengah	Kabupaten Kebumen	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-08	Retraining	08/02/2026	Retraining
fff8ea99-2e50-44e8-a1c0-aebaca76e802	760	ILLIRA Lite Hotel Praya Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	93	3	2018-08-01	Jl. Raya No.88, Penujak, Praya Barat, Kab. Lombok Tengah\nNusa Tenggara Barat. 83572	Nusa Tenggara Barat	Kabupaten Lombok Tengah	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	eff96100-ce07-47c1-9365-e90088ee8562	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-12	Maintenance	12/10/2025	Maintenance
0120e857-68ed-4d03-8600-91905353fd3a	944	Khas Pekanbaru Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	134	5	2023-02-20	Jl. Jend. Sudirman No.455, Simpang Empat, Kec. Pekanbaru Kota, Kota Pekanbaru, Riau 28116	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-03-10	Implementation	10/03/2023	Implementation
744ac044-8a0b-405c-899d-1ca79dc0b822	1049	Metro Park View Hotel Kota Lama Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	89	8	2025-09-01	Jl. K.H. Agus Salim No.2-4, Kauman, Kec. Semarang Tengah, Kota Semarang, Jawa Tengah 50138	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	72a2fc8f-c7ba-4bed-90c1-96c5b6910530	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-30	Implementation	30/10/2025	Implementation
7483158b-d315-4987-ac13-7daa2382148f	618	Myko Hotel & Convention Center Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	218	9	2017-01-25	Kompl. Panakkukang Mall, Jl. Boulevard, Masale, Kec. Panakkukang, Kota Makassar, Sulawesi Selatan 90231	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-15	Maintenance	15/08/2025	Maintenance
7a9de08c-dbeb-4030-8617-c384d42229a2	911	Maxone Hotel-Kota Harapan Indah	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	86	6	2022-10-01	Jl. Harapan Indah 2 Blok SN6.8 No.18. Pusaka Rakyat Tarumajaya, Kab. Bekasi, Jawa Barat - 17214	Jawa Barat	Kabupaten Bekasi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-06-02	Maintenance	02/06/2026	Maintenance
7badb35b-a1ac-4430-bd38-531f42a2de78	961	Golden Hill Batu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	136	3	2023-11-01	Jl. Raya Oro-Oro Ombo No.1, Temas, Kec. Batu, Kota Batu, Jawa Timur 65315	Jawa Timur	Kota Batu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-12-14	Implementation	14/12/2023	Implementation
7c64690a-3c6e-45a9-ba0a-52d60f817529	1047	Jambuluwuk - BLOK M	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	15	\N	2025-07-18	Jl. Aditiyawarman No.59, RT.3/RW.2, Melawai, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	22/07/2025	Remote Installation
7c6f12df-658b-4408-b23e-c26a180ba527	131	Jambuluwuk Batu Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	68	0	2011-11-01	Jl. Trunojoyo No.99, Songgokerto, Kec. Batu, Kota Batu, Jawa Timur 65312	Jawa Timur	Kota Batu	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2012-09-13	Maintenance	25/04/2025	Remote Installation
7c9327d5-a1ca-4380-be55-7fce6cf82162	1048	Jambuluwuk Resort Bromo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	76	3	2025-09-06	Jl. Wonosari, Wonopolo, Tosari, Kec. Tosari, Pasuruan, Jawa Timur 67177	Jawa Timur	Kabupaten Pasuruan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-19	Implementation	24/12/2025	Remote Installation
7d2d66fd-2a1b-4cd5-9012-636aa86d05fc	622	Deivan Hotel Padang (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	34	1	2016-03-09	Jl. Diponegoro No.25, Belakang Tangsi, Kec. Padang Bar., Kota Padang, Sumatera Barat 25117	Sumatera Barat	Kota Padang	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-10-27	Maintenance	27/10/2023	Maintenance
072dc72e-f200-4996-8b6b-7e29738b1ee7	970	Midaz Senayan Golf - Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	0	6	2023-10-25	Senayan Avenue Pintu IX Jl. Asia Afrika, Gelora, Tanah Abang, Central Jakarta City, Jakarta 10270	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-13	Retraining	13/10/2025	Retraining
7c9bb617-0077-456d-a84d-62f783674768	633	KTM Resort Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	100	0	2016-12-08	Jalan Kolonel Soegiono, Tj. Pinggir, Kec. Sekupang, Kota Batam, Kepulauan Riau 29432	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-27	Maintenance	27/07/2025	Maintenance
11c79919-3cb0-4319-8821-22261004a004	507	De Rain Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	70	\N	2015-05-01	Jl. Lengkong Kecil No.76-80, Paledang, Kec. Lengkong, Kota Bandung, Jawa Barat 40261	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-06-14	Maintenance	14/06/2024	Maintenance
1696e40b-853e-4802-8ec9-9e764b18faa2	999	Dusun Bambu-Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	16	2024-08-05	Jl. Kolonel Masturi http://no.km/. 11, Kertawangi, Kec. Cisarua, Kabupaten Bandung Barat, Jawa Barat 40551	Jawa Barat	Kabupaten Bandung Barat	e1e794bc-7bbf-468c-81bb-7e4bb2968308	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-21	Retraining	21/09/2025	Retraining
41f387d4-f32d-4de0-ba99-7d09bc97eb83	692	Dafam Pacific Caesar Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	108	3	2017-08-09	Jl. Dr. Ir. H. Soekarno No.45-C, Kalijudan, Kec. Mulyorejo, Kota Surabaya, Jawa Timur 60114	Jawa Timur	Kota Surabaya	\N	\N	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-16	Retraining	16/11/2025	Retraining
5a4aa806-5cb8-41a8-8fa9-7daeca0d9e11	713	De Paviljoen Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	145	3	2017-10-01	Jl. Laks LLRE Martadinata St No.68, Citarum, Bandung Wetan, Bandung City, West Java 40115	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c9b3de12-b053-45fa-a5d3-305cbace4d03	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-05-09	Maintenance	09/05/2025	Maintenance
5d6cfec6-069c-4b94-be88-0ec44426f887	18	Danau Sunter Hotel (Sunlake)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	228	8	2001-01-01	Jl. Danau Permai Raya, Sunter Agung, Kec. Tj. Priok, Jkt Utara, Daerah Khusus Ibukota Jakarta 14350	DKI Jakarta	Kota Jakarta Utara	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	72a2fc8f-c7ba-4bed-90c1-96c5b6910530	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-28	Maintenance	28/11/2025	Maintenance
5e1296be-ff8e-41b6-a500-dbbeada8ad40	339	Dewarna Bojonegoro Hotel & Convention	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	205	3	2013-08-11	Jl. Veteran No.55, Jambean, Sukorejo, Kec. Bojonegoro, Kabupaten Bojonegoro, Jawa Timur 62115	Jawa Timur	Kabupaten Bojonegoro	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	44afd187-51f4-4801-860b-5ccdbe8f9a18	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-03-01	Retraining	01/03/2026	Retraining
5e5acf54-1e9f-48ae-bf5e-506ff85c945e	926	Bawah Investment PTE. LTD	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2023-01-01	Pulau Bawah, Desa Kiabu, Kecamatan Siantan\nSelatan Kebupatan Kepulauan Anambas, Provinsi Kepulauan Riau	Kepulauan Riau	Kabupaten Kepulauan Anambas	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	3185a01f-eeee-49eb-aac9-4d3fad065460	24e8eaf5-f179-4623-a5c1-44bbed901060	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
5f8738ff-fe56-4e0a-88b9-04cd661dabf7	219	DOX Ville Boutique Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	29	5	2013-05-31	No. 28, Jl. Kp. Sebelah No.Kel, Berok Nipah, Kec. Padang Bar., Kota Padang, Sumatera Barat	Sumatera Barat	Kota Padang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-03-23	Maintenance	23/03/2016	Maintenance
615e9526-5b31-4718-a166-32b1898d0ef0	508	Aradhana Villas Canggu Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	11	0	2015-02-25	Jl. Pemelisan Agung Tibubeneng, Kec. Kuta Utara, Kabupaten Badung, Bali	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-03-20	Upgrade	20/03/2016	Upgrade
7d837d56-7d6f-4559-b096-30ab65815412	485	Pandanaran Prawirotaman Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	117	3	2015-03-16	Jl. Prawirotaman St No.38, Brontokusuman, Mergangsan, Yogyakarta City, Special Region of Yogyakarta 55153	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b85b056-1bd0-4cda-b8e6-b1bd9184d17b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-15	Maintenance	15/10/2025	Maintenance
7eaa6d6b-a441-449e-83d5-6acb92a801c3	24	Kuta Paradiso Hotel Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	260	13	\N	Jl. Kartika Plaza, Tuban, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-03-13	Upgrade	13/03/2020	Upgrade
7ec60a7b-148a-497c-93a3-99290667aaf2	75	Park Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	172	9	2009-12-01	Jl. DI. Panjaitan No. Kav 5, RT.7/RW.11, Cawang, Jatinegara, Kota Jakarta Timur, Daerah Khusus Ibukota Jakarta 13340	DKI Jakarta	Kota Jakarta Timur	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3545ee81-be6c-44fd-b5ed-65d101d5a853	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-11	Retraining	11/12/2025	Retraining
84ad326a-1045-4d2f-98d2-bfeeb961bda1	785	Starlet Hotel Airport Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	1	120	0	2019-07-18	Jl. Atang Sanjaya No.45, RT.001/RW.006, Benda, Kec. Benda, Kota Tangerang, Banten 15125	Banten	Kota Tangerang	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2020-09-21	Maintenance	26/03/2021	Remote Installation
8531e232-51d0-410a-b349-a203b45ab4c5	667	Sotis Residence Pejompongan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	80	5	2017-04-01	Jl. Pejompongan Raya Jl. Penjernihan 1 No.10 B, RW.6, Bend. Hilir, Kec. Tanah Abang, Jakarta Pusat, DKI Jakarta 10210	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-05-11	Retraining	11/05/2025	Retraining
85e19b6f-67f7-4e7a-94f1-ba6820dd3790	1016	Khas Palu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	57	3	2024-12-01	Jl. Zebra 1, Kel. Birobuli Utara, Kec. Palu Selatan, Kota Palu, Sulawesi Tengah 94231	Sulawesi Tengah	Kota Palu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	7508fc4c-86ea-4d4e-bba1-31bb7982310a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-12-24	Implementation	24/12/2024	Implementation
64520e04-a114-4bc4-acb3-67c067cd41d8	430	Hotel Ciputra World Surabaya (CWS)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	212	5	2014-12-15	Jl. Mayjen Sungkono No.89, Gn. Sari, Kec. Dukuhpakis, Kota Surabaya, Jawa Timur 60224	Jawa Timur	Kota Surabaya	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-12-21	Maintenance	07/05/2025	On Line Training
014d7cb7-d88f-4c18-9575-586084d264d4	987	Manna Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	115	5	2024-05-01	Jl. Medan, No. 88, Siantar Utara, Kec. Siantar Martoba, Kota Pematang Siantar, Sumatera Utara 21138	Sumatera Utara	Kota Pematang Siantar	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-07-05	Implementation	05/07/2024	Implementation
0482c962-065c-4088-b771-32fce4117389	1002	Labersa Hotel & Convention Center - Samosir	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	197	8	2024-09-14	Simarmata, Simanindo, Kabupaten Samosir, Sumatera Utara 22395	Sumatera Utara	Kabupaten Samosir	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	290e5d8a-c56f-4e69-b3da-26805a82b2ac	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-13	Implementation	13/11/2024	Implementation
049fe264-7095-4162-b07f-4370a628bce6	995	Secana Beachtown Residence - Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	90	7	2024-10-01	Jl. Pemelisan Agung Jl. Pantai Berawa, Canggu, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	6109cf5a-d464-4597-82ae-44c0c2343552	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-20	Retraining	20/07/2025	Retraining
065439d0-29fc-4608-990f-9c5bf797b537	623	Pangeran Beach Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	181	6	2018-05-01	Jl. Ir. H. Juanda No.79, Flamboyan Baru, Kec. Padang Bar., Kota Padang, Sumatera Barat 25115	Sumatera Barat	Kota Padang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4d61701d-ad6c-4c88-9dd7-635396b0b475	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-08-26	Maintenance	26/08/2023	Maintenance
057b8096-cf14-46e3-aacb-7b4af362808a	715	Golden Tulip Holland Resort Batu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	260	7	2017-10-31	Komplek, Jl. Bukit Panderman Hill Jl. Cherry No.10, Temas, Kec. Batu, Jawa Timur 65314	Jawa Timur	Kecamatan Batu	8aea9f79-7c88-4d37-a2e7-04534b32b83e	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-09-25	Maintenance	10/12/2024	On Line Training
8c18c3ce-91d5-40c2-8ff3-4c50294e66be	709	Sunbreeze Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	57	2	2018-02-26	Perkantoran Permata Senayan Blok G5-9 Jl. Tentara Pelajar Raya, Kel, RT.1/RW.7, Grogol Utara, Kec. Kby. Lama, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12210	DKI Jakarta	Kota Jakarta Selatan	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-09-13	Implementation	13/09/2023	Implementation
8c556508-2fd2-4c45-a0d9-b3b56887ec11	743	Merumatta Senggigi Lombok Kila Senggigi Beach-Aero	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	167	8	2018-11-01	Jalan Pantai Senggigi, Senggigi, Kec. Batu Layar, Kabupaten Lombok Barat, Nusa Tenggara Bar. 83355	Nusa Tenggara Barat	Kabupaten Lombok Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2021-10-10	Retraining	10/10/2021	Retraining
8f5c73c4-3309-4ca1-84af-7eae3f9dbed9	818	Sol Beach House Benoa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	128	10	2019-11-01	Jl. Pratama, Benoa, Kec. Kuta Selatan, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-08	Retraining	08/02/2026	Retraining
4e39b117-9ae0-4f27-8006-dec5d2cd3083	54	Swiss-Belhotel Tarakan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	82	\N	2008-07-01	Jl. Mulawarman No.15, Karang Anyar Pantai, Tarakan Bar., Kota Tarakan, Kalimantan Utara 77111	Kalimantan Utara	Kota Tarakan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-06-09	Maintenance	09/06/2024	Maintenance
7e1142ae-9ae6-4971-abc1-4e32301e649e	1010	Hotel Wisata Banda Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	58	1	2024-09-08	Jl. Jend. Ahmad Yani No.19-21, Peunayong, Kec. Kuta Alam, Kota Banda Aceh, Aceh	Nanggroe Aceh Darussalam	Kota Banda Aceh	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-02	Implementation	02/11/2024	Implementation
7e7c331e-feb1-4d6b-ae56-ab5848175393	237	Grand Elite Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	145	5	2016-07-01	Komplek Riau Business Centre, Jl. Riau, Air Hitam, Kec. Payung Sekaki, Kota Pekanbaru, Riau 28292	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-08	Upgrade	08/02/2026	Special Request
808f96f0-cd89-4e7e-85cf-d6c945923cec	463	I Villa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	9	2	2014-09-13	Jl. Petitenget, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-02	Maintenance	02/03/2025	Maintenance
81cedd97-db87-427b-981f-533291e515fc	722	ILLIRA Hotel Banyuwangi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	138	3	2018-01-01	Jl. Yos Sudarso No.81-83, Lingkungan Sukowidi, Klatak, Kec. Kalipuro, Kabupaten Banyuwangi, Jawa Timur 68421	Jawa Timur	Kabupaten Banyuwangi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	eff96100-ce07-47c1-9365-e90088ee8562	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-27	Maintenance	27/10/2025	Maintenance
836d1367-6386-417a-b7fa-39352657ba1d	194	Dafam Hotel Pekanbaru (Owned)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	107	1	2012-09-05	Jl. Sultan Syarif Qasim Kav. 150, Kota Tinggi, Lima Puluh, Kota Tinggi, Kec. Pekanbaru Kota, Kota Pekanbaru, Riau 28155	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-11-29	Maintenance	29/11/2019	Maintenance
8737a082-0a0c-4dd1-88f5-5624878feace	97	Hotel Kuta Beach Club	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	150	9	2019-10-14	Jl. Bakung Sari No.81, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-09	Maintenance	09/03/2025	Maintenance
87b79075-d5c8-4a94-9fae-958c2facc3f8	533	GTV Hotel & Service Apartments Cikarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	220	6	2015-08-01	Jl. Raya Sukamahi No.1, Sukamahi, Kec. Cikarang Pusat, Bekasi, Jawa Barat 17530	Jawa Barat	Kota Bekasi	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-05-18	Maintenance	18/05/2025	Maintenance
15ed3916-b193-4081-a43f-d4cb52b30d05	750	Fortuna Grande Jember	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	121	2	2018-08-02	Jl. Karimata No.43, Gumuk Kerang, Sumbersari, Kec. Sumbersari, Kabupaten Jember, Jawa Timur 68121	Jawa Timur	Kabupaten Jember	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c06866bb-60c5-41a5-ae4d-ee95edd2887d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-14	Maintenance	14/09/2025	Maintenance
3322daa6-3bbf-4ea1-869c-851f1566b5d3	693	eL Royale Hotel & Resort Banyuwangi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	162	4	2017-05-23	Jl. Raya Jember KM 7 Pakistaji, Dusun Krajan, Dadapan, Kec. Kabat, Kabupaten Banyuwangi, Jawa Timur 68461	Jawa Timur	Kabupaten Banyuwangi	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ff784809-b9f5-48bf-b3dc-ab533399751e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-03-07	Retraining	07/03/2026	Retraining
3546d91b-d01c-406e-a72c-6572298d5c41	700	Famvida Hotel Lubuk Linggau	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	122	3	2017-08-01	Jl. HM Soeharto Km 12, No. 168, Lubuk Linggau Selatan I, Lubuk Linggau City, Sumatera Selatan 31626	Sumatera Selatan	Kota Lubuk Linggau	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-11-26	Retraining	26/11/2023	Retraining
35b0fdfb-d2b5-4487-a843-4f2b59650b7b	1035	Fortunasuites Malioboro - Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	117	6	2025-08-01	Jl. Sultan Agung, Purwokinanti, Pakualaman, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55166	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c06866bb-60c5-41a5-ae4d-ee95edd2887d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-20	Implementation	20/11/2025	Implementation
4b673bd7-0f22-4f1d-8608-f9d14a1ee72c	306	Fortuna Grande Malioboro Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	103	\N	2013-07-12	Jl. Malioboro Jl. Dagen No.60, Sosromenduran, Gedong Tengen, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55271	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c06866bb-60c5-41a5-ae4d-ee95edd2887d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-29	Retraining	29/09/2025	Retraining
90efc9f5-1fa7-49bf-a419-f3bf9c1dfea6	866	Prime Park Hotel & Convention Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	158	5	2021-10-18	Jl. Udayana Kelurahan No.16, Monjok Barat, Kec. Selaparang, Kota Mataram, Nusa Tenggara Barat 83122	Nusa Tenggara Barat	Kota Mataram	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3545ee81-be6c-44fd-b5ed-65d101d5a853	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-05-05	Maintenance	05/05/2024	Maintenance
9106773a-7992-4c01-818f-395c9f717dfb	677	Savvoya Hotel Villa Seminyak Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	133	5	2017-01-01	Jl. Mertanadi No.14, Seminyak, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-09-08	Retraining	08/09/2022	Retraining
916d5c42-bb16-4dba-a75d-28a68a987ec0	942	Khas Surabaya Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	142	5	2023-03-01	Jl. Benteng No.1, Nyamplungan, Kec. Pabean Cantikan, Kota SBY, Jawa Timur 60162	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-09-19	Retraining	20/01/2026	On Line Training
91f69762-1001-4a24-8f83-e609f362fa8d	1018	LAMORA Kota Lama Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	156	3	2024-12-01	Jl. Waspada No.58 - 60, Bongkaran, Kec. Pabean Cantikan, Surabaya, Jawa Timur 60161	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-31	Maintenance	31/01/2026	Maintenance
944bcc4f-9cd9-461d-a5b8-e5482ff71216	29	Kuta Sea View Boutique Resort & Spa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	90	0	\N	Jalan Pantai Kuta, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-27	Retraining	27/11/2025	Retraining
956bfb44-1c36-4e3a-aee7-643e37892464	103	Puri Asri Magelang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	168	1	2012-11-01	Jl. Cemp. No.9, Kemirirejo, Kec. Magelang Tengah, Kota Magelang, Jawa Tengah 56122	Jawa Tengah	Kota Magelang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-07-24	Maintenance	24/07/2022	Maintenance
9793023e-1ec9-4c2a-bf70-328c9a7bc3d1	1063	PT. Guna Bhakti Sukses Bersama	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Gedung Equity Tower Lantai 27 Unit H, Scbd Lot 9, Jl. Jend Sudirman Kav.52-53 Blok - No.- Kel.Senayan Kec.Kebayoran Baru Kota/Kab.Jakarta	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
9878af38-8479-4da8-b882-1fc5528f9d74	329	Savali Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	23	1	2013-01-01	Jl. Hayam Wuruk No 31-33, Belakang Tangsi, Padang Barat, Kota Padang, Sumatera Barat - Indonesia	Sumatera Barat	Kota Padang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-11-20	Maintenance	20/11/2019	Maintenance
98f591ef-1973-4667-ab51-290aa9ad60af	810	Suni Garden Lake Hotel & Resort Papua	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	100	8	2019-09-25	Jl. Sentani - Jayapura, Sentani Kota, Sentani, Jayapura, Papua 99359	Papua	Kabupaten Jayapura	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-05-15	Maintenance	14/01/2026	On Line Training
9a5a2d33-3496-4b6f-b06f-85a2c4710554	647	Samara Resort Hotel Batu Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	163	1	2016-12-17	Jl. Imam Bonjol No.17B, Sisir, Kec. Batu, Kota Batu, Jawa Timur 65315	Jawa Timur	Kota Batu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-03-08	Maintenance	08/03/2026	Maintenance
8ad10530-019b-4292-9c51-cd744fc86708	321	HW Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	78	3	2014-01-01	Jl. Hayam Wuruk No. 16, Kel, Belakang Tangsi, Kec. Padang Bar., Kota Padang, Sumatera Barat 25118	Sumatera Barat	Kota Padang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-03-22	Maintenance	22/03/2020	Maintenance
8b6afc43-a87e-4001-856f-9598f5b0bdd2	1020	d'primahotel PIK Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	70	1	2024-12-31	Metro Broadway The Plaza, Jl. Pantai Indah Utara 2 Pantai Indah Blok 9 No. AS - BC, Kapuk, Kec. Penjaringan, Jkt Utara, Daerah Khusus Ibukota Jakarta 14460	DKI Jakarta	Kota Jakarta Utara	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-14	Retraining	14/11/2025	Retraining
8b789bd9-2f57-4ff9-b725-3ad2df20df55	401	Grand Qin Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	187	5	2014-09-01	Q Mall Banjarbaru, Jl. A. Yani http://no.km/, RW.8, Komet, Kec. Banjarbaru Utara, Kota Banjar Baru, Kalimantan Selatan 70714	Kalimantan Selatan	Kota Banjar Baru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-16	Retraining	16/11/2025	Retraining
6644aabb-e117-4579-8199-dfeae0477fe9	44	eL Royale Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	521	15	2011-09-01	Jl. Merdeka No.2, Braga, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40111	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ff784809-b9f5-48bf-b3dc-ab533399751e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-30	Maintenance	30/11/2025	Maintenance
66471964-8368-4683-90b5-63422bdd9894	453	Grand Inna Tunjungan Surabaya (Simpang)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	124	2	2014-09-01	Jl. Gubernur Suryo No.1 - 3, Embong Kaliasin, Kec. Genteng, Kota SBY, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-05-18	Maintenance	19/01/2026	On Line Training
0fd14e71-fd9d-4d10-b2a5-87a76ade15fd	1055	Maha Resort Party -Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	46	5	2026-02-14	Jl. Pantai Batu Mejan No.1, Desa/Kelurahan Canggu, Kec. Kuta Utara,\nKab. Badung, Provinsi Bali	Bali	Kabupaten Badung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
12421e54-2730-4891-a42b-0f18eebab989	416	Noor Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	54	3	2015-02-15	Jl. Madura No.6, Citarum, Kec. Bandung Wetan, Kota Bandung, Jawa Barat 40115	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-23	Maintenance	23/08/2024	Maintenance
1310b284-f03a-405f-96f2-170188dff67d	708	Nevada Ketapang Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	88	6	2017-09-02	Jl. R. Suprapto No.116, Sampit, Kec. Delta Pawan, Kabupaten Ketapang, Kalimantan Barat 78811	Kalimantan Barat	Kabupaten Ketapang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	68350c01-b4d1-4246-a289-c79b0160300b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-07-23	Maintenance	08/10/2025	On Line Training
14135078-278e-4e0c-b913-c385b8173908	639	Swiss-BelExpress Kuta Bali (Galesong)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	116	1	2016-08-04	Jl. Legian Gg. Troppozone, Kuta, Kec. Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-01-28	Maintenance	28/01/2024	Maintenance
8c91204e-6922-4bae-ac36-e86857af50cd	345	Harmoni One Convention Hotel & Service Apart Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	292	4	2013-09-02	Jl. Raja M Tahir No.1, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29444	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-07	Maintenance	07/12/2025	Maintenance
8cffec72-49d9-48d2-8df2-90bf0aaf49a4	482	Fortuna Grande Seturan Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	100	3	2014-12-02	Jl. Seturan Raya, Kec. Depok, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55281	Daerah Istimewa Yogyakarta	Kabupaten Sleman	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c06866bb-60c5-41a5-ae4d-ee95edd2887d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-29	Maintenance	29/08/2025	Maintenance
8da601aa-362b-4d41-a4b3-e6fe080de0b4	737	Grand Suka Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	125	4	2018-03-01	Jl. Soekarno - Hatta No.KAV. 148, Delima, Kec. Tampan, Kota Pekanbaru, Riau 28294	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-20	Maintenance	20/03/2024	Maintenance
8daa6f3d-68a4-478c-b799-8abd40e29924	645	Citra Hotel Kepur Muara Enim (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	30	1	2016-06-20	Muara Enim, Kec. Muara Enim, Kabupaten Muara Enim, Sumatera Selatan 31311	Sumatera Selatan	Kabupaten Muara Enim	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-02-08	Maintenance	08/02/2019	Maintenance
911a57a1-e4f1-43d6-823b-0e58665c8df9	100	Jambuluwuk Convention Hall & Resort Ciawi-Puncak	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	88	0	2010-07-01	Jl. Veteran III Jl. Tapos Lbc No.63, Jambu Luwuk, Kec. Ciawi, Kabupaten Bogor, Jawa Barat 16720	Jawa Barat	Kabupaten Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	02/03/2025	Remote Installation
9abaa011-65a1-4458-8f2b-c056957f6f9a	985	Parkside Petro Gayo Hotel Takengon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	135	3	2024-03-01	Jl. Sengeda, Nunang Antara, Kec. Bebesen, Kabupaten Aceh Tengah, Aceh 24519	Nanggroe Aceh Darussalam	Kabupaten Aceh Tengah	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-04-26	Implementation	15/10/2025	On Line Training
9b17fa21-0185-4897-8e7a-a97bd1e6ee34	811	Starlet Hotel Serpong Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	109	\N	2019-09-01	Jl. Raya Kelapa Gading Utara No.37A, Pakualam, Kec. Serpong Utara, Kota Tangerang Selatan, Banten 15320	Banten	Kota Tangerang Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-11-15	Maintenance	15/11/2024	Maintenance
9e2f8256-8343-4c25-9a5d-3e52d9d9548f	979	SMKN 73 Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	50	1	\N	Jl. Angsana Raya No.7, RT.6/RW.12, Cengkareng Tim., Kecamatan Cengkareng, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11720	DKI Jakarta	Kota Jakarta Barat	\N	d0cf407a-7618-4450-b798-046ca14576d4	c5443aff-0d00-4df3-aad8-0d130850ee76	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-12-13	Implementation	13/12/2023	Implementation
a005fc31-c2ee-4878-b9fc-c32168c33d06	902	Surabaya Suites Hotel Powered by Archipelago	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	\N	2022-03-17	Jl. Plaza Boulevard Jl. Pemuda No.33 - 37, Embong Kaliasin, Kec. Genteng, Surabaya, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
a2657cce-e603-4902-a804-44cc52aa42fd	908	Kharista Villas & Retreat	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	15	3	2022-07-01	Jl. Pantai Batu Mejan No.21, Canggu, Kec. Kuta Utara, Kabupaten Badung, Bali 80351	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-07-12	Implementation	12/07/2022	Implementation
a274b26d-5220-4066-ab36-c732133f69f2	117	Permata Hotel Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	159	\N	2011-03-01	Jl. Raya Pajajaran No.35, Babakan, Kecamatan Bogor Tengah, Kota Bogor, Jawa Barat 16128	Jawa Barat	Kota Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-10	Maintenance	10/09/2024	Maintenance
a36df16f-8dd5-44e8-8831-30f84d062662	863	Sotis Hotel Kemang Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	74	4	2021-01-01	Jl. Kemang Raya No.4, RT.1/RW.7, Bangka, Kec. Mampang Prapatan, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12730	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-08	Retraining	08/08/2025	Retraining
1472e2e1-95bf-406b-aa12-cc89d73c1e30	694	KTM Resort 2 Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	50	5	2017-11-01	Jalan Kolonel Soegiono, Tj. Pinggir, Kec. Sekupang, Kota Batam, Kepulauan Riau 29432	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-07-01	Maintenance	01/07/2023	Maintenance
92318642-ed4a-43c1-8ab8-af26add386d1	449	Golden Palace Hotel Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	198	5	2014-11-24	Jl. Sriwijaya No.38, Sapta Marga, Kec. Cakranegara, Kota Mataram, Nusa Tenggara Bar. 83232	Nusa Tenggara Barat	Kota Mataram	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-15	Maintenance	15/02/2026	Maintenance
9245a7a9-85ef-45f7-aeda-0719b4a1373d	118	Hermes Palace Hotel Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	106	0	2011-02-01	Jl. Pemuda No.22, A U R, Kec. Medan Maimun, Kota Medan, Sumatera Utara 20151	Sumatera Utara	Kota Medan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5b9ab11f-d885-4a87-8006-4ac5637bbcdf	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-17	Maintenance	17/03/2024	Maintenance
a503d029-c757-4146-86c7-8abfad0ad076	976	Qin Hotel Banjar Baru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	99	1	2023-11-01	Q Mall, Jl. A. Yani http://no.km/. 36 Lantai 3, RW.8, Komet, Kec. Banjarbaru Utara, Kota Banjar Baru, Kalimantan Selatan 70714	Kalimantan Selatan	Kota Banjar Baru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-12-16	Implementation	04/10/2024	Remote Installation
a7178a08-ed79-47cd-8aa1-94e230c17f81	137	Sintesa Peninsula Hotel Palembang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	84	\N	2011-11-07	Jl. Residen Abdul Rozak No.168, 2 Ilir, Kec. Ilir Tim. II, Kota Palembang, Sumatera Selatan 30163	Sumatera Selatan	Kota Palembang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b6de363a-4dc6-4712-964c-f6156ba64afa	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
a7e2a8c5-10ea-4686-b941-69903c3a737a	719	Sahira Butik Hotel Paledang Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	60	4	2017-12-01	Jl. Paledang No.53, Paledang, blok gajah, Kota Bogor, Jawa Barat 16122	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	2aed36c5-71e5-48da-9e73-994e5f234213	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-26	Maintenance	26/12/2025	Maintenance
a8ec6902-aa58-4483-93af-8a733ec1f719	417	Samali Hotel & Resort (Head Office)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2014-04-17	Jl. Dharmawangsa X No.86, Kebayoran Baru, Jakarta Selatan, 12160	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	8bca21b7-bb1b-4581-9934-5c2aeb49783a	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2015-02-20	Retraining	20/02/2015	Retraining
ab75e6b5-6a9f-4a5e-982c-3e9189dfd0f3	1057	Saka Ombilin Heritage Hotel Sawahlunto	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	1	57	2	2025-12-04	Jl. A. Yani, Pasar Remaja, Lembah Segar, Kota Sawahlunto, Sumatera Barat, Indonesia, 27411/27422.	Sumatera Barat	Kota Sawahlunto	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-20	Implementation	20/12/2025	Implementation
ab9e53f3-323e-4028-8b4f-74189f22c69f	398	Melva Balemong Resort Ungaran Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	52	5	2014-07-01	Jl. Patimura No.1 B, Krajan, Ungaran, Kec. Ungaran Bar., Kabupaten Semarang, Jawa Tengah 50511	Jawa Tengah	Kabupaten Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-31	Retraining	31/08/2025	Retraining
ac6f8b76-35fa-4eb9-bd64-b37d0dafee95	506	Pasar Baru Square Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	99	2	2015-11-14	Jl. Otto Iskandar Dinata No.81-89, Braga, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40111	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-17	Maintenance	17/07/2025	Maintenance
aeace384-7329-4088-9cb3-72fd7c2a9dce	951	Swiss-Belhotel Airport Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	167	5	2024-01-23	Weton, Kebonrejo, Kec. Temon, Kabupaten Kulon Progo, Daerah Istimewa Yogyakarta 55654	Daerah Istimewa Yogyakarta	Kabupaten Kulon Progo	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-07	Maintenance	07/11/2025	Maintenance
af8de69f-103d-4df5-9526-48cae0aec207	726	Segara Village Hotel Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	125	5	2018-01-01	Jl. Segara Ayu, Sanur, Kec. Denpasar Sel., Kota Denpasar, Bali 80030	Bali	Kota Denpasar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2020-02-17	Maintenance	17/02/2020	Maintenance
b02e4747-8a8f-4d95-93b3-254c830758bf	640	Meotel Purwokerto Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	119	4	2016-08-17	Jl. DR. Soeparno No.1, Arcawinangun, Kec. Purwokerto Timur, Kab. Banyumas, Jawa Tengah 53123	Jawa Tengah	Kabupaten Banyumas	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-14	Maintenance	14/12/2025	Maintenance
b0b1f7d5-11cb-417b-b0a0-753b509231b5	751	Matos Hotel & Convention & Mall Mamuju	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	102	3	2018-07-16	Jl. Yos Sudarso No.37, Kabupaten Mamuju, Sulawesi Barat 91511	Sulawesi Barat	Kabupaten Mamuju	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-05	Maintenance	05/08/2024	Maintenance
b124ff4f-ab5e-4765-8773-dd745f85f673	877	Swiss-Belhotel Cendrawasih Biak Papua	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	\N	2021-10-01	Jl. Imam Bonjol No.46, Fandoi, Kec. Biak Kota, Kabupaten Biak Numfor, Papua 98111	Papua	Kabupaten Biak Numfor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-08-11	Retraining	20/11/2025	On Line Training
b26717b2-898b-47bb-a98e-ba28872ece21	865	Kyriad Muraya Hotel Training Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	126	3	2020-01-18	Jl. Teuku Moh. Daud Beureueh No.5, Laksana, Kec. Kuta Alam, Kota Banda Aceh, Aceh 24415	Nanggroe Aceh Darussalam	Kota Banda Aceh	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	0f8b16f7-fe11-4265-81f3-9436fd5aa50f	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-01-18	Implementation	18/01/2020	Implementation
b45bcd12-b72a-421f-8536-7583432e59ee	790	Swiss-Belhotel Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	150	6	2019-03-08	Jl. Salak No.38-40, Babakan, Kecamatan Bogor Tengah, Kota Bogor, Jawa Barat 16129	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-25	Maintenance	25/02/2026	Maintenance
b52d502b-2546-46fb-8936-86124ad6a3b6	738	Palm Park Hotel Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	101	5	2018-08-02	Jl. Kapas Krampung No.45, Tambakrejo, Kec. Simokerto, Surabaya, Jawa Timur 60142	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3545ee81-be6c-44fd-b5ed-65d101d5a853	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-11	Maintenance	11/01/2026	Maintenance
5c33c6bd-3dc0-48fd-8c9c-64cc49b686fb	734	Swiss-BelInn Modern Cikande	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	165	3	2018-07-16	Jl. Modern Industri I Jl. Raya Jkt No.68, Nambo Ilir, Kec. Kibin, Kabupaten Serang, Banten 42185	Banten	Kabupaten Serang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-24	Maintenance	17/12/2025	Remote Installation
957762a4-6214-4a67-991c-75e5d9af1708	311	D'Primahotel Marina (WTC Mangga 2) Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	54	\N	2023-04-06	Jl. Gunung Sahari Raya, Komplek Marinatama Blok A 26, RT.1/RW.13, Pademangan Bar., Jakarta Utara, Kota Jkt Utara, Daerah Khusus Ibukota Jakarta 14420	DKI Jakarta	Kota Jakarta Utara	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-31	Maintenance	31/07/2025	Maintenance
95f46ee8-470a-49a5-8b51-8018140e94d9	668	Ayani Hotel Banda Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	119	3	2018-03-25	Jl. Jend. A. Yani No. 20, Peunayong, Kuta Alam, Kota Banda Aceh, Aceh 23122	Nanggroe Aceh Darussalam	Kota Banda Aceh	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-02-19	Retraining	04/11/2025	On Line Training
969de925-d9d5-4e53-96b4-b256f92f2c2e	519	Ijen Suites Resort & Convention Hotel Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	202	3	2015-07-01	Jl. Ijen Nirwana Raya Blok A No.16, Bareng, Kec. Klojen, Kota Malang, Jawa Timur 65116	Jawa Timur	Kota Malang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ea77a5c4-ded3-48bb-8d8c-0b825e85d6ce	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-26	Maintenance	26/01/2025	Maintenance
97d4ccf5-0966-4d7b-8d1e-c857b8b66718	178	Jambuluwuk Malioboro Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	144	0	2011-12-01	Jl. Gajah Mada No.67, Purwokinanti, Pakualaman, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55166	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2012-07-25	Maintenance	09/04/2025	Remote Installation
14c101c3-fd99-4ad4-a162-7b886d405d45	119	Plan B Padang (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	39	1	2011-02-01	No.28, Jl. Hayam Wuruk No.Kel, Belakang Tangsi, Kec. Padang Bar., Kota Padang, Sumatera Barat	Sumatera Barat	Kota Padang	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-02-13	Maintenance	13/02/2022	Maintenance
18cad6f3-02da-4b28-aab4-9ef7881d72cf	330	Padjadjaran Suites Resort Convention Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	143	5	2014-02-18	Perumahan Bogor Nirwana Residence Jl. Bogor Inner Ringroad Lot XIX C-2 No 17, Mulyaharja, Kec. Bogor Sel., Kota Bogor, Jawa Barat 16132	Jawa Barat	Kota Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ea77a5c4-ded3-48bb-8d8c-0b825e85d6ce	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-20	Maintenance	20/06/2025	Maintenance
1718fbb6-85ea-479f-8589-053278211b94	371	Grand Hatika Hotel Belitung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	153	4	2014-01-01	Jl. Kemuning No.16, Parit, Kec. Tj. Pandan, Kabupaten Belitung, Kepulauan Bangka Belitung 33412	Kepulauan Bangka Belitung	Kabupaten Belitung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-22	Maintenance	22/09/2024	Maintenance
2cdaf49a-5adb-4f1e-ba55-39f1ac8b4c3e	13	Grand Eastern Restaurant Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Pasir Kaliki No.18, Kb. Jeruk, Kec. Andir, Kota Bandung, Jawa Barat 40181	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7fa6284-cd6b-4bad-996e-e5fd20beac3a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-12-24	Maintenance	24/12/2020	Maintenance
1970a67b-6394-4a32-997a-000cd12c34c7	343	Sotis Hotel Falatehan Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	75	3	2013-11-12	Jl. Falatehan I No.21-22, Melawai, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-19	Maintenance	19/12/2025	Maintenance
1a0e7f9e-6a7f-4e39-9600-cb5ac99a51fb	243	PT. Primahotel Manajemen Indonesia (Head Office)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2024-09-01	Jl. Semanan Raya No.27, RT.4/RW.10, Semanan, Kec. Kalideres, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11850	DKI Jakarta	Kota Jakarta Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-03	Maintenance	03/02/2026	Maintenance
1a8a80b0-9695-469f-a684-e346db56ae2d	536	Surabaya Suites Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	231	3	2016-01-01	Plaza Boulevard, Jalan Pemuda No.33-37, Embong Kaliasin, Genteng, Embong Kaliasin, Kec. Genteng, Kota SBY, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-24	Maintenance	24/12/2025	Maintenance
99a82cad-4a1b-4075-a8d1-1b431969bef6	450	Grand Zuri Kuta Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	133	0	2014-07-20	Jl. Raya Kuta No.81, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-26	Maintenance	26/06/2025	Maintenance
99f7c01d-c859-42b2-ab20-5cb2e3e47c0f	671	Bayu Amrta Exotic Hotel Restaurant Sukabumi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	26	0	2017-06-01	Jl. Karang Pamulang No.31, Citepus, Kec. Pelabuhanratu, Kabupaten Sukabumi, Jawa Barat 43364	Jawa Barat	Kabupaten Sukabumi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-04-27	Maintenance	27/04/2025	Maintenance
9ab8005b-ee55-4c65-9cd3-322d6e0706db	471	Ammeerra Hotels Bandung (Widyaloka)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	84	0	2014-10-20	Jl. Gegerkalong Hilir No. 47, Sukarasa, Sukasari, Sukarasa, Kec. Sukasari, Kota Bandung, Jawa Barat 40152	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-10-19	Maintenance	19/10/2019	Maintenance
213d690a-918e-4593-b83d-1d438aa6d8c9	182	Rama Garden Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	30	\N	2011-01-01	Jl. Padma, Legian, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-09-26	Retraining	26/09/2025	Retraining
b9b2f50f-520d-4ccb-85c4-56fa711b217b	991	Nusantara International Convention Exhibition	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	11	3	2025-08-31	Jl. M.H. Thamrin, Salembaran, Kec. Kosambi, Kabupaten Tangerang, Banten 15214	Banten	Kabupaten Tangerang	ee78c157-577a-429f-ade0-9a0e4d504506	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	b48c6277-d81d-4afe-a226-44f8b5b85019	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-06	Maintenance	06/02/2026	Maintenance
ba885baa-8c37-46ec-ab41-20950eafe026	885	Moritz Inn BSD Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	34	1	2021-11-01	Skyhouse BSD Tower Leonie L1, Jl. Damai Foresta No.15J, Sampora, Cisauk, Tangerang Regency, Banten 15345	Banten	Kabupaten Tangerang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1520e95b-70d9-4240-97ab-002d96d08614	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-05	Maintenance	05/06/2025	Maintenance
bbcb5366-c26c-4083-a195-f61e20c5587b	167	Savana Hotel & Convention Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	171	0	2012-07-01	Jl. Letjen Sutoyo No.30-34, Rampal Celaket, Kec. Klojen, Kota Malang, Jawa Timur 65141	Jawa Timur	Kota Malang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-22	Maintenance	22/02/2026	Maintenance
bbea96e0-ea1b-4480-8e33-19b874f81bf6	1065	Kiara Beach Front	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	94	4	\N	Jl. Pemelisan Agung, Tibubeneng, Kec. Kuta Utara, Kab. Badung, Bali - 80361\nIndonesia	Bali	Kabupaten Badung	\N	\N	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
bc488fd2-6aca-4b14-81d1-c15968d85a27	302	Sevn Legian	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	125	3	2014-11-19	Jalan Padma Utara, Legian, Badung, Legian, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-03-19	Maintenance	19/03/2024	Maintenance
bdc82248-1930-4056-a2f2-3dc6ac21e19b	931	Parkside Alhambra Hotel - Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	48	1	2023-01-16	Jl. Pante Pirak No.10, Simpang Lima, Kec. Kuta Alam, Kota Banda Aceh, Aceh 23127	Nanggroe Aceh Darussalam	Kota Banda Aceh	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	da2341a4-4289-4431-a330-343e969ef15b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-01-20	Implementation	20/01/2023	Implementation
1aaa440a-4659-4cc6-8f8e-99dc2128e211	473	Ratu Hotel Serang Banten	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	93	4	2014-11-01	Jl. K.H. Abdul Hadi No.66, Cipare, Kec. Serang, Kota Serang, Banten 42117	Banten	Kota Serang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-02	Retraining	02/11/2025	Retraining
1d82cc09-f1d7-41f2-acfc-43dd03eac5a7	1068	Marqen Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	166	7	\N	Jl. Kembangan Selatan No.02, Kembangan Sel., Kec. Kembangan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11610	DKI Jakarta	Kota Jakarta Barat	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
20b02a50-5dc0-4004-b29e-243d7b67da5f	935	Kayumas Seminyak Resort	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	61	5	2023-02-01	Jl. Pura Telaga Waja No.18A, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-19	Maintenance	21/04/2025	On Line Training
20cc56c1-ebd8-42bf-b331-d713bdba3f04	301	Sense Sunset Seminyak Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	196	2	2013-05-01	Jl. Sunset Road No.88S, Seminyak, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2021-10-13	Retraining	18/12/2023	On Line Training
22306558-5722-4a98-9606-4eb9a519499a	796	PT. Artotel Indonesia - HO	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Plaza Permata #07-23, Jl. M.H. Thamrin No. 57, Jakarta Pusat 10350	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	a7d0fd6c-57cc-49c3-ba41-1e19020148e1	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
277bbc88-56bf-44d8-90a3-c26419e899c6	887	Moritz Hotel Cihampelas Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	47	3	2022-03-22	Jl. Cihampelas No.179, Cipaganti, Kecamatan Coblong, Kota Bandung, Jawa Barat 40131	Jawa Barat	Kota Bandung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1520e95b-70d9-4240-97ab-002d96d08614	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-05	Maintenance	05/07/2025	Maintenance
becbe2d7-8105-4bfb-a955-3bf274c9d8ec	236	Pangeran Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	250	7	2018-09-01	Jl. Jend. Sudirman No.371-373, Cinta Raja, Kec. Sail, Kota Pekanbaru, Riau 28126	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4d61701d-ad6c-4c88-9dd7-635396b0b475	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-10-09	Maintenance	28/11/2025	On Line Training
c0b24c55-e543-48d7-b9ea-2a5a81965c5d	203	Labersa Pekanbaru & HO PT Labersa Hutahaean	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	257	\N	2012-03-11	Jl. Labersa, Tanah Merah, Kec. Siak Hulu, Kabupaten Kampar, Riau 28282	Riau	Kabupaten Kempar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	290e5d8a-c56f-4e69-b3da-26805a82b2ac	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-29	Maintenance	29/08/2025	Maintenance
9ba03dd5-3a18-4b64-9001-71f1460293e1	664	Batiqa Hotel Palembang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	160	4	2017-03-01	Jl. Kapten A. Rivai No. 219, 26 Ilir D. I, Kec. Ilir Barat I, Kota Palembang, Sumatera Selatan 30121	Sumatera Selatan	Kota Palembang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-11	Upgrade	26/07/2024	On Line Training
9c8f5e18-05b5-4d4f-b6fb-f39022d499aa	900	Balai Besar Pengembangan Latihan Kerja BBPLK Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	34	2	2022-03-25	Jl. Gatot Subroto http://no.km/. 7,8, Lalang, Kec. Medan Sunggal, Kota Medan, Sumatera Utara 20126	Sumatera Utara	Kota Medan	dcff7137-e65e-4721-bfa2-577ac260fbeb	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	c5443aff-0d00-4df3-aad8-0d130850ee76	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-03-26	Implementation	26/03/2022	Implementation
9ec43a8f-f396-4ec1-a8a9-42f23d0ea600	964	Guntur Hotel -Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	45	2	2024-02-01	Jl. Otto Iskandar Dinata No.20, Pasir Kaliki, Kec. Cicendo, Kota Bandung, Jawa Barat 40171	Jawa Barat	Kota Bandung	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-05	Maintenance	05/01/2025	Maintenance
a0b85c86-c08d-48b8-99e2-4e53f3e3e09c	1026	d'primahotel Perintis Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	2	2025-03-19	Jl. Perintis Kemerdekaan No.3 Km. 17, Pai, Kec. Biringkanaya, Kota Makassar, Sulawesi Selatan 90243	Sulawesi Selatan	Kota Makassar	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-25	Implementation	25/03/2025	Implementation
a0ea1432-6730-4601-b5bc-fba41e2c9a74	1046	Jambuluwuk - Pakubuwono	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	32	\N	2025-07-18	Jl. Ophir No.6, Gunung, Kec. Kby. Baru, Jakarta, Daerah Khusus Ibukota Jakarta 12120	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	22/07/2025	Remote Installation
a2970670-0ab8-4567-84e0-7e77e4e6679c	620	A-One Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	150	1	2016-11-04	Jl. Wahid Hasyim No.80, RT.15/RW.3, Kebon Sirih, Menteng, Central Jakarta City, Jakarta 10340	DKI Jakarta	Kota Jakarta Pusat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b2cb85d-fa37-486c-86d6-809621c484a9	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
a3981350-f753-4c28-8f42-d67fb15830e3	629	Imelda Park Hotel & Convention Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	7	2016-05-05	Jl. Intan No.12 Komplek L.I.K, Indarung, Pauh, Padang City, West Sumatra 25157	Sumatera Barat	Kota Padang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2017-07-10	Maintenance	16/11/2020	On Line Training
c225109a-21a0-47a9-8cdb-ba0e9285077c	714	Novena Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	126	\N	2017-12-22	Jl. Dr. Setiabudi No.4, Gudangkahuripan, Lembang, Kabupaten Bandung Barat, Jawa Barat 40391	Jawa Barat	Kabupaten Bandung Barat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7fa6284-cd6b-4bad-996e-e5fd20beac3a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-09	Maintenance	09/03/2025	Maintenance
c3821036-6b3f-479a-a984-f97551d7737b	31	Swiss-Belhotel Borneo Samarinda	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	183	\N	2000-06-01	Jl. Mulawarman No.6, Pelabuhan, Kec. Samarinda Kota, Kota Samarinda, Kalimantan Timur 75112	Kalimantan Timur	Kota Samarinda	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-06-23	Maintenance	11/11/2021	Remote Installation
c4141824-70c6-4661-85e1-a4cc62385602	946	Khas Tegal Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	98	5	2023-02-20	Jl. Gajah Mada No.5, Mintaragen, Kec. Tegal Tim., Kota Tegal, Jawa Tengah 52112	Jawa Tengah	Kota Tegal	74e6cb74-89c9-4d21-8410-2b77c74d6cd8	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-03-10	Implementation	10/03/2023	Implementation
c491d60c-d1b8-4cd0-8e0c-c4384b024938	869	Moritz Hotel RSAB Harapan Kita Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	96	3	2021-04-01	Jl. Letjen S. Parman No.Kav. 87, RT.1/RW.8, Kota Bambu Utara, Kec. Palmerah, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11420	DKI Jakarta	Kota Jakarta Barat	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1520e95b-70d9-4240-97ab-002d96d08614	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-14	Maintenance	14/06/2025	Maintenance
292c86e7-3c3f-49f6-8d6c-084816881de5	838	Savana Hotel & Training Malang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	164	1	2020-07-01	Jl. Letjen Sutoyo No.30-34, Rampal Celaket, Kec. Klojen, Kota Malang, Jawa Timur 65141	Jawa Timur	Kota Malang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2020-04-05	Implementation	05/04/2020	Implementation
2ab5ac34-569d-4e36-b60e-db13b5595bdb	681	PT. Surya Internusa Hotels (HO-SIH)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Ged. Tempo Scan Tower Lt.20, Jl. H.R. Rasuna Said Kav.3-4, Kuningan Timur, Setiabudi, Jakarta Selatan – DKI Jakarta	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-02	Maintenance	02/10/2024	Maintenance
2bf49bb3-b745-4851-b1b4-c6131bd0cf6a	23	Ramayana Suites & Resort Kuta Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	189	1	2017-03-01	Jl. Bakung Sari, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	0c02f3fc-beb4-4708-87c1-143077a8cfe7	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2017-04-09	Implementation	05/07/2023	Remote Installation
2d671629-fbc4-4c6e-b859-2440a33afaaa	809	Meruorah Komodo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	150	5	2019-10-01	Jl. Soekarno Hatta No.20, Labuan Bajo, Komodo, Kabupaten Manggarai Barat, Nusa Tenggara Tim. 86711	Nusa Tenggara Timur	Kabupaten Manggarai Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	7508fc4c-86ea-4d4e-bba1-31bb7982310a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-08	Retraining	08/11/2024	Retraining
329b0ff1-97c1-4498-89b5-7d1f88ac74dc	161	Kampung Sumber Alam Resort Garut	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	79	1	2012-06-01	Jl. Raya Cipanas 122 Pananjung Tarogong Kaler, Pananjung, Cipanas, Kabupaten Garut, Jawa Barat 44151	Jawa Barat	Kabupaten Garut	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-24	Maintenance	24/11/2024	Maintenance
478dbd2b-f199-473b-b3cb-47ea814e9273	990	Katamaran Hotel & Resort-Komodo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	150	7	2024-10-03	Pantai Waecicu, Labuan Bajo, Kec. Komodo, Kabupaten Manggarai Barat, Nusa Tenggara Tim. 86763	Nusa Tenggara Timur	Kupaten Manggarai Barat	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-25	Implementation	29/01/2026	On Line Training
0b6252c4-d39d-405b-8c18-636ba621964c	315	Grand Whiz Hotel Nusa Dua Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	130	0	2013-07-07	Komplek Wisata Nusa Dua, Jl. Kw. Nusa Dua Resort, Benoa, Kec. Kuta Selatan, Kabupaten Badung, Bali 80363	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	726728c9-9b7e-4f73-b253-ed4da52676b9	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-16	Maintenance	16/03/2025	Maintenance
c63d6507-b7eb-472d-839f-f4b09f7c9083	687	Pangeran City Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	97	3	2017-03-01	Jl. Dobi No.3-5, Kp. Pd., Kec. Padang Bar., Kota Padang, Sumatera Barat 25115	Sumatera Barat	Kota Padang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4d61701d-ad6c-4c88-9dd7-635396b0b475	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-09-09	Maintenance	09/09/2023	Maintenance
c63ee352-a2f6-4e8b-aaa8-75fb4a773819	788	Kupu Kupu Barong Villas & Spa Ubud Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	99	4	2019-02-04	Jl. Raya Kedewatan, Kedewatan, Kecamatan Ubud, Kabupaten Gianyar, Bali 80571	Bali	Kabupaten Gianyar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-26	Retraining	26/02/2025	Retraining
c820d754-943c-43d7-ba0c-56629ec80f36	173	Swiss-Belhotel Danum Palangkaraya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	150	0	2012-03-16	Jl. Tjilik Riwut KM.5 No.9, Bukit Tunggal, Kec. Jekan Raya, Kota Palangka Raya, Kalimantan Tengah 73112	Kalimantan Tengah	Kota Palangka Raya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-14	Maintenance	13/01/2026	Remote Installation
a7db7910-ff4a-468d-b039-c9cc21b46eb2	459	Ammi Hotel Cepu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	62	0	2026-01-01	Jl. Giyanti No.14, Sambongan, Karangboyo, Kec. Cepu, Kabupaten Blora, Jawa Tengah 58315	Jawa Tengah	Kabupaten Blora	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	94c9f0bb-3e2a-42dd-a4fe-b779dbf31155	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-11	Upgrade	11/01/2026	Upgrade
a8393ddc-04f3-4b23-ae70-755828a70f68	992	Golo Mori Covention Center	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	0	2	2024-06-21	Kawasan MICE, Golo Mori, Labuan Bajo, Kabupaten Manggarai Barat, Nusa Tenggara Tim. 86763	Nusa Tenggara Timur	Kabupaten Manggarai Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	b48c6277-d81d-4afe-a226-44f8b5b85019	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-16	\N	16/01/2025	On Line Training
a89a7ad5-75be-4b59-9c5f-8e9a734d92e5	819	Grand Cemara Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	104	3	2020-01-01	Jl. Cemara No.1, RT.5/RW.3, Gondangdia, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10350	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b2cb85d-fa37-486c-86d6-809621c484a9	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-10	Maintenance	10/07/2025	Maintenance
aa3e7fa3-9208-4641-8eea-2afb209d00e8	410	Inna Heritage Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	71	1	2014-04-02	Jl. Veteran No.3, Dauh Puri Kaja, Kec. Denpasar Utara, Kota Denpasar, Bali 80111	Bali	Kota Denpasar	26c188d8-2bea-46f8-81e0-4d48ef95f4a6	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-06-05	Upgrade	05/06/2023	Upgrade
ad0a8f1d-c139-406c-a841-aca71519cfd2	439	Citra Hotel Talang Jawa Muara Enim (Xpress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	44	\N	2014-01-09	Jl.Jend Sudirman No. 59, Kec. Muara Enim, Ps. III Muara Enim, Kec. Muara Enim, Kabupaten Muara Enim, Sumatera Selatan 31313	Sumatera Selatan	Kabupaten Muara Enim	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-02-10	Maintenance	10/02/2019	Maintenance
c9a5deb7-72be-4dd0-877e-1561f2c0689d	66	Rama Beach Resort & Villas Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	\N	\N	Jl. Jenggala Tuban, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-10-23	Maintenance	06/03/2025	On Line Training
15368178-a1f9-4171-974f-5cd4714b6d4b	832	Grand Swiss-Belhotel Darmo Surbaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	228	5	2021-01-11	Jl. Bintoro No.21-25, DR. Soetomo, Kec. Tegalsari, Kota Surabaya, Jawa Timur 60264	Jawa Timur	Kota Surabaya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-21	Maintenance	21/12/2025	Maintenance
1e81d946-7341-4d15-9df6-09645a2ef820	907	Grand Zuri Hotel Lubuk Linggau	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	116	5	2022-10-15	Jl. Yos Sudarso No.1, Batu Urip Taba, Kec. Lubuk Linggau Tim. I, Kota Lubuklinggau, Sumatera Selatan 31624	Sumatera Selatan	Kota Lubuk Linggau	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-16	Maintenance	16/09/2025	Maintenance
2a61cf4d-dae3-4989-88d2-2e2826811f1e	171	Grand Zuri BSD City Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	132	2	2012-06-16	Jl. Pahlawan Seribu Kavling Ocean Walk Blok CBD, Lot. 6, BSD City, Lengkong Gudang, Kec. Serpong, Kota Tangerang Selatan, Banten 15322	Banten	Kota Tangerang Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-11	Maintenance	11/01/2026	Maintenance
3138e8bd-3c69-4ed0-ae51-5efbab512e17	376	Grand Maleo Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	92	3	2014-02-01	Jl. Pelita Raya VIII No.1, Bua Kana, Kec. Rappocini, Kota Makassar, Sulawesi Selatan 90222	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-07	Maintenance	07/11/2025	Maintenance
4046d907-a261-4536-a7b7-cbb5fe1d5e53	826	Grand Zuri Ketapang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	102	3	2020-03-03	Jl. DI Panjaitan, Sampit, Delta Pawan, Kabupaten Ketapang, Kalimantan Barat 78811	Kalimantan Barat	Kabupaten Ketapang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-27	Maintenance	27/06/2025	Maintenance
4f93404f-b164-4796-a53c-8569479a86a9	168	Grand Zuri Hotel Dumai	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	111	\N	2010-03-01	Jl. Jend. Sudirman No.88, Bintan, Dumai Kota, Kota Dumai, Riau 28812	Riau	Kota Dumai	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-07	Maintenance	07/07/2025	Maintenance
66d79694-6495-43f2-8174-2253ce7d5a45	189	Grand Central Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	161	2	2012-08-01	Jl. Jenderal Sudirman No.1, Tengkerang Utara, Kec. Bukit Raya, Kota Pekanbaru, Riau 28287	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-06	Maintenance	06/09/2024	Maintenance
67fd4d2b-309d-4ec9-bba5-b0b3a08cc3e4	200	El Cavana Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	106	3	2012-11-08	Jl. Pasir Kaliki No.16-18, Kb. Jeruk, Kec. Andir, Kota Bandung, Jawa Barat 40181	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7fa6284-cd6b-4bad-996e-e5fd20beac3a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-12	Maintenance	12/11/2025	Maintenance
c9c28f66-a4a0-48c5-8053-5a6ea3273f3e	1007	Noema Resort Pererenan Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	157	7	2025-04-11	Jl. Kuwum, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-05-16	Implementation	16/05/2025	Implementation
ca5beec7-ddd1-45d7-b38f-8ff8b4b3e51e	712	Kyriad Muraya Hotel Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	126	3	2017-11-09	Jl. Teuku Moh. Daud Beureueh No.5, Laksana, Kec. Kuta Alam, Kota Banda Aceh, Aceh 24415	Nanggroe Aceh Darussalam	Kota Banda Aceh	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	0f8b16f7-fe11-4265-81f3-9436fd5aa50f	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-05-19	Maintenance	28/03/2023	Remote Installation
cab40c24-d825-4102-8170-606cfc04052d	496	Merusaka Nusa Dua	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	460	8	2014-12-25	Kawasan Wisata Nusa Dua Lot S-3, Benoa, Kuta Selatan, Benoa, Kec. Kuta Sel., Kabupaten Badung, Bali 80363	Bali	Kabupaten Badung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-07-11	Maintenance	11/07/2024	Maintenance
cb4b1416-60b1-462b-a078-d2ec599847c2	871	Starlet Hotel BSD City Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	99	0	2021-06-03	Jl. BSD Boulevard Utara, Lengkong Kulon, Kec. Pagedangan, Kabupaten Tangerang, Banten 15331	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-22	Retraining	22/08/2025	Retraining
cc24de5a-4a2a-4d4d-a335-f05fa9f87532	949	Mardliyyah Islamic Center UGM - Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	136	2	2023-08-18	Jl. Kesehatan Sendowo, Sendowo, Sinduadi, Kec. Mlati, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55281	Daerah Istimewa Yogyakarta	Kabupaten Sleman	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-12	Upgrade	11/09/2024	On Line Training
cc6b3e74-6d8b-4989-9f4f-6be26fa688ad	307	Primebiz Hotel Kuta Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	140	1	2013-05-01	Jl. Raya Kuta No.66, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-02-26	Maintenance	26/02/2023	Maintenance
ccd1bc25-6a3a-4b52-9fd5-a4fe53f00ba8	17	Kedaton Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	116	0	\N	Jl. Suniaraja No.14, Braga, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40111	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7fa6284-cd6b-4bad-996e-e5fd20beac3a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-01	Maintenance	01/02/2026	Maintenance
ceeb113d-aa37-4d1c-9b33-96dea983f770	216	Seminyak Icon Villa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	18	1	2012-08-05	Dewi Madri, Jl. Bali Deli, Seminyak, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5552e1dc-feb4-4b89-b870-4d58f90bb88e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-03	Maintenance	03/12/2025	Maintenance
2e514663-62c3-4e5f-b231-433eb130637c	792	Saka Hotel Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	108	3	2019-04-01	Jl. Gagak Hitam No.14, Sei Sikambing B, Kec. Medan Sunggal, Kota Medan, Sumatera Utara 20122	Sumatera Utara	Kota Medan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	51d71edf-55ca-4773-9e80-02519c048c5a	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-04-01	Implementation	10/05/2024	On Line Training
3019d098-fec0-400e-ad4e-c0913c917584	316	Sanur Resort Watu Jimbar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	314	5	2014-04-08	Jl. Danau Tamblingan No.99A, Sanur, Kec. Denpasar Sel., Kota Denpasar, Bali 80228	Bali	Kota Denpasar	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-19	Retraining	19/12/2025	Retraining
3104cc70-667f-4906-80bd-a529177bb68a	261	Swiss-Belhotel Harbour Bay Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	180	2	2013-01-19	Jl. Duyung Sei Jodoh, Sungai Jodoh, Kec. Batu Ampar, Kota Batam, Kepulauan Riau 29432	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-10-17	Maintenance	31/08/2022	On Line Training
3209405f-223c-4f3c-85aa-6396b601e541	609	Kila Infinity8 Jimbaran Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	183	0	2016-06-01	Jalan By Pass Ngurah Rai No.88A Jimbaran, Nusa Dua, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-16	Retraining	16/12/2025	Retraining
345379c4-65ff-49b5-9f2b-e0165cc5a238	736	Prime Park Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	151	5	2018-02-01	Jl. Jenderal Sudirman No.3, RW.6, Simpang Tiga, Kec. Bukit Raya, Kota Pekanbaru, Riau 28671	Riau	Kota Pekanbaru	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3545ee81-be6c-44fd-b5ed-65d101d5a853	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-02	Retraining	02/11/2025	Retraining
348b3841-6a57-4759-94da-e257dc3e9968	947	Khas Makassar Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	140	5	2023-03-01	Jl. A. Mappanyukki No.49, Kunjung Mae, Kec. Mariso, Kota Makassar, Sulawesi Selatan 90125	Sulawesi Selatan	Kota Makassar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-05-06	Maintenance	06/05/2023	Maintenance
d1d04e92-35b2-4716-8343-4079679660ce	1064	Kiara Ocean Place	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	62	1	\N	Jl. Pemelisan Agung, Tibubeneng, Kec. Kuta Utara, Kab. Badung, Bali - 80361\nIndonesia	Bali	Kabupaten Badung	e1e794bc-7bbf-468c-81bb-7e4bb2968308	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	Implementation	\N	Implementation
d4fe3275-85f3-44fa-b64e-e4e19c17c98f	822	Labersa Toba Balige Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	152	5	2020-02-28	Saribu Raja Janji Maria, Balige, Toba Samosir Regency, North Sumatra	Sumatera Utara	Kabupaten Toba	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	290e5d8a-c56f-4e69-b3da-26805a82b2ac	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-11	Maintenance	14/01/2026	On Line Training
ad103f35-85ba-40e3-81eb-888cb025d620	755	eL Royale Hotel Malioboro Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	166	3	2019-03-01	Jl. Dagen No.6, Sosromenduran, Gedong Tengen, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55271	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ff784809-b9f5-48bf-b3dc-ab533399751e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-04-06	Retraining	18/07/2025	Remote Installation
af6e21d4-8351-487b-8e11-c054d8730a4e	710	Ana Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	85	3	2017-11-28	Jl. Kebon Kacang IX/79. RT.9/RW.4, Kb. Kacang, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10240	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-01	Retraining	01/02/2026	Retraining
b0719d11-ad20-4387-b9ca-79d5b307aaae	538	Grand Palace Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	72	\N	2015-09-01	Jl. Tentara Pelajar No.50, Butung, Kec. Wajo, Kota Makassar, Sulawesi Selatan 90165	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-11-09	Maintenance	09/11/2019	Maintenance
b0b28713-fb7f-444a-9204-3d87d3801473	628	Batiqa Hotel Lampung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	109	3	2016-06-02	Jalan Jenderal Sudirman no.140 Pahoman Tanjung Karang, Pahoman, Engal, Kota Bandar Lampung, Lampung 35213	Lampung	Kota Bandar Lampung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-06-12	Upgrade	12/06/2024	Upgrade
b2c0b217-73f9-4439-b72c-fc2c0354382d	346	Atria Hotel Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	156	3	2016-01-09	Jl. Gading Serpong Boulevard No.2 Kavling 2, Pakulonan Barat, Kecamatan Kelapa Dua, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-26	Maintenance	26/03/2025	Maintenance
d735ff03-9d70-42ea-9f8f-b98fd6c88f59	921	Sotis Hospitality Management	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Panglima Polim No.28, RT.9/RW.7, Pulo, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-11-09	Others	09/11/2023	Others
da171e89-60c0-4fc8-873b-285f6677cffa	93	Kiss Design Villas Seminyak Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	8	1	2010-12-31	JL. Cendrawasih No 99X, Petitenget, Kerobokan, Kerobokan Kelod, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2010-09-14	Implementation	14/09/2010	Implementation
db25cc48-bdea-4d9d-adb2-5aa7b4d4b3fa	943	Khas Gresik Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	5	2023-03-01	Jl. Panglima Sudirman No.1, Sumberrejo, Sidokumpul, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61111	Jawa Timur	Kabupaten Gresik	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-09-24	Retraining	24/09/2023	Retraining
db377220-2257-42b7-8335-b74b8c17b9d2	643	Mola Mola Gili Air Resort Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	52	5	2016-08-01	Gili Air, Gili Indah, Pemenang, Kota Mataram, Nusa Tenggara Bar. 08020	Nusa Tenggara Barat	Kota Mataram	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-02-11	Maintenance	13/07/2020	On Line Training
dcb12d9d-d728-4a17-a6ba-c16edd6c3782	994	Kuara Resort - Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	16	3	2024-09-01	Jalan Raya Awang Dusan, Jl. Bumbang, Kabupaten, Kec. Pujut, Kabupaten Lombok Tengah, Nusa Tenggara Bar. 83573	Nusa Tenggara Barat	Kabupaten Lombok Tengah	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	6109cf5a-d464-4597-82ae-44c0c2343552	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-04	Retraining	04/06/2025	Retraining
013393f3-3d69-40cc-98a5-f5d67bcd4d4b	298	Griya Sintesa Hotel Muara Enim Palembang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	64	2	2013-10-01	Jl. Karet, Air Lintang, Kec. Muara Enim, Kabupaten Muara Enim, Sumatera Selatan 31315	Sumatera Selatan	Kabupaten Muara Enim	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b6de363a-4dc6-4712-964c-f6156ba64afa	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2013-11-27	Implementation	27/11/2013	Implementation
031dda47-018d-42a1-8a50-cb215e0536c9	265	Grande Padjadjaran Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	119	7	2013-07-01	Jl. Raya Pajajaran No.17, RT.02/RW.03, Bantarjati, Kec. Bogor Utara, Kota Bogor, Jawa Barat 16153	Jawa Barat	Kota Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	ea77a5c4-ded3-48bb-8d8c-0b825e85d6ce	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-14	Retraining	14/11/2025	Retraining
10563990-a8e6-43c0-bd1b-426b7607fd16	135	Grand Zuri Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	\N	2009-11-01	Jl. Teuku Umar No.7, Rintis, Kec. Lima Puluh, Kota Pekanbaru, Riau 28141	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-28	Maintenance	28/07/2025	Maintenance
16d8457c-9a6a-40af-a360-3c336d74dadd	815	Luxury Inn Arion Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	82	3	2020-01-20	Jl. Pemuda No.Kav. 17, Rawamangun, Kec. Pulo Gadung, Kota Jakarta Timur, Daerah Khusus Ibu kota Jakarta 13220	DKI Jakarta	Kota Jakarta Timur	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3271c59d-2f4d-4aae-b0ec-01ab476a54b1	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-12	Retraining	12/12/2025	Retraining
34d5afc1-dec8-4576-9988-e221038098bf	540	Sapphire Sky Hotel - BSD City	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	102	4	2015-10-28	BSD City, Jl. BSD Boulevard Utara SC II No.2, Lengkong Kulon, Kec. Pagedangan, Kabupaten Tangerang, Banten 15331	Banten	Kabupaten Tangerang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-03-01	Retraining	01/03/2026	Retraining
356c03e3-8445-431e-b258-76fd581d1892	798	Kyriad Hotel Sadurengas	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	141	3	2019-07-04	Jl. Kusuma Bangsa KM. 5, Tana, Tepian Batang, Kec. Tanah Grogot, Kabupaten Paser, Kalimantan Timur 76251	Kalimantan Timur	Kabupaten Paser	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	0f8b16f7-fe11-4265-81f3-9436fd5aa50f	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-09-16	Maintenance	16/09/2022	Maintenance
38cdb4e0-1cae-4c77-9841-918a8c7a794c	1009	Suites 5 Balangan Hotel - Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	37	3	2024-12-20	Jl. Pantai Balangan No.99, Jimbaran, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-14	Maintenance	14/12/2025	Maintenance
3e181999-9ff2-42c8-8af5-0d86072b96a7	165	Paramita Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	37	\N	2012-03-17	Jl. Teuku Umar No.20, Kota Tinggi, Kec. Pekanbaru Kota, Kota Pekanbaru, Riau 28155	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	2613c0c2-bb62-4be3-a25d-a5389041eedf	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-11-27	Maintenance	27/11/2019	Maintenance
de398d36-8137-4945-a2e8-dabbd86a7c12	702	Premier Place Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	129	5	2017-09-01	Jl. Raya Bandara Juanda No.73, Semawalang, Semambung, Kec. Gedangan, Kabupaten Sidoarjo, Jawa Timur 61254	Jawa Timur	Kabupaten Sidoarjo	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-21	Maintenance	21/12/2025	Maintenance
dfdfa3cf-9323-4754-9ae2-b25c0ad2637e	597	Swiss-Belhotel Jambi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	136	4	2016-03-29	Jl. Sumantri Brojonegoro No.1, Solok Sipin, Kec. Telanaipura, Kota Jambi, Jambi 36124	Jambi	Kota Jambi	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-16	Maintenance	15/01/2026	Remote Installation
dff33da0-2c64-4c66-877e-51e6d6639f66	840	JHL D'Varee Diva (Episode) Kuta Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	191	3	2020-09-01	Jl. By Pass Ngurah Rai No.99, Kuta, Kabupaten Badung, Bali 80362	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-30	Retraining	30/09/2025	Retraining
e1072edb-7078-44dd-b02e-c27f0d37bee3	45	Swiss-Belhotel Indonesia - Regional Office	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	The Blugreen Boutique Office Tower C-D, 2nd Floor\nJl. Lingkar Luar Barat Kav. 88, Puri Kembangan\nKembangan Utara - Jakarta 11610, Indonesia	DKI Jakarta	Kota Jakarta Barat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	8bca21b7-bb1b-4581-9934-5c2aeb49783a	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-01-10	Maintenance	29/01/2026	Others
e31c2adc-f199-477e-8923-90cdf4b085cb	378	Karibia Boutique Hotel Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	167	7	2015-05-01	Jl. Timor Blok J No.I-IV, Gg. Buntu, Kec. Medan Tim., Kota Medan, Sumatera Utara 20231	Sumatera Utara	Kota Medan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-16	Upgrade	04/12/2025	On Line Training
e46d355a-4c61-4828-92d0-5babc7d94840	39	Ponderosa HO - Pondok Pinang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2012-09-12	Komplek Ruko Pondok Pinang Centre, Blok C No.46-48, Jl. Ciputat Raya RT.01/RW.05, Jakarta Selatan 12310	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	8bca21b7-bb1b-4581-9934-5c2aeb49783a	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-01-31	Maintenance	31/01/2024	Maintenance
1359c974-78e1-4f86-9176-11e7eda3fdc8	152	Swiss-BelInn Baloi Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	128	0	2008-10-01	Komp. Villa Idaman, Jl. Pembangunan, Batu Selicin, Kec. Lubuk Baja, Kota Batam, Kepulauan Riau 29432	Kepulauan Riau	Kota Batam	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-01-29	Upgrade	17/03/2025	Remote Installation
1f155836-c001-404d-9dd3-4f0edc2b39b0	478	Swiss-Belinn Karawang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	166	4	2015-09-01	Jl. A. Yani No.29, Tanjungpura, Kec. Karawang Bar., Kabupaten Karawang, Jawa Barat 41315	Jawa Barat	Kabupaten Karawang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-09	Retraining	09/01/2026	Retraining
414ae933-a94a-4340-bbf2-eac8266ac86e	71	Swiss-Belhotel Ambon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	112	\N	2010-05-01	Jl. Benteng Kapaha No.88, Uritetu, Kec. Sirimau, Kota Ambon, Maluku 97128	Maluku	Kota Ambon	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-11-17	Maintenance	17/11/2024	Maintenance
415f6523-cad0-461c-b966-48b0f2a39625	665	Rama Residence Padma Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	38	3	2016-12-28	Jl. Padma No.1, Legian, Kuta, Kabupaten Badung, Bali 80361, Indonesia.	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-11-13	Retraining	13/11/2022	Retraining
420a6e8d-56e1-4038-9f24-963cb0f3816c	229	Nagoya Mansion Hotel & Residence Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	126	5	2013-05-20	Jl. Raden Patah Kampung Utama No.1, Lubuk Baja Kota, Kec. Lubuk Baja, Kota Batam, Kepulauan Riau 29444	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2018-01-28	Maintenance	02/03/2026	On Line Training
43190cc0-604f-4926-9939-d9cbfb5be1a2	955	Kyriad Airport Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	165	4	2023-06-08	Jl. Marsekal Suryadarma No.1, RT.001/RW.006, Karang Sari, Kec. Neglasari, Kota Tangerang, Banten 15121	Banten	Kota Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-08-04	Maintenance	30/05/2024	On Line Training
439a95d8-d082-4852-ad1a-401cbf37c23e	680	Kyriad M Hotel Sorong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	121	4	2018-02-01	Jl. Sungai Maruni, Klawuyuk, Kec. Sorong Utara, Kota Sorong, Papua Barat Daya 98416	Papua Barat Daya	Kota Sorong	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	0f8b16f7-fe11-4265-81f3-9436fd5aa50f	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-05-05	Maintenance	05/05/2025	Maintenance
441fd867-d7a9-45ee-b2ff-a6e846650718	912	Parador Office	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Soho Office Park Kav. 9, 3rd Floor, Jl. Boulevard Raya Gading Serpong, Gading, Serpong, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
502a8fff-89e2-4480-8b00-f004b058ed1a	762	Lelewatu Resort Sumba	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	28	5	2019-04-01	Jl. Lelewatu No.168, Wei Mangoma, Wanokaka, Kabupaten Sumba Barat, Nusa Tenggara Tim. 87272	Nusa Tenggara Timur	Kabupaten Sumba Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-15	Retraining	21/11/2025	On Line Training
55b1885d-9907-4f05-9d34-0c05fe36746c	535	Lembah Permai Resort	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	134	2	2016-10-01	Jl. Raya Cipanas No.219, Sindanglaya, Kec. Cipanas, Kabupaten Cianjur, Jawa Barat 43253	Jawa Barat	Kabupaten Cianjur	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-08-04	Retraining	04/08/2023	Retraining
c4814eda-4c17-436c-adf7-1e1710f157ef	749	Reveur Head Office	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
b84f97ee-103a-49dc-bbd0-0f2ec5e7b231	151	Dafam Mataram Hotel & Resort Pekalongan (Owned)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	90	\N	2012-02-05	Jalan Urip Sumoharjo No.53 Medono, Podosugih, Kec. Pekalongan Bar., Kota Pekalongan, Jawa Tengah 51111	Jawa Tengah	Kota Pekalongan	\N	\N	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b526f24e-e110-4359-bb8c-d5da3d91f380	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-28	Retraining	28/12/2025	Retraining
b8adf094-6c4b-4cd7-99a0-c6996c8d1254	198	Aerotel Smile Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	160	4	2012-08-17	Jl. Muchtar Lutfi No.38, Maloku, Kec. Ujung Pandang, Kota Makassar, Sulawesi Selatan 90111	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
ba75b50f-1847-460e-a3d9-9a2b1989bc82	631	Jambuluwuk Oceano Seminyak Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	138	10	2016-11-01	Jl. Petitenget No.108, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	a70f3070-a500-4a3a-8207-7a292edc2a4d	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-12-08	Implementation	20/11/2025	Remote Installation
bb333ecb-840a-40d5-a387-2b9664d4936d	663	Batiqa Hotel Jababeka	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	127	0	2017-02-01	Kawasan Industri Jababeka II, Jl. Niaga Raya Blok CC No.3A, Cikarang Sel., Kabupaten Bekasi, Jawa Barat 17530	Jawa Barat	Kabupaten Bekasi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7018e52-3eb7-4075-8a6b-202c7dbfc083	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-20	Maintenance	20/07/2025	Maintenance
bb49dad5-be7d-481c-a8cc-43ec35170ad9	1	Grand Aquila Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	237	3	2012-01-01	Jl. Dr. Djunjunan No.116, Sukagalih, Kec. Sukajadi, Kota Bandung, Jawa Barat 40173	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-08-16	Upgrade	16/08/2025	Upgrade
bbc5a662-edce-4cab-a6ad-0ff4573b612c	542	Grand Luley Manado	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	123	5	2015-11-01	Tongkeina, Bunaken, Tongkeina, Bunaken, Kota Manado, Sulawesi Utara 95244	Sulawesi Utara	Kota Manado	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-22	Retraining	22/03/2024	Retraining
bbe55585-7c3b-4c86-a9af-6ce90413f3a8	61	Arion Suites Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	103	0	2005-01-08	Jl. Otto Iskandar Dinata No.16, Pasir Kaliki, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40171	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3271c59d-2f4d-4aae-b0ec-01ab476a54b1	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-15	Retraining	15/11/2025	Retraining
81a914d0-0737-4d0a-b68d-0a893f314b48	729	Living Asia Resort & Spa Lombok	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	66	7	2018-02-01	Jl. Raya Senggigi Jl. Dusun Lendang Luar, Malaka, Kec. Pemenang, Kabupaten Lombok Utara, Nusa Tenggara Bar. 83352	Nusa Tenggara Barat	Kabupaten Lombok Utara	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1c0e57d6-6695-41b8-8678-cf44bef057d0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-07	Retraining	07/12/2025	Retraining
07e706ae-0da2-4e74-8466-c549f472cf60	441	Indoluxe Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	200	5	2014-11-24	Jl. Palagan Tentara Pelajar No.106, Sumberan, Sariharjo, Kec. Ngaglik, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55581	Daerah Istimewa Yogyakarta	Kabupaten Sleman	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	6b3bb293-f0f7-4d4c-aa72-9e8c407d1ba2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-09-24	Retraining	24/09/2023	Retraining
08f1f66e-0b7c-4dc6-8c96-d8af9eefed0a	99	Hotel Ciputra Semarang (HCS)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	200	8	2010-07-01	Jl. Simpang Lima No. 1, Semarang 50134, Kota Semarang, Jawa Tengah - Indonesia	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-21	Maintenance	14/01/2026	Remote Installation
125dddd6-c854-455b-a583-7f694c66664a	1028	Hotel Truntum Cihampelas - Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	102	3	2025-09-01	Jl. Cihampelas No.91, Cipaganti, Kecamatan Coblong, Kota Bandung, Jawa Barat 40131	Jawa Barat	Kota Bandung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-04	Maintenance	04/10/2025	Maintenance
53a9faac-c20a-4436-991d-fa5bcb0aa928	757	Morazen Hotel Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	172	5	2018-09-20	Jl. Kayun No.2-4, Embong Kaliasin, Genteng, Surabaya City, East Java 60271	Jawa Barat	Kota Surabaya	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-13	Retraining	13/02/2026	Maintenance
a637b3b0-78b3-4a30-be50-cafbb6852721	717	BBC Hotel Lampung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	123	3	2017-12-08	Jl. Proklamator Raya, Bandar Jaya Tim., Kec. Terbanggi Besar, Kabupaten Lampung Tengah, Lampung 34163	Lampung	Kabupaten Lampung Tengah	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-07	Maintenance	12/01/2026	On Line Training
e508c492-7aab-4b21-b848-853cf9dd9057	282	Peppers Seminyak	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	64	3	2013-02-01	Jl. Pura Telaga Waja Jl. Petitenget, Seminyak, Kec. Kuta Utara, Kabupaten Badung, Bali	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-09-03	Upgrade	10/01/2024	Remote Installation
e70fc4f6-fcd5-4f98-b330-c540f1d1a0cf	325	Swiss-Belhotel Cirebon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	183	0	2013-12-05	Cirebon Superblock, Pekiringa, Jl. Cipto Mangunkusumo No.26, Pekiringan, Kec. Kesambi, Kota Cirebon, Jawa Barat 45131	Jawa Barat	Kota Cirebon	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-05-11	Maintenance	08/01/2026	Remote Installation
e742fc38-314c-4f47-b629-02abe9b7ab89	945	Khas Pekalongan Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	98	5	2023-02-20	Jl. DR. Cipto Mangunkusumo No. 24, Sugihwaras, Kota Pekalongan, Jawa Tengah 51125	Jawa Tengah	Kota Pekalongan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-03-10	Implementation	10/03/2023	Implementation
e8386d42-f4d3-492c-9afd-427e1a382f6b	158	Swiss-Belhotel Balikpapan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	255	5	2013-06-05	Balikpapan Ocean Square, Jl. Jenderal Sudirman, Klandasan Ilir, Kota Balikpapan, Kalimantan Timur 76113	Kalimantan Timur	Kota Balikpapan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2018-11-18	Maintenance	09/01/2026	Remote Installation
e8524b51-b48a-4e1e-be1d-b99e2ab107c4	619	Sawana Suites Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	35	1	2016-02-15	Jl. Danau Limboto No.B1 45, RT.5/RW.4, Bendungan Hilir, Tanah Abang, Central Jakarta City, Jakarta 10210	DKI Jakarta	Kota Jakarta Pusat	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-02-19	Retraining	10/03/2025	On Line Training
e9f16cc7-2bd9-4704-a7b8-e239960a68ca	784	Oak Tree Glamping Resort Batu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	26	1	2019-04-01	Jalan Raya Tawangargo No.1, Sisir, Kec. Batu, Kota Batu, Jawa Timur 65314	Jawa Timur	Kota Batu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-03-16	Maintenance	16/03/2020	Maintenance
ebe9fd49-b887-4fee-9e6e-b1142758f856	848	Khas Ombilin Heritage Hotel Sawahlunto	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	30	1	2020-10-05	Jl. Ahmad Yani, Pasar, Lembah Segar, Kota Sawahlunto, Sumatera Barat 27422	Sumatera Barat	Kota Sawahlunto	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	7508fc4c-86ea-4d4e-bba1-31bb7982310a	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2020-10-15	Implementation	15/10/2020	Implementation
f0a57cfe-67f4-4492-8c2a-704d29fc2a32	932	Parkside Alhambra Hotel - Training Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	48	1	2023-01-23	Jl. Pante Pirak No.10, Simpang Lima, Kec. Kuta Alam, Kota Banda Aceh, Aceh 23127	Nanggroe Aceh Darussalam	Kota Banda Aceh	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	da2341a4-4289-4431-a330-343e969ef15b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
f2673f41-c1fe-409a-95e6-ce478e0a6184	193	Prime Park Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	129	9	2012-10-15	Jl. Penghulu Haji Hasan Mustofa No.47/57, Neglasari, Kec. Cibeunying Kaler, Kota Bandung, Jawa Barat 40124	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	3545ee81-be6c-44fd-b5ed-65d101d5a853	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-22	Maintenance	22/06/2025	Maintenance
f277d56b-44f8-4807-a80c-2e8f5ce6314d	123	Kupu Kupu Jimbaran Bali Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	40	0	\N	Jl. Raya Uluwatu, Jimbaran, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-21	Retraining	21/02/2025	Retraining
c07da5bb-3e8e-4039-ad68-598a2ccebe9b	616	Almadera Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	91	3	2016-05-01	Somba Opu St No.235, Maloku, Ujung Pandang, Makassar City, South Sulawesi 90111	Sulawesi Selatan	Kota Makassar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-02	Upgrade	02/02/2025	Upgrade
2790db17-8123-4e10-b537-94052dc9b889	466	Hotel Ciputra Cibubur (HCC)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	108	8	2015-04-20	Hotel Ciputra Cibubur (HCC) Jl. Alternatif Cibubur No.KM.4, Jatikarya, Kec. Jatisampurna, Kota Bks, Jawa Barat 17435	Jawa Barat	Kota Bekasi	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	045a1448-ffb6-46a2-8101-a7361bd47550	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-13	Maintenance	20/11/2025	Remote Installation
3a18716b-96ef-40e1-b8a5-b517736a71bc	996	Moriah Hills Hotel - Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	80	3	2024-10-01	Jl. Telaga Nirwana, Cihuni, Kec. Pagedangan, Kabupaten Tangerang, Banten 15332	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-13	Maintenance	13/01/2026	Maintenance
450da517-cd02-4e88-a1b3-eba0a3ea1779	741	Prama Sanur Beach Bali (PSB)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	428	11	2018-12-01	Jl. Cemara, Sanur, Denpasar Selatan, Kota Denpasar, Bali 80228	Bali	Kota Denpasar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	68350c01-b4d1-4246-a289-c79b0160300b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-24	Maintenance	24/10/2025	Maintenance
453856b8-7c55-49bf-8940-7208ebd2320e	88	Merlynn Park Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	302	8	2010-01-01	Jl. KH. Hasyim Ashari No.29-31, RT.7/RW.7, Petojo Utara, Kecamatan Gambir, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10130	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	72a2fc8f-c7ba-4bed-90c1-96c5b6910530	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-16	Retraining	16/03/2025	Retraining
466f5cb2-0e61-4e2f-8271-adf43c4c67d8	32	Manhattan Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	255	8	2001-01-01	Jalan Professor Doktor Satrio, Jl. Casablanca No.24, RT.7/RW.4, Kuningan, Karet Kuningan, Kuningan, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12950	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	72a2fc8f-c7ba-4bed-90c1-96c5b6910530	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-01-31	Maintenance	25/03/2025	Others
c36741b9-4453-4d88-a988-e717d547a74b	25	Galeri Ciumbuleuit Hotel & Apartment	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	89	0	2000-08-01	Jl. Ciumbuleuit No.42A, Hegarmanah, Kec. Cidadap, Kota Bandung, Jawa Barat 40141	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	034b1b75-4130-4e20-ba0c-690a835e80e0	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-22	Maintenance	22/01/2026	Maintenance
c4bde408-14c0-4ff1-8c34-78dae5d16501	910	GDAS Health & Wellness Ubud	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	28	8	2022-10-04	Jl. Cempaka, Banjar Kumbuh, Mas, Kecamatan Ubud, Kabupaten Gianyar, Bali 80571	Bali	Kabupaten Gianyar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-31	Retraining	31/10/2025	Retraining
f4833cb3-9840-49eb-8138-4a0557c269b9	786	M Bahalap Hotel Palangkaraya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	227	5	2019-05-01	Jl. RTA Milono No. 51 Km 1.3, Menteng, Jekan Raya, Kota Palangka Raya, Kalimantan Tengah 73111	Kalimantan Tengah	Kota Palangka Raya	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-07-24	Maintenance	17/11/2023	Remote Installation
f4a34f38-0bc4-4cf2-ae85-e480baecf7ee	94	Kawana Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	42	0	2011-04-01	Jl. MH. Thamrin, Kelurahan No.71, Ranah Parak Rumbio, Kec. Padang Sel., Kota Padang, Sumatera Barat 25212	Sumatera Barat	Kota Padang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-07	Maintenance	07/12/2025	Maintenance
f6e8bfc3-d4d1-4dbb-a447-5da1e41ce8a9	802	Mine Home Kebon Kawung Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	107	3	2019-06-01	Jl. Marjuk No.9, Pasir Kaliki, Kec. Cicendo, Kota Bandung, Jawa Barat 40171	Jawa Barat	Kota Bandung	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	787810e4-5b4b-4129-adb0-0a5c67546a56	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2019-07-05	Implementation	10/04/2025	On Line Training
f6ff9fbb-7cf6-4869-91a6-9bb455aa0b9a	547	Sotis Luxury Villas Canggu Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	27	3	2016-03-10	Jl. Raya Kayutulang, Canggu, Kec. Kuta Utara, Kabupaten Badung, Bali 80351	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-01-13	Upgrade	13/01/2023	Upgrade
09f2f8c6-595c-4294-aad5-cbb1806c2065	650	The Gunawarman Luxury Residence (Prana Nadi)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	35	1	2016-09-13	Jl. Gunawarman No.3, RT.6/RW.3, Selong, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12110	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	669515b7-0c7c-4064-bd1b-95133b574a84	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-22	Maintenance	22/01/2026	Maintenance
0bb5bfb1-cb9f-415e-a6ee-05d8ab697dee	646	The Sahira Hotel & Restaurant Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	122	4	2016-09-01	Jl. A. Yani No.17 - 23, Tanah Sareal, Kec. Tanah Sereal, Kota Bogor, Jawa Barat 16161	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	2aed36c5-71e5-48da-9e73-994e5f234213	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-28	Retraining	28/12/2025	Retraining
10914931-71b9-4125-82b7-64d974e1d0ac	1032	The Papilion - Kemang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	9	2025-06-01	Jl. Kemang Raya No.45 AA, Bangka, Kec. Mampang Prpt., Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12730	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-13	Implementation	13/07/2025	Implementation
13119185-3b73-4165-8de7-c143b7c35523	495	Zest Hotel Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	139	2	2015-03-11	No.27, Jl. Raya Pajajaran, Babakan, Kecamatan Bogor Tengah, Kota Bogor, Jawa Barat 16128	Jawa Barat	Kota Bogor	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-29	Maintenance	29/11/2025	Maintenance
160dea0c-d4da-4eb3-a6bb-88d0f4922b49	787	The Zuri Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	171	5	2019-02-24	Kompleks Transmart, Jl. Soekarno - Hatta, Labuh Baru Tim., Kec. Payung Sekaki, Kota Pekanbaru, Riau 28292	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-14	Maintenance	14/08/2025	Maintenance
18ca2757-614f-46f6-8412-f69970bd5c89	197	The ZHM Premiere Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	202	2	2012-11-15	Jl. Thamrin No.27, Alang Laweh, Kec. Padang Sel., Kota Padang, Sumatera Barat 25133	Sumatera Barat	Kota Padang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-10-10	Maintenance	10/10/2025	Maintenance
c60c71a2-2938-4355-883a-b8d8f3cf3080	842	Aruss Hotel Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	145	3	2022-03-15	Jl. Dr. Wahidin No.116, Jatingaleh, Kec. Candisari, Kota Semarang, Jawa Tengah 50254	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-04-10	Retraining	10/04/2025	Retraining
482ab1d3-e46c-4795-a0e4-147778857d1e	457	Khas Parapat	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	101	3	2014-08-01	Danau Toba, Jl. Marihat No.1, Tiga Raja, Girsang Sipangan Bolon, Kabupaten Simalungun, Sumatera Utara 21174	Sumatera Utara	Kabupaten Simalungun	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-12-15	Maintenance	15/01/2026	On Line Training
4885d325-fe0b-406b-8530-30225c2eca26	364	Petit Paris Lyon Essence Cafe	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Darmawangsa X, No. 86\nKebayoran Baru\nJakarta Selatan	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2014-02-11	Maintenance	11/02/2014	Maintenance
48a95c4e-695d-4b20-982b-c2995a424acf	26	Rama Candidasa Resort & Spa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	78	1	\N	Jl. Raya Sengkidu, Sengkidu, Kec. Manggis, Kabupaten Karangasem, Bali 80871	Bali	Kabupaten Karangasem	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c003422c-c07a-4f8d-8f94-c8b529273669	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-26	Upgrade	26/11/2025	Upgrade
4a6ce5c9-97dd-4c58-a94a-9928b76ac0fe	223	Nagoya Hill Hotel Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	250	7	2015-04-18	No. 1, Nagoya Hill Super Block, Jl. Teuku Umar, Lubuk Baja Kota, Kec. Lubuk Baja, Kota Batam, Kepulauan Riau 29432	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2017-08-06	Maintenance	17/12/2025	Remote Installation
4bb8ceb3-655c-482f-8b86-b66431c1d7dc	904	Parkside Star Hotel dh Metta Star Jayapura	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	71	3	2022-07-16	Jl. Raya Waena, Kp. Waena, Kec. Abepura, Kota Jayapura, Papua 99532	Papua	Kota Jayapura	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	da2341a4-4289-4431-a330-343e969ef15b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-09-06	Implementation	08/01/2025	On Line Training
605c7210-e9eb-4a17-a37f-5885a0328afc	882	Morazen Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	198	5	2022-06-18	Jalan Nasional III Yogyakarta - Purworejo KM 41.5, KM 41.5, Kec. Temon, Kabupaten Kulon Progo, Daerah Istimewa Yogyakarta 55654	Daerah Istimewa Yogyakarta	Kabupaten Kulon Progo	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	fa3e4c27-6f17-4fbc-96f5-4abd4db9f606	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-24	Maintenance	24/02/2026	Maintenance
656fd259-7998-4dd8-bef3-57577c2b5c9b	909	Moritz Biz Gandaria	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	70	5	2022-07-11	Jl. Gandaria Tengah I No.24, RT.4/RW.1, Kramat Pela, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12130	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1520e95b-70d9-4240-97ab-002d96d08614	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-21	Maintenance	21/06/2025	Maintenance
c757f3e7-3471-4d41-a829-1bc065369183	260	DBamboo Suites	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	106	3	2012-12-01	Jl. Anggrek 4 No.47, RT.14/RW.7, Kuningan, Karet Kuningan, Kecamatan Setiabudi, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12940	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-15	Maintenance	15/03/2025	Maintenance
cae3cd90-5dbb-442a-b120-94ff8d2710d3	242	D’Primahotel Airport Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	158	5	2014-01-01	Jl. Benteng Betawi No.88, Buaran Indah, Kec. Tangerang, Kota Tangerang, Banten 15148	Banten	Kota Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-31	Maintenance	31/07/2025	Maintenance
cb64e13b-72f3-4829-b3a9-3eaf3e931913	920	Grand Central Premier Hotel - Medan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	159	6	2022-12-13	Jl. Putri Merak Jingga No.3A, Kesawan, Kec. Medan Bar., Kota Medan, Sumatera Utara 20231	Sumatera Utara	Kota Medan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-03-26	Maintenance	26/03/2024	Maintenance
cd9dda1e-4252-44b6-b25b-e27927088f8c	758	D'Primahotel Airport 2 Jakarta (Gondo)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	152	4	2018-09-22	Jl. Peta Barat No.95, Pegadungan, Kec. Kalideres, Kota Tangerang, Banten 11830	Banten	Kota Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-10	Maintenance	10/12/2025	Maintenance
cfaa44f6-d7f4-434b-917d-23c8548b126b	839	Herloom Hotel & Residence Sihanoukville	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	305	5	2022-02-18	Otres Marina Rd#833, Sangkat 4, Sihanoukville 18000, Preah Sihanouk, Cambodia	Cambodia	Preah Sihanouk	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2022-04-14	Implementation	04/12/2023	On Line Training
d3ca6140-4ec5-464e-bd4c-8705649f77ee	288	Ananta Legian Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	175	2	2012-01-02	Jl. Werkudara No.539, Legian, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
1a237bb4-ee44-4d52-8212-ea3ea7b82eb9	211	The BCC / Batam City Condominium	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	228	\N	2011-10-13	Jl. Bunga Mawar No.5, Batu Selicin, Kec. Lubuk Baja, Kota Batam, Kepulauan Riau 29444	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2012-12-15	Retraining	15/12/2012	Retraining
22330c94-6c4a-46fe-bc16-8b1f65ae3269	807	The Zuri Hotel Dumai	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	111	3	2019-09-10	Jl. Jend. Sudirman No.108, Tlk. Binjai, Dumai Tim., Kota Dumai, Riau 28826	Riau	Kota Dumai	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-14	Maintenance	14/07/2025	Maintenance
289366ba-6c80-4d5d-8262-6658222dce0f	234	Winstar Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	91	4	2013-06-28	Jl. Moh. Ali No.118, Padang Terubuk, Kec. Senapelan, Kota Pekanbaru, Riau 28155	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-01-24	Maintenance	26/10/2021	On Line Training
28a3ad1e-0f87-42b1-b8dd-ade2f9bc3a12	340	The Melio Enim Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	105	3	2013-12-23	Jl. Jenderal Sudirman, Talang Jawa, Kel. Pasar III, Kec. Muara Enim, Kabupaten Muara Enim, Sumatera Selatan 31314	Sumatera Selatan	Kabupaten Muara Enim	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-12-20	Retraining	20/12/2023	Retraining
ebdf7b3e-e516-4d77-b4bc-d34738c7e64f	723	Monopoli Hotel Kemang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	68	0	2017-12-15	Jl. Taman Kemang No.12, RT.14/RW.1, Bangka, Kec. Mampang Prpt., Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12730	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	669515b7-0c7c-4064-bd1b-95133b574a84	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-10	Retraining	10/10/2025	Retraining
5809c542-cddf-41d4-bcb7-27ba48ea03f7	776	Wayame Bay Ambon - Rejeki IV (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	77	0	2018-10-15	Jl. Ir. Putuhena RT.004/RW.002, Wayame, Teluk Ambon, Kota Ambon, Maluku	Maluku	Kota Ambon	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-12-03	Maintenance	03/12/2023	Maintenance
0046a638-e915-4748-a019-c0e5a85e4e89	895	Indonesia Convention Exhibition (ICE) BSD City	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	10	2	2022-01-01	Jl. BSD Grand Boulevard No.1, Pagedangan, Kec. Pagedangan, Kabupaten Tangerang, Banten 15339	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	b48c6277-d81d-4afe-a226-44f8b5b85019	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-21	Retraining	21/03/2025	Retraining
1d7890b0-ac3a-46d2-a2b8-987a55327108	1012	Janji Surga -Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	5	2	2024-12-15	Gg. Kenanga, Cepaka, Kec. Kediri, Kabupaten Tabanan, Bali 80351	Bali	Kabupaten Tabanan	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-21	Retraining	21/03/2025	Retraining
2301dfce-e2e2-409a-b69c-6a239e8d5da5	454	Inna Tretes Hotel & Resort Pasuruan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	70	2	2014-08-01	Jl. Pesanggrahan No.2, Semeru, Prigen, Kec. Prigen, Pasuruan, Jawa Timur 67157	Jawa Timur	Kabupaten Pasuruan	26c188d8-2bea-46f8-81e0-4d48ef95f4a6	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-05-18	Upgrade	18/05/2023	Upgrade
289b2481-f48e-4bb5-930e-d93263a41c16	836	JHL Solitaire Gading Serpong Hotel Tangerang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	141	11	2020-07-01	Jl. Gading Serpong Boulevard Blok S No.5, Curug Sangereng, Kecamatan Kelapa Dua, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-12	Retraining	12/11/2025	Retraining
28ba03cd-2acb-4216-a3d5-8d19545f7940	377	Yunna Hotel Lampung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	102	1	2014-03-14	Jl. Ikan Hiu No.1, Tlk. Betung, Kec. Telukbetung Selatan, Kota Bandar Lampung, Lampung 35211	Lampung	Kota Bandar Lampung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-05-12	Maintenance	12/05/2024	Maintenance
2b478f74-485c-4179-a402-285f5a08bfde	782	Swiss-BelResort Tanjung Binga Belitung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	77	4	2018-12-24	Jl. Tj. Pandan - Tj. Kelayang No.168, Terong, Sijuk, Kabupaten Belitung, Kepulauan Bangka Belitung 33414	Bangka Belitung	Kabupaten Belitung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-02-21	Retraining	12/01/2026	Remote Installation
2be1610e-9844-430d-9595-5db2ccb37d09	850	The Manohara Hotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	6	2020-11-01	Jl. Affandi, Santren, Caturtunggal, Kec. Depok, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55281	Daerah Istimewa Yogyakarta	Kabupaten Sleman	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-02-08	Maintenance	13/08/2025	On Line Training
2c097451-6f00-4047-b6ee-6af965a0ea54	199	Zuri Express Lippo Cikarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	138	3	2012-11-05	Lippo Cikarang, Jl. Kemang Raya No.6, Sukaresmi, Cikarang Sel., Kabupaten Bekasi, Jawa Barat 17530	Jawa Barat	Kabupaten Bekasi	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-31	Maintenance	31/08/2025	Maintenance
2c76018a-5087-45c1-a513-8961245c8129	428	Swiss-Belhotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	296	5	2016-06-01	Jl. Ujung Pandang No.8, Bontoala, Kec. Makassar, Kota Makassar, Sulawesi Selatan 90111	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-18	Maintenance	18/01/2026	Maintenance
2e564ef3-d37c-4c79-a9ad-b4131ca97a01	644	Zest Harbour Bay Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	182	1	2016-08-01	Harbour Bay Complex Jalan Duyung Sei Jodoh, Sungai Jodoh, Kec. Batu Ampar, Kota Batam, Kepulauan Riau 29444	Kepulauan Riau	Kota Batam	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-10-22	Maintenance	22/10/2019	Maintenance
d8b7a00c-23ba-4920-8ac4-db3f73a028a5	1034	d'primahotel Harmoni Jakarta (Hayam Wuruk)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	\N	\N	2025-04-01	Jl. Hayam Wuruk 5 No.5, Kb. Klp., Kecamatan Gambir, Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10120	DKI Jakarta	Kota Jakarta Pusat	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-06-10	Implementation	10/06/2025	Implementation
d8cece15-23c2-4c8e-89d6-98652eefa3b5	393	D'Primahotel Jayakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	48	\N	2023-04-01	Tiangseng Komp. Rukan Pangeran Jayakarta Center, Jl. Pangeran Jayakarta No.73, RT.3/RW.6, Mangga Dua Sel., Kecamatan Sawah Besar, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10730	DKI Jakarta	Kota Jakarta Pusat	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-09-20	Maintenance	20/09/2024	Maintenance
d9952ec4-6c9f-422b-8991-4e87678ed513	1067	d'primahotel Yogyakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	42	3	\N	Gandekan Lor No.47, Malioboro, Gedong Tengen, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55272.	Daerah Istimewa Yogyakarta	Kota Yogyakarta	e8771417-8cfb-4742-9239-b361765db63f	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
da57d093-6649-4638-95ad-7813f04a2273	894	IPC Residence & Convention. PT. PMLI	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	140	5	2022-01-01	Jl. Beringin I Jl. Raya Gadog No.1, Pandansari, Kec. Ciawi, Kabupaten Bogor, Jawa Barat 16720	Jawa Barat	Kabupaten Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-05-06	Maintenance	06/05/2025	Maintenance
dac655f3-a124-4560-8113-b4bd85498b85	452	Grand Inna Malioboro Yogyakarta (Garuda)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	2	2014-12-01	Jl. Malioboro No.60, Suryatmajan, Kec. Danurejan, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55213	Daerah Istimewa Yogyakarta	Kota Yogyakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2023-07-22	Upgrade	22/07/2023	Upgrade
4db074c6-00db-4254-a8bd-49ad53fea914	1050	Nawasena Mandiri Corporate University	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	191	3	2025-08-11	Jl. Daan Mogot, RT.5/RW.3, Wijaya Kusuma, Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta	DKI Jakarta	Jakarta Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-03	Maintenance	14/01/2026	In House Training
5c054daa-f9eb-49aa-9824-735b12ae9cec	273	Jolin Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	53	1	2012-12-12	Jl. Pengayoman No.7, Masale, Kec. Panakkukang, Kota Makassar, Sulawesi Selatan 90231	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-01-21	Maintenance	21/01/2024	Maintenance
4e1694a0-dee6-410a-a6b5-42fe18866522	5	Rama Garden Palu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	87	\N	2011-08-01	Jl. Tj. Santigi No.26, Lolu Sel., Kec. Palu Selatan, Kota Palu, Sulawesi Tengah 94111	Sulawesi Tengah	Kota Palu	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-10-16	Maintenance	16/10/2023	Maintenance
4e3e09ec-6d5f-4517-8a2c-5258add2384b	847	JHL Jeep Station Indonesia Resort (JSI)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	137	7	2020-09-01	Jl. Cikopo Sel. http://no.km/, RW.5, Sukagalih, Kec. Megamendung, Bogor, Jawa Barat 16770	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-02-08	Maintenance	08/02/2026	Maintenance
4f475e70-fbb0-4b79-a889-48a141604c55	399	Karebosi Condotel Hotel Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	152	3	2015-02-02	Jl. Jend. M. Jusuf No.1, Gaddong, Kec. Makassar, Kota Makassar, Sulawesi Selatan 90174	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-27	Maintenance	27/07/2025	Maintenance
51cadbfe-b7ae-40ac-9fc3-90fb9076772f	318	Pranaya Suites BSD City	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	100	3	2013-10-02	Pranaya Boutique Hotel, Commercial Park BSD Lot VIII, Jl. Komp. BSD No.3 2nd Floor, Kota Tangerang Selatan, Banten 15322	Banten	Kota Tangerang Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-11-03	Maintenance	03/11/2025	Maintenance
52f3db35-6ac7-4e03-a844-7a89af9c48e5	365	Savoy Homann Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	186	9	2014-01-23	Jl. Asia Afrika No.112, Cikawao, Kec. Lengkong, Kota Bandung, Jawa Barat 40261	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-05-12	Maintenance	18/06/2025	On Line Training
dbd1e88f-b706-4087-81f7-f3ddd56d90ec	841	Episode Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	320	5	2022-01-16	Jl. Gading Serpong Boulevard No.6 - 7, Curug Sangereng, Kec. Klp. Dua, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-14	Retraining	14/12/2025	Retraining
dc097947-afc6-4a1d-9605-fbdd0d41e985	698	Asana Sincerity Dorm-Aero	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	120	3	2017-01-07	Jl. Raya Duri Kosambi No. 125,\nGITC - Cengkareng\nJakarta Barat	DKI Jakarta	Kota Jakarta Barat	\N	\N	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	68350c01-b4d1-4246-a289-c79b0160300b	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-12-21	Maintenance	21/12/2025	Maintenance
33308ac9-990f-47fa-9105-25f305d3e874	977	Swiss-Belinn Airport Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	133	3	2024-01-01	Jl. Raya Bandara Juanda No.1,88, Semalang, Semambung, Kec. Gedangan, Kabupaten Sidoarjo, Jawa Timur 61254	Jawa Timur	Kabupaten Sidoarjo	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-02-15	Implementation	12/01/2026	Remote Installation
37c51b2d-6c03-4ac2-aba1-76dc6722ee65	925	Tembesu PTE. LTD	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2023-01-01	Pulau Bawah, Desa Kiabu, Kecamatan Siantan\nSelatan Kebupatan Kepulauan Anambas, Provinsi Kepulauan Riau	Kepulauan Riau	Kabupaten Kepulauan Anambas	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	24e8eaf5-f179-4623-a5c1-44bbed901060	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
3d31f10b-97f2-4fbd-bc7d-e26869fa8e3b	739	Zuri Express Jimbaran Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	85	3	2018-04-25	 Jl. Uluwatu II No.88X, Jimbaran, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-15	Retraining	15/08/2025	Retraining
3e7289e2-4161-4010-a0a3-f8c2aa8fbfb0	670	Tijili Benoa Hotel Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	270	6	2017-03-01	Jl. Pratama No.62, Tj. Benoa, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-12	Retraining	12/07/2025	Retraining
3ebb0f57-e7fa-4414-a78c-073ed3de708d	411	Zuri Hospitality Management (ECOS)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	Jl. Mangga Dua Dalam No. 55-56, Mangga Dua Selatan, Sawah Besar - Jakarta Pusat	DKI Jakarta	Kota Jakarta Pusat	\N	4f67719b-8dec-4d7d-a0d6-dc336951d15c	8bca21b7-bb1b-4581-9934-5c2aeb49783a	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-09-04	Others	04/09/2025	Others
401bc970-bfa6-4933-8ecb-94e2d4feb645	544	The Sintesa Jimbaran Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	150	5	2015-09-01	Jl. Kencana No.1, Jimbaran, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b6de363a-4dc6-4712-964c-f6156ba64afa	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-03-23	Maintenance	23/03/2019	Maintenance
4221543f-1d15-4590-92f5-7d2b19e3e671	175	Swiss-BelInn SKA Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	108	\N	2012-03-15	Jl. Soekarno Hatta Lot 69, Complex SKA Mall, Delima, Tampan, Delima, Kec. Tampan, Kota Pekanbaru, Riau 28294	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-04	Maintenance	04/08/2025	Maintenance
a2c0dd1c-5a99-472f-bd33-3a7271eb1cf4	1054	Sango Hotel Management-Head Office	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2025-10-23	Jl. K.H. Hasyim Ashari 29-31,\nJakarta Pusat 10130\nIndonesia	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	72a2fc8f-c7ba-4bed-90c1-96c5b6910530	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
2c80fd42-c6b9-4109-bb94-ed2d079bd3b3	791	Swiss-BelInn Gajah Mada	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	105	3	2019-04-01	Jl. Gajah Mada No.49, Babura, Kec. Medan Baru, Kota Medan, Sumatera Utara 20154	Sumatera Utara	Kota Medan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	51d71edf-55ca-4773-9e80-02519c048c5a	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-07-05	Maintenance	05/07/2024	Maintenance
540f56f3-1d5e-4345-9513-950e379b2d18	1051	NIM’S Hotel - Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	109	3	2025-10-01	Jl. Sunset Road No. 17, Seminyak, Kec. Kuta, Kab. Badung, Bali – 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-10-29	Implementation	29/10/2025	Implementation
54ee8efe-7ecc-4623-bfbb-7371efda12b0	1024	Mustika Yogyakarta Resort & SPA	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	246	5	2025-02-13	Jl. Laksda Adisucipto No.KM.8, RW.7, Nayan, Maguwoharjo, Kec. Depok, Kabupaten Sleman, Daerah Istimewa Yogyakarta 55282	Daerah Istimewa Yogyakarta	Kabupaten Sleman	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-13	Implementation	13/03/2025	Implementation
5509f1cf-3322-420a-95c5-83cecf5ef9ee	7	Nusa Dua Beach Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	415	\N	2003-09-01	Kawasan Pariwisata, Nusa Dua Lot, Jl. Nusa Dua North 4, Benoa, South Kuta, Badung Regency, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	20/01/2022	Remote Installation
551cbcfa-055b-4218-b990-0183ccff5463	938	Khas Semarang Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	152	5	2023-01-15	Jl. Depok No.33, Kembangsari, Kec. Semarang Tengah, Kota Semarang, Jawa Tengah 50133	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-08-07	Maintenance	07/08/2024	Maintenance
58241bc7-5868-4b69-80a0-ac6f8b5a8673	546	Sotis Hotel Kupang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	88	10	2015-12-06	Jl. Terusan Timor Raya http://no.km/. 3, RW.No.90, Pasir Panjang, Kec. Kota Lama, Kota Kupang, Nusa Tenggara Tim. 85229	Nusa Tenggara Timur	Kota Kupang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cbcafb66-f196-45e7-9a06-0625b32ad82c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-07	Maintenance	07/12/2025	Maintenance
8a021f3c-f995-48f2-87c9-c7df98c9aa0b	880	JoyLive Hotel BSD City	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	143	3	2021-11-07	Jl. BSD Sektor Dormitory B/6, Pagedangan, Pagedangan, Kab. Tangerang Banten 15339	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2026-01-09	Maintenance	09/01/2026	Maintenance
c3b88985-393a-4836-add7-a4f5ee20bcc0	844	JHL Collections-Head Office	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	JHL Solitaire Gading Serpong, Jl. Gading Serpong Boulevard, Curug Sangereng, Kec. Klp. Dua, Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	4f67719b-8dec-4d7d-a0d6-dc336951d15c	8bca21b7-bb1b-4581-9934-5c2aeb49783a	24e7fd22-056d-4d6b-a8f2-1a87ec60d4a2	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-07-15	Maintenance	15/07/2025	Maintenance
691b7a77-0c6a-4aa0-b2a9-7ed33355c5fb	916	Hades VIP - Lounge, Bar, & Karaoke	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	8	2023-10-14	Jl. Alternatif Cibubur No.39 Rt.002 / Rw.009,\nJatikarya, Jatisampurna, Kota Bekasi, Jawa Barat.	Jawa Barat	Kota Bekasi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2496cfed-551c-4436-8a72-daf301050ac3	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-09-25	Retraining	25/09/2025	Retraining
d44d5259-ea87-491c-8ecf-ff4e9fc0395c	104	Asmila Boutique Hotel Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	36	0	2010-01-11	Jl. Dr. Setiabudi No.54, Hegarmanah, Kec. Cidadap, Kota Bandung, Jawa Barat 40141	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-11-26	Maintenance	26/11/2024	Maintenance
014de9a1-0390-45f9-bd65-fe2751190cad	272	The Vouk Hotel & Suites Nusa Dua Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	176	6	2013-04-01	Jl. Raya Nusa Dua Selatan, Sawangan, Benoa, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-07-14	Maintenance	27/02/2025	On Line Training
05af2c79-6169-4f79-9665-8a7f286b7a14	814	The Garcia Ubud Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	57	5	2020-02-01	Jl. Raya Silungan, Lodtunduh, Kecamatan Ubud, Kabupaten Gianyar, Bali 80571	Bali	Kabupaten Gianyar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-09-18	Retraining	18/09/2025	Upgrade
091d7c1f-f5cf-44aa-958e-96920024c6e5	224	The Layar Designer Villa & Spa Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	30	1	2013-01-31	Seminyak, Jl. Pangkung Sari No.10 X, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-08	Retraining	08/08/2025	Retraining
0a3c5b3a-2127-4a13-bf79-add871bd935f	933	Veranda Hotel @Pakubuwono	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	184	2	2023-02-01	Jl. Kyai Maja No.63, RT.6/RW.2, Kramat Pela, Kec. Kby. Baru, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12130	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-10-07	Retraining	07/10/2025	Retraining
48d5e62b-dcd1-4be6-b4a1-f11e471e6bbc	940	WIKA Realty	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	2023-01-16	\N	\N	\N	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	8bca21b7-bb1b-4581-9934-5c2aeb49783a	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
59cc3155-c59b-41d1-9687-a3c129f2d7c7	846	The Zuri Hotel Baturaja	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	117	5	2020-11-18	Jl. DR. Sutomo No.88, Sukajadi, Kec. Baturaja Timur, Kabupaten Ogan Komering Ulu, Sumatera Selatan 32126	Sumatera Selatan	Kabupaten Ogan Komering Ulu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-09-24	Maintenance	24/09/2025	Maintenance
7c8a94a8-2f12-459c-b636-71ea841d0b71	626	Sekolah Perhotelan Panghegar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	c5443aff-0d00-4df3-aad8-0d130850ee76	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
8e32bc52-6eca-417c-9604-9b9e4b42dfe2	1041	PT. Sarana Prima Budaya Raga	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	JL Spasawahan, No.18, Komplek Javana SPA, Cicurug, Indonesia	\N	\N	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c1e3d369-277a-49f2-b8a5-7623da5865b6	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	\N	\N	\N	\N
9bccc8a6-9d94-4854-951f-82a9e2348dd2	107	Grand City Convention Center Resto Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	4	\N	2015-04-01	Jl. Walikota Mustajab No.1, Ketabang, Kec. Genteng, Kota Surabaya, Jawa Timur 60272	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2015-03-29	Maintenance	29/03/2015	Maintenance
c911aa0d-60c8-4ad5-9308-8605a86bab6f	1021	Loccal Collection Hotel - Labuan Bajo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	96	5	2025-01-01	Labuan Bajo, Kec. Komodo, Kabupaten Manggarai Barat, Nusa Tenggara Tim.	Nusa Tenggara Timur	Kabupaten Manggarai Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-03-07	Implementation	23/05/2025	On Line Training
be3322fd-7f14-457f-95bf-eef54f694988	277	Dewarna Sutoyo Hotel Malang (Ollino Garden 2)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	73	3	2012-12-22	Jl. Letjen Sutoyo No.22, Rampal Celaket, Kec. Klojen, Kota Malang, Jawa Timur 65141	Jawa Timur	Kota Malang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	44afd187-51f4-4801-860b-5ccdbe8f9a18	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2013-02-05	Implementation	13/11/2024	On Line Training
be58e6f1-8cf5-49f0-90a8-7282d6d199ee	1015	Balai Pelatihan Vokasi & Produktivitas Banyuwangi	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	21	2	2024-10-21	Dusun Krajan, Kedungrejo, Kec. Muncar, Kabupaten Banyuwangi, Jawa Timur 68472	Jawa Timur	Kabupaten Banyuwangi	dcff7137-e65e-4721-bfa2-577ac260fbeb	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	c5443aff-0d00-4df3-aad8-0d130850ee76	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2024-10-24	Implementation	24/10/2024	Implementation
bffde642-e7d9-480d-b1cb-cab85a93cec2	140	Drego Hotel Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	45	1	\N	Jl. Jenderal Sudirman No. 182, Tengkerang Tengah, Kec. Marpoyan Damai, Kota Pekanbaru, Riau 28128	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2016-11-07	Maintenance	15/10/2020	On Line Training
c05ed79f-4c87-4215-89aa-74c06a82a814	537	Dalton Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	207	5	2015-08-24	Jl. Perintis Kemerdekaan KM 16 RW.2, Pai, Kec. Biringkanaya, Kota Makassar, Sulawesi Selatan 90241 - Indonesia	Sulawesi Selatan	Kota Makassar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:02+00	2026-03-23 11:32:02+00	2025-02-02	Upgrade	26/03/2025	On Line Training
097745fd-c5f2-4433-811e-c447e8535f2b	CNC-PROJ-TINKER-1774422304	Partner Tinker	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-03-25 07:05:04+00	2026-03-25 07:05:04+00	\N	\N	\N	\N
195c2aca-8d2f-4f8d-a085-e69b0d4574a4	CNC-PROJ-TINKER-1774422487	Partner Tinker	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-03-25 07:08:07+00	2026-03-25 07:08:07+00	\N	\N	\N	\N
5cfa9c2b-9954-48da-ae6b-de4ef3207b3f	674	The Royal IDI Hotel Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	75	3	2017-01-01	Jl. Medan Banda Aceh, Seuneubok Bacee, Idi Rayeuk, Kabupaten Aceh Timur, Aceh	Nanggroe Aceh Darussalam	Kabupaten Aceh Timur	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-09-29	Maintenance	29/09/2019	Maintenance
6031bb81-c5a5-43c9-8503-86f5f4a20258	654	UTC Hotel Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	128	6	2016-11-01	Jl. Kelud Raya No.2, Petompon, Kec. Gajahmungkur, Kota Semarang, Jawa Tengah 50237	Jawa Tengah	Kota Semarang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4b85b056-1bd0-4cda-b8e6-b1bd9184d17b	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-11-25	Maintenance	25/11/2019	Maintenance
6093d3ba-226e-4160-aee2-9dd2a2a61b97	799	Zuri Express Banjarmasin	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	95	3	2019-07-22	Jl. A. Yani No.KM.6, RW.No.9, Pemurus Dalam, Kec. Banjarmasin Sel., Kota Banjarmasin, Kalimantan Selatan 70248	Kalimantan Selatan	Kota Banjarmasin	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-09-08	Implementation	08/09/2019	Implementation
618722bc-87b0-4a93-b59c-db96ee29e71f	487	Swiss-BelResidences Kalibata Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	213	8	2015-06-01	Woodland Park, Jl. Raya Kalibata No.22, RT.6/RW.7, Rawajati, Kec. Pancoran, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12740	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-11-05	Upgrade	25/11/2025	Remote Installation
619a2e89-224f-4a3d-b190-2fd8fbd2e871	745	Swiss-BelInn Cibitung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	93	4	2018-02-01	Jl. Raya Teuku Umar No.26, Cibitung, Kec. Cikarang Bar., Kabupaten Bekasi, Jawa Barat 17530	Jawa Barat	Kabupaten Bekasi	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-03-06	Maintenance	06/03/2026	Maintenance
6e320647-ced5-4028-bcf9-a0aaaf397c0f	285	The Falatehan Hotel Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	94	3	2013-02-15	Jl. Falatehan Blok K 09-F, Kebayoran Baru - Jakarta Selatan 12160\nIndonesia	DKI Jakarta	Kota Jakarta Selatan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	36b8a4d6-236a-4d39-b0d1-ada48e2a4e5a	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-10-02	Retraining	02/10/2025	Retraining
74e35bc8-4e88-48c5-b33f-9a13dd03c537	600	Swiss-Belinn Luwuk	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	102	3	2017-05-21	Jl. Kantor DPRD Baru, Maahas, Luwuk, Kabupaten Banggai, Sulawesi Tengah 94711	Sulawesi Tengah	Kabupaten Banggai	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-06-18	Retraining	18/06/2023	Retraining
7a4fdab1-e5c4-4c29-b116-a797348fcc39	1029	Ulaman Eco Luxury Retreat Tabanan - Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	39	6	2025-05-26	Jl. Raya Buwit, Buwit, Kec. Kediri, Kabupaten Tabanan, Bali 82121	Bali	Kabupaten Tabanan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-26	Retraining	26/12/2025	Retraining
7aac8a33-5e7c-4479-8001-996027f5962c	155	Swiss-Belhotel Rainforest Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	163	1	2012-12-13	Jl. Sunset Road No.101, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-01	Upgrade	01/02/2026	Upgrade
809d3cb6-2363-4a48-925c-5cc83b6aae00	132	Wyndham	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	263	\N	2011-11-01	Jl. Basuki Rahmat No.67 - 73, Embong Kaliasin, Kec. Genteng, Kota SBY, Jawa Timur 60271	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2021-10-10	Maintenance	10/10/2021	Maintenance
8492dda9-7508-434c-aa18-ba4cf2433313	959	Wyndham Tamansari Jivva Resort Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	222	3	2023-07-01	Pantai Lepang, Jl. Subak Lepang No.16, Takmung, Kec. Banjarangkan, Kabupaten Klungkung, Bali 80752	Bali	Kabupaten Klungkung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	c4f0c088-78c2-434b-9565-42683a4dbd16	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-30	Maintenance	30/01/2026	Maintenance
43b4dd40-04ad-4cda-a66d-b5f3bb6d2f84	121	The Aliante Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	138	1	2011-03-01	Jl. Aris Munandar No.41-45, Kiduldalem, Kec. Klojen, Kota Malang, Jawa Timur 65119	Jawa Timur	Kota Malang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	44afd187-51f4-4801-860b-5ccdbe8f9a18	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-15	Retraining	15/01/2026	Retraining
856e24e8-9aee-4e24-946e-ba38443649c6	349	Whiz Hotel Cikini Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	133	\N	2014-01-11	Jl. Cikini Raya No.06, RT.13/RW.5, Cikini, Kec. Menteng, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10330	DKI Jakarta	Kota Jakarta Pusat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	726728c9-9b7e-4f73-b253-ed4da52676b9	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-21	Maintenance	21/12/2025	Maintenance
85cbde83-152a-48d4-9667-341774c13986	691	Swiss-BelHotel Pangkalpinang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	146	3	2018-06-10	Jl. Jendral Sudirman No.65, Gedung Nasional, Kec. Taman Sari, Kota Pangkal Pinang, Kepulauan Bangka Belitung 33684	Bangka Belitung	Kota Pangkal Pinang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-01-24	Maintenance	15/01/2026	Remote Installation
8b2adbb7-1ff4-4c8d-982f-eef26fc99a47	56	The Mirah Hotel Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	142	\N	\N	Jl. Pangrango No.9A, Babakan, Kecamatan Bogor Tengah, Kota Bogor, Jawa Barat 16150	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-16	Maintenance	16/11/2025	Maintenance
93d35b84-66e3-48ed-a673-501859f00270	613	Wimarion Hotel Semarang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	62	3	2016-08-31	Jl. Wilis No.2a, Tegalsari, Kec. Candisari, Kota Semarang, Jawa Tengah 50231	Jawa Tengah	Kota Semarang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-10-12	Maintenance	12/10/2024	Maintenance
945594cb-9f30-4f26-868b-b461674e016e	341	Truntum Kuta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	322	5	2013-10-07	Jl. Pantai Kuta No.1, Pande Mas, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-10-27	Maintenance	27/10/2024	Maintenance
956a0b41-0c5b-483a-968d-56cd05cc63c9	405	Zuri Express Mangga Dua Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	124	3	2014-07-07	Jl. Mangga Dua Dalam No.55-56, RT.6/RW.7, Mangga Dua Sel., Kecamatan Sawah Besar, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10730	DKI Jakarta	Kota Jakarta Pusat	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-06-08	Maintenance	08/06/2025	Maintenance
977e974c-db99-401b-a25e-b87b1199ea43	868	The Ocean Beach Hotel Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	87	3	2021-11-19	Jl. Walter Monginsidi No.4 D/E, Belakang Tangsi, Padang Barat, Kota Padang, Sumatera Barat – 25118	Sumatera Barat	Kota Padang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-10-21	Maintenance	19/08/2024	On Line Training
9b3de175-420b-437f-b92f-968806dd285d	768	Swiss-BelResort Dago Heritage Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	161	4	2018-12-08	Jl. Lapangan Golf Dago Atas No.78, Cigadung, Cibeunying Kaler, Kota Bandung, Jawa Barat 40135	Jawa Barat	Kota Bandung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-02	Maintenance	13/01/2026	Remote Installation
9b72b926-0baf-4f68-99bc-de469b9515d8	704	Vinila Villa Nusa Dua Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	12	2	2017-07-01	Jl. Desa Sawangan, Benoa, Kec. Kuta Sel., Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	656620cd-66d8-466b-9dc8-5d49d2a0647e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-01	Retraining	01/08/2025	Retraining
9de8b237-f111-465b-90b6-4d0ccd4250f4	779	Swiss-BelInn Saripetojo Solo	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	137	4	2018-10-25	Jl. Slamet Riyadi No.437, Sondakan, Kec. Laweyan, Kota Surakarta, Jawa Tengah 57147	Jawa Tengah	Kota Surakarta	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-13	Maintenance	13/12/2025	Maintenance
9e38ab00-65dd-49ce-ba41-5ddd0b849318	1058	The Heirloom Hotel - Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	91	10	2026-01-26	Jalan Letjen S. Parman No. 75, Slipi, Palmerah, Jakarta Barat, 11480.	DKI Jakarta	Kota Jakarta Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	Implementation	\N	Implementation
9ff81d7e-1e6f-473e-8623-0b69ef244d4f	740	The Zuri Hotel Palembang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	214	1	2018-05-01	Area Transmart, Jl. Radial No.1371, 26 Ilir, Bukit Kecil, Palembang City, South Sumatra 30135	Sumatera Selatan	Kota Palembang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-08-20	Maintenance	20/08/2019	Maintenance
a0428e0c-30a8-4de2-bc48-8e4a4d464ba5	1030	Zest Hotel - Ambon	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	113	5	2025-06-26	Jl. Imam Bonjol, Kel Ahusen, Kec. Sirimau, Kota Ambon, Maluku 97124	Maluku	Kota Ambon	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-21	Implementation	21/07/2025	Implementation
a47b066f-294a-4865-ae26-52214803feb8	124	Taman Dayu Golf Pasuruan	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	53	0	2011-06-01	Jl. Raya Surabaya - Malang http://no.km/. 48, Bulukandang, Kec. Pandaan, Pasuruan, Jawa Timur 67156	Jawa Timur	Kabupaten Pasuruan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-14	Maintenance	14/12/2025	Maintenance
a75ca943-ef01-45fa-bbe3-fda6d5120f02	204	Villa Damar Bandung (XPress)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	20	1	2012-08-07	Jl. Damar No.7, Pasteur, Kec. Sukajadi, Kota Bandung, Jawa Barat 40161	Jawa Barat	Kota Bandung	\N	1fd30f9f-a081-4709-89d1-17e941c0e2a7	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-21	Retraining	21/11/2025	Retraining
aa77074a-21cb-47ea-bf3c-51341a26603c	733	The Media Hotel & Tower's Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	166	6	2018-01-01	Jl. Gn. Sahari 12, RT.16/RW.3, Gn. Sahari Utara, Kecamatan Sawah Besar, Kota Jakarta Pusat, Daerah Khusus Ibukota Jakarta 10720	DKI Jakarta	Kota Jakarta Pusat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	820da907-4ad2-4998-b3fd-c1f72cd43ba1	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-12-08	Maintenance	04/01/2021	Remote Installation
ac60ab58-fd6e-470b-8041-7d13a0589c13	101	The ALTS Hotel Palembang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	207	1	2010-08-01	Jl. Rajawali No.8, 9 Ilir, Kec. Ilir Timur II, Kota Palembang, Sumatera Selatan 30114	Sumatera Selatan	Kota Palembang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	9fd7de6c-317c-43e0-be51-e50d9088fcf3	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-09-23	Maintenance	09/11/2024	Remote Installation
b05eadd9-f15b-4af0-bf9e-6c68e60a676b	855	Unigraha Hotel Kerinci Riau	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	141	16	2021-01-01	Pangkalan Kerinci Timur Pangkalan Kerinci, Pangkalan Kerinci Kota, Kec. Pelalawan, Kabupaten Pelalawan, Riau 28654	Riau	Kabupaten Pelalawan	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-06-01	Maintenance	01/06/2025	Maintenance
b1a5d31c-ab01-4ab1-a586-a99b550d7e08	1061	The Tribrata Convention Center - Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	4	2026-01-01	Jl. Darmawangsa III No.1, Pulo, Kebayoran Baru, Jakarta Selatan, DKI Jakarta 12160	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-06	Maintenance	06/02/2026	Maintenance
b2447664-45c6-4975-82be-717268a590a6	658	Swiss-BelInn Singkawang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	218	4	2016-12-18	Singkawang Grand Mall Area, Jl. Alianyang, Pasiran, Singkawang Barat, Kota Singkawang, Kalimantan Barat 79123	Kalimantan Barat	Kota Singkawang	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-06-04	Retraining	04/06/2023	Retraining
b63f0903-931c-453c-9e82-9465e7d3292a	686	Verwood Hotel & Serviced Residence Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	\N	2017-03-01	Jl. Raya Kupang Indah, Putat Gede, Kec. Sukomanunggal, Kota SBY, Jawa Timur 60189	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-02-23	Maintenance	23/02/2025	Maintenance
b6511d6f-b42d-47a5-b63f-44a654fec664	456	Truntum Padang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	168	2	2014-10-01	Jl. Gereja No.34, Belakang Tangsi, Kec. Padang Bar., Kota Padang, Sumatera Barat 25118	Sumatera Barat	Kota Padang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	b412cb84-7d39-4125-8d5b-7a0f14fc0504	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-12-08	Maintenance	08/12/2024	Maintenance
7376ef6c-a059-41f8-b670-84fc9874a89b	CNC-PROJ-TINKER-1774422467	Partner Tinker	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-03-25 07:07:47+00	2026-03-25 07:07:47+00	\N	\N	\N	\N
e491b3ff-df87-4abd-824e-2534132bd41d	53	Swiss-Belhotel Maleosan Manado	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	170	\N	2008-10-18	Jalan Jendral Sudirman No.Kav. 85 - 87, Pinaesaan, Wenang, Pinaesaan, Kec. Wenang, Kota Manado, Sulawesi Utara	Sulawesi Utara	Kota Manado	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-07	Maintenance	07/01/2026	Maintenance
e66234a7-26e2-480d-891a-295981083d0c	780	Swiss-BelInn Simatupang Jakarta	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	159	4	2018-10-25	Jl. R.A.Kartini No.32, RT.9/RW.7, Lb. Bulus, Cilandak, Kota Jakarta Selatan, Daerah Khusus Ibukota Jakarta 12440	DKI Jakarta	Kota Jakarta Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-01-22	Retraining	22/01/2026	Retraining
e6fa6c88-9dcd-4143-aeee-d485be0f8962	148	Swiss-BelInn Panakkukang Makassar	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	183	\N	2012-03-11	Jl. Adyaksa Baru No.55, Pandang, Kec. Panakkukang, Kota Makassar, Sulawesi Selatan 90222	Sulawesi Selatan	Kota Makassar	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-12-29	Maintenance	29/12/2024	Maintenance
eade1ed7-93d4-44bd-9018-aed14e38203e	1069	Grand Swiss-Belhotel Harbour Bay - Batam	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	\N	\N	2026-04-28	Jl. Duyung, Sungai Jodoh, Kec. Batu Ampar, Kota Batam, Kepulauan Riau 29453	Kepulauan Riau	Kota Batam	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-27 04:15:41+00	2026-03-27 04:15:41+00	\N	\N	\N	\N
eee4451c-8983-4e48-ac3a-836f72f31b57	1059	Taman Estate - Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	\N	18	3	2025-12-20	Jl. Mertasari, Kerobokan Kelod, Kec. Kuta Utara, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-29	Implementation	29/12/2025	Implementation
efc26821-f3f8-4693-8a23-187f063731cd	919	Tijili Seminyak Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	120	6	2022-10-01	Jl. Drupadi No.9, Seminyak, Kec. Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-07-06	Retraining	06/07/2025	Retraining
f2e83cfd-fc59-4119-9054-b26ef0b34ded	36	Swiss-Belhotel Papua Jayapura	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	154	9	2012-12-31	Pusat Bisnis Jayapura, Jl. Pacific Permai, Bayangkara, Jayapura Utara, Kota Jayapura, Papua 99112	Papua	Kota Jayapura	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-06-18	Maintenance	15/12/2025	Remote Installation
f4f13010-8e28-43fc-808e-39434b6ebae6	362	VEGA Gading Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	145	5	2013-11-07	Vega Center, Jalan CBD Barat Jl. Boulevard Raya Gading Serpong No.Kav 1, Pakulonan Barat, Kecamatan Kelapa Dua, Kabupaten Tangerang, Banten 15810	Banten	Kabupaten Tangerang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	179386d3-3e8b-4aeb-9ddd-a6be7b9530c0	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2021-08-21	Retraining	06/08/2025	Others
f845cfe9-2d07-4c7d-8563-69b938edadf6	486	Swiss-Belinn Kemayoran	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	157	7	2014-12-01	Complex Springhill J. Benyamin Suaeb Ruas D7, Jl. Semeru Vl, RW.10, Pademangan Tim., Kec. Pademangan, Kota Jkt Utara, Daerah Khusus Ibukota Jakarta 14410	DKI Jakarta	Jakarta Barat	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-05-23	Retraining	23/10/2025	Remote Installation
fc6695c1-8361-48e1-85f6-0d80008304d9	308	Swiss-Belinn Manyar Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	144	3	2013-12-06	Jl. Manyar Kertoarjo No.100, Manyar Sabrangan, Kec. Mulyorejo, Kota SBY, Jawa Timur 60231	Jawa Timur	Kota Surabaya	f85f20a6-40e9-4ae5-bfd5-c4643bae806f	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-01-16	Maintenance	16/01/2025	Remote Installation
fcec736f-2a01-4091-b56e-4dcc2e76243c	636	Veranda Serviced Residence@Puri	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	\N	\N	2018-05-15	Jl. Pesanggrahan No.28, RT.003/RW.009, Kembangan Selatan\nKembangan, Kota Jakarta Barat	DKI Jakarta	Kota Jakarta Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-03-24	Maintenance	28/11/2025	Remote Installation
fd2443c4-c606-400f-b513-08bd28f5d107	396	The Jineng Villas Bali	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	16	\N	2014-01-04	Jl. Nakula Gg. Baik-Baik No.9, Seminyak, Kuta, Kabupaten Badung, Bali 80361	Bali	Kabupaten Badung	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	81d913d6-4da4-4d19-b0fd-c3d3cfedc02b	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	\N	\N	\N	\N
fdd9589f-bad0-4303-a76a-4291e6e13189	781	Swiss-Belhotel Serpong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	107	6	2019-04-25	Jl. Lkr. Tim., Rw. Mekar Jaya, Kec. Serpong, Kota Tangerang Selatan, Banten 15310	Banten	Kota Tangerang Selatan	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-01-22	Retraining	22/01/2025	Retraining
ffab7acf-09b1-4046-9f4c-45a4ccda977e	615	The Rinra Makassar Hotel	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	176	5	2016-07-20	Jl. Metro Tj. Bunga No.2, Panambungan, Kec. Mariso, Kota Makassar, Sulawesi Selatan 90112	Sulawesi Selatan	Kota Makassar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	5ae684b3-a3d8-4703-a001-21035b54871c	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-03-04	Upgrade	04/03/2025	Upgrade
b6e1e582-dd33-456e-a13b-19ae30d9884b	849	Swiss-BelInn Bogor	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	132	3	2020-11-16	Jl. Pajajaran Indah V, RT.01/RW.11, Baranangsiang, Kec. Bogor Tim., Kota Bogor, Jawa Barat 16143	Jawa Barat	Kota Bogor	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-29	Retraining	06/01/2026	Others
b90260c6-1bfc-459c-b902-aab8b484b0d6	981	Training Center Kristal Hotel - Kupang	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	139	3	2023-12-29	Jl. Timor Raya No.59, Pasir Panjang, Kec. Kota Lama, Kota Kupang, Nusa Tenggara Tim. 85228	Nusa Tenggara Timur	Kota Kupang	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-01-01	Implementation	01/01/2024	Implementation
ba39d33a-c952-4cf7-88af-9135afacf946	85	Swiss-Belhotel Kendari	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	139	\N	2010-04-19	Jl. Edi Sabara By Pass No.88, Lahundape, Kec. Kendari Bar., Kota Kendari, Sulawesi Tenggara 93121	Sulawesi Tenggara	Kota Kendari	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-07-19	Maintenance	19/07/2022	Maintenance
c604b608-6fd1-4269-a6ec-dbbfa004c862	1037	Trimulia Hotel - Sihanoukville Cambodia	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	136	6	2025-09-26	Trimulia Hotel, 801 Phum2, Sangkat 2, Khan Mittapheap, Sihanoukville, Cambodia	Cambodia	Sihanoukville	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-11-08	Implementation	08/11/2025	Implementation
c76240f0-55cd-4a35-a781-b5b5dd087be7	429	Swiss-Belhotel Sorong	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	127	8	2014-08-18	Jl. Jend. Sudirman, Malawei, Kecamatan Sorong Manoi, Kota Sorong, Papua Barat Daya 98412	Papua Barat Daya	Kota Sorong	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2019-02-16	Maintenance	30/04/2025	On Line Training
cdc3db1f-8270-4daa-8fe0-b0e05c0aba01	545	Swiss-Belinn Tunjungan Surabaya	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	190	3	2016-01-04	Tunjungan St No.101, Embong Kaliasin, Genteng, Surabaya City, East Java 60271	Jawa Timur	Kota Surabaya	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-21	Maintenance	09/01/2026	Remote Installation
cf7cc471-3af6-4447-af10-66bc17dc2e39	179	Zuri Express Pelangi Pekanbaru	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	57	1	2011-01-01	Jl. Gatot Subroto No.39B, Kota Tinggi, Kec. Pekanbaru Kota, Kota Pekanbaru, Riau 28112	Riau	Kota Pekanbaru	\N	d0cf407a-7618-4450-b798-046ca14576d4	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2023-01-11	Upgrade	11/01/2023	Upgrade
d282bf2a-8679-42f3-9450-b36b6226b3a8	186	The NewTon Bandung	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	2	73	1	2012-08-15	Jl. L. L. R.E. Martadinata No.223, Merdeka, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40114	Jawa Barat	Kota Bandung	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	d7fa6284-cd6b-4bad-996e-e5fd20beac3a	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2026-02-22	Maintenance	22/02/2026	Maintenance
d8fb5899-de97-43ff-9c6e-f7b821fbfc18	187	The Singhasari Resort Batu	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	198	6	2012-07-12	Jl. Ir. Soekarno No.120, Beji, Kec. Batu, Kota Batu, Jawa Timur 65236	Jawa Timur	Kota Batu	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	eff96100-ce07-47c1-9365-e90088ee8562	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-09-11	Maintenance	11/09/2025	Maintenance
deb63f15-84d1-4026-a5f8-dbcb6d94cc78	112	The Premiere Pekanbaru by Grand Zuri	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	170	\N	2011-01-01	Jl. Jenderal Sudirman No. 389, Simpang Empat, Kec. Pekanbaru Kota, Kota Pekanbaru, Riau 28121	Riau	Kota Pekanbaru	\N	3f10844d-0a49-4a6e-a2b9-7f41ba1f7112	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	cf69fe67-ee71-437f-b8b6-d9017e93b10e	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-08-06	Maintenance	06/08/2025	Maintenance
e03d5a02-4af5-41ef-b3ed-fa8da2ccd2bd	145	Swiss-Belhotel Merauke	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	118	\N	2012-03-02	Jl. Raya Mandala No.53, Bambu Pemali, Kec. Merauke, Kabupaten Merauke, Papua 99616	Papua	Kabupaten Merauke	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	4523b31a-174a-4d40-aee8-02d12cc97824	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2022-11-28	Upgrade	28/11/2022	Upgrade
e1177939-436a-4a6a-b33f-a58fc8e40a51	730	The Chandi Boutique & Spa Lombok (Living)	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	4	16	4	2018-05-01	Jl. Raya Senggigi No.KM.5, Senggigi, Kec. Batu Layar, Kabupaten Lombok Barat, Nusa Tenggara Bar. 83355	Nusa Tenggara Barat	Kabupaten Lombok Barat	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	1c0e57d6-6695-41b8-8678-cf44bef057d0	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2025-12-01	Maintenance	01/12/2025	Maintenance
e15e8a04-f1ef-4793-ab26-72b59efcdb4c	414	The Meru Sanur	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	5	457	8	2014-05-13	Jl. Hang Tuah, Sanur Kaja, Kec. Denpasar Sel., Kota Denpasar, Bali 80227	Bali	Kota Denpasar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	6a1269c4-3df7-4e2e-a787-32f82c0c46d8	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-07-19	Maintenance	23/07/2025	Remote Installation
e1b93b24-ecba-47f9-a157-963f1ba13a46	68	The Pade Hotel Aceh	eab1c9f0-d34a-4d33-865f-e3bdf4e07338	3	65	1	\N	Jalan Soekarno - Hatta No. 1, Daruy Kameu, Darul Imarah, Tingkeum, Darul Imarah, Kabupaten Aceh Besar, Aceh 23231	Nanggroe Aceh Darussalam	Kabupaten Aceh Besar	\N	942eb834-f99f-43e8-ab0a-9eb6eaa14a58	2a1f1081-f13f-4c22-9d9c-f11edf1276b4	\N	2026-03-23 11:32:03+00	2026-03-23 11:32:03+00	2024-08-12	Upgrade	17/09/2024	Retraining
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.permissions (id, key, description, created_at, updated_at) FROM stdin;
7edd931a-fae0-4be3-a9c8-0dac835330a7	arrangements.pickup.approve	Approve arrangement pickup	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
be6e900a-ba95-46dd-b885-264ec424665b	arrangements.pickup.override_cancel	Override cancel approved pickup	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
ead3ca99-bccd-43da-b537-cfed25d095d8	users.view	View users list	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
230038f3-6748-4891-a6d5-1e6fda03481b	users.create	Create new users	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
7a4d4b97-e0e0-4595-9206-4bbead580bc1	users.edit	Edit existing users	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
7f63bbd4-9455-4bc4-86d8-bfcfc5001689	users.delete	Delete users	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
7657e7ff-e9bd-4500-ad9b-2c0a7333339f	roles.view	View roles and permissions	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
d441f6b0-47dc-4056-b0d9-3b7167f0086f	roles.edit	Manage roles and permissions	2026-04-14 07:56:54.779341+00	2026-04-14 07:56:54.779341+00
8957b5c9-1361-460c-8e74-ac6dba24b5f6	partners.view	View partners list	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
db226a2d-726a-427f-b9fd-a0101b397e4c	partners.create	Create new partners	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
f9c45862-c79e-4445-b677-404069877920	partners.edit	Edit existing partners	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
03b28f31-2a7c-4d1f-b9c8-f74af8314bc8	partners.delete	Delete partners	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
7711f43f-fea4-4b9d-b3b1-31e1edf90154	projects.view	View projects list	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
65bc2290-736e-411e-86ff-ec5954f3aa25	projects.create	Create new projects	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
9f46029e-7e33-458c-add4-0e2346495c24	projects.edit	Edit existing projects	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
293a4993-578d-4d5c-8e02-de2887e39478	projects.delete	Delete projects	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
0464f7d7-ed8b-486c-a17c-bad405f178aa	time_boxings.view	View time boxings	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
2a3649ac-5a4a-40b0-be79-639747c02c8f	time_boxings.create	Create time boxings	2026-04-14 07:58:20.098425+00	2026-04-14 07:58:20.098425+00
\.


--
-- Data for Name: project_pic_assignments; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.project_pic_assignments (id, project_id, pic_user_id, start_date, end_date, assignment_id, status_id, release_state_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.projects (id, partner_id, cnc_id, name, type_id, status_id, start_date, end_date, spreadsheet_id, spreadsheet_url, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.role_permissions (role_id, permission_id) FROM stdin;
bad66a1d-a1c7-492c-be3a-d4819055db9a	7edd931a-fae0-4be3-a9c8-0dac835330a7
bad66a1d-a1c7-492c-be3a-d4819055db9a	be6e900a-ba95-46dd-b885-264ec424665b
3c6fd8e9-45db-4489-ad9a-f9e9eb5eaf18	7edd931a-fae0-4be3-a9c8-0dac835330a7
bad66a1d-a1c7-492c-be3a-d4819055db9a	ead3ca99-bccd-43da-b537-cfed25d095d8
bad66a1d-a1c7-492c-be3a-d4819055db9a	230038f3-6748-4891-a6d5-1e6fda03481b
bad66a1d-a1c7-492c-be3a-d4819055db9a	7a4d4b97-e0e0-4595-9206-4bbead580bc1
bad66a1d-a1c7-492c-be3a-d4819055db9a	7f63bbd4-9455-4bc4-86d8-bfcfc5001689
bad66a1d-a1c7-492c-be3a-d4819055db9a	7657e7ff-e9bd-4500-ad9b-2c0a7333339f
bad66a1d-a1c7-492c-be3a-d4819055db9a	d441f6b0-47dc-4056-b0d9-3b7167f0086f
bad66a1d-a1c7-492c-be3a-d4819055db9a	8957b5c9-1361-460c-8e74-ac6dba24b5f6
bad66a1d-a1c7-492c-be3a-d4819055db9a	db226a2d-726a-427f-b9fd-a0101b397e4c
bad66a1d-a1c7-492c-be3a-d4819055db9a	f9c45862-c79e-4445-b677-404069877920
bad66a1d-a1c7-492c-be3a-d4819055db9a	03b28f31-2a7c-4d1f-b9c8-f74af8314bc8
bad66a1d-a1c7-492c-be3a-d4819055db9a	7711f43f-fea4-4b9d-b3b1-31e1edf90154
bad66a1d-a1c7-492c-be3a-d4819055db9a	65bc2290-736e-411e-86ff-ec5954f3aa25
bad66a1d-a1c7-492c-be3a-d4819055db9a	9f46029e-7e33-458c-add4-0e2346495c24
bad66a1d-a1c7-492c-be3a-d4819055db9a	293a4993-578d-4d5c-8e02-de2887e39478
bad66a1d-a1c7-492c-be3a-d4819055db9a	0464f7d7-ed8b-486c-a17c-bad405f178aa
bad66a1d-a1c7-492c-be3a-d4819055db9a	2a3649ac-5a4a-40b0-be79-639747c02c8f
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.roles (id, name, created_at, updated_at) FROM stdin;
bad66a1d-a1c7-492c-be3a-d4819055db9a	Administrator	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
3c6fd8e9-45db-4489-ad9a-f9e9eb5eaf18	Admin Officer	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
ad5aef4e-7c3d-43ae-bf67-6772e62648e1	Management	2026-04-11 19:08:09.941255+00	2026-04-11 19:08:09.941255+00
4a4095a3-fdbd-4914-aae8-250585c598c5	User	2026-04-14 09:30:24.63278+00	2026-04-14 09:30:24.63278+00
05639d9b-5775-44bd-8a08-7a110a44dc34	super-admin	2026-04-14 09:30:24.63278+00	2026-04-14 09:30:24.63278+00
\.


--
-- Data for Name: time_boxings; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.time_boxings (id, no, information_date, type_id, priority_id, status_id, user_id, partner_id, project_id, description, action_solution, due_date, completed_at, deleted_at, deleted_by, created_at, updated_at, user_position) FROM stdin;
2d2b9409-32ac-43da-a4b1-c89c0925138c	147	2026-03-31	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	92fb134a-68bc-4409-a20d-8fa3775a720f	eade1ed7-93d4-44bd-9018-aed14e38203e	\N	Prepare Project dan PIC untuk masuk ke project ini.\nRidwan sebagai Leader	\N	2026-03-31	\N	\N	\N	2026-03-31 05:23:21+00	2026-03-31 05:23:21+00	IT
1704ed68-8d6f-4209-ab3e-e7ad8962b2d7	149	2026-03-31	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	92fb134a-68bc-4409-a20d-8fa3775a720f	59e31f95-3412-487c-aa14-60a023fd7953	\N	Pembuatan SPK	1. Akbar to JoyLive Hotel BSD City: 31 Mar 26 - 1 Apr 26 (Training E-Commerce).\n2. Fachri to Swiss-BelInn Cibitung: 1 Apr 26 - 4 Apr 26 (Mentoring EOM).\n3. Indra to Kayumas Seminyak Resort: 6 Apr 26 - 10 Apr 26 (Server Migration).	2026-04-02	\N	\N	\N	2026-03-31 07:23:41+00	2026-03-31 08:23:53+00	Komeng
0f4a959c-e749-4f6c-899b-5a89aeb00ef8	150	2026-03-31	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	92fb134a-68bc-4409-a20d-8fa3775a720f	55b1885d-9907-4f05-9d34-0c05fe36746c	\N	Prepare PIC untuk nemenin Pak Den meting pembahsan program terbaru Power Pro, kemungkinan besar akan upgrade pada hari Rabu, 15 April 2026 jam 10.00 WIB.	\N	2026-04-07	\N	\N	\N	2026-03-31 09:59:37+00	2026-03-31 09:59:37+00	Ibu Dewi | CA
b11bffd3-02ff-4b83-b841-59f4d9772f91	28	2026-01-15	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"Minta penawaran PMS. dengan detail:\n\nPak Azli | Poltekper Medan\nWA: +62 812-6555-6778\nEmail: azliansyah@hotmail.com\n\n* Est Opening: Belum terkonfirmasi.\n* Room: 70.\n* Keylock: Dekkson.\n* PABX: Belum terkonfirmasi.\n* Outlet: 9\n1. resto, \n2. ⁠indoor bar, \n3. ⁠gym, \n4. ⁠pool, \n5. ⁠open sky bar, \n6. ⁠laundry, \n7. ⁠room service,\n8. banquet,⁠\n9. ⁠pastry shop."	Sudah WA ke Pak Den.	2026-01-15	2026-01-29 16:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Bapak Azli
19c164ea-1e45-4dc4-a0bf-10e275112757	1	2026-01-02	ced36e5b-8236-47c1-ad25-1cf4323d0f81	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Fixed Target 2026.	Data yang tertera di CNC / Project / Analisys kendala, data yang muncul disana adalah total dari Team Member, bukan total Project. | Sudah diupate CNC versi 3.4.2601.473 oleh MJ.	2026-01-02	2026-01-29 11:39:00+00	\N	\N	2026-03-20 09:18:22+00	2026-03-23 19:28:00+00	Komeng
ba89701b-0b5e-4323-8ea0-1fd5280de8c9	143	2026-03-26	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	59e31f95-3412-487c-aa14-60a023fd7953	\N	Pembuatan SPK	1. Yosa & Andreas at Kiara Ocean Place: 20 Mar 26 - 29 Mar 26 (Extend Implementation).\n2. Jaja to The Vouk Hotel & Suites Nusa Dua Bali: 30 Mar 26 - 12 Apr 26 (Annual Maintenance).\n3. Ridwan to Plan B Padang (XPress): 30 Mar 26 - 5 Apr 26 (Annual Maintenance & Refresh Training). \n4. Yosa & Andreas to Kiara Beachtown: 30 Mar 26 - 28 May 26 (Implementation Cloud Full Version).\n5. Robi to Grand Maleo Hotel & Convention Mamuju: 1 Apr 26 - 7 Apr 26 (Annual Maintenance).\n6. Apip to BBC Hotel Lampung: 12 Apr 26 - 19 Apr 26 (Refresh Traininig).	2026-03-30	2026-03-31 07:05:10+00	\N	\N	2026-03-26 07:57:24+00	2026-03-31 07:05:10+00	Komeng
e0d56f91-3841-4734-a3b7-7b2df388523d	26	2026-01-13	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Info request pergantian module dari yang sebelumnya.	\N	2026-01-29	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Bapak Christ
1568bbda-26ee-4abe-9bb9-24481224b87f	30	2026-01-15	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat email informasi penyerahan BA saat project berubah status menjadi "Document".	\N	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
4e449578-c601-41c0-b0c1-0a5cb14894eb	145	2026-03-27	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	eade1ed7-93d4-44bd-9018-aed14e38203e	\N	Prepare Grand Swissbel Batam\n- Informasi dari Ridwan opening 28 April 26.	\N	2026-03-27	\N	\N	\N	2026-03-27 04:05:08+00	2026-03-27 04:16:03+00	Bapak Wahyu | IT
346b2850-2405-4c02-9ede-7f217486b02b	34	2026-01-19	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	20cc56c1-ebd8-42bf-b331-d713bdba3f04	\N	Prepare PIC untuk Refresh Training hari Selasa, 3 Februari 2026.	Kordinasi dengan Indra akan arrange Adi.	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Andika | IT
4c6ac3ed-590d-4948-bba4-e27459732221	35	2026-01-23	4fe4b040-17c0-4763-94aa-4764c69bf2da	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	466f5cb2-0e61-4e2f-8271-adf43c4c67d8	\N	Prepare PIC untuk meeting membahas kendala double booking tiket #134993.	Sudah WA ke Imam untuk arrange PIC dan forward email dari Pak Alvin | IT.	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Alvin | IT
62a2a877-6951-4385-b4bd-51d466e0e5d1	41	2026-01-23	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Pastiken agenda meeting dengan SBI terlaksana dengan baik dan juga issue CM bisa teratasi dalam kurun waktu 26 Jan 26 - 30 Jan 26.	\N	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Aris
cd92f616-fd9b-4df7-8fab-eb4524eb1abc	43	2026-01-27	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	9b3de175-420b-437f-b92f-968806dd285d	\N	Konfirmasi Yosa melakukan kunjungan pada 18 Mei 2026.	\N	2026-05-04	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Ridwan | IT
8820491c-0a18-4ec4-b41e-749a02780408	42	2026-01-26	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	SPK periode	26 Jan 261. Ridwan at Aerotel Smile Hotel Makassar: 26 Jan 26 - 01 Feb 26 (Extend Maintenance).*2. Hasbi to JHL Jeep Station Indonesia Resort (JSI): 2 Feb 26 - 8 Feb 26 (Annual Maintenance).*3. Fachri to Batiqa Hotel Cirebon: 2 Feb 26 - 8 Feb 26 (Refresh Training).\n\n27 Jan 26\n1. Vincent to Wyndham Tamansari Jivva Resort Bali: 29 Jan 26 - 30 Jan 26 (POS Issue & Retraining).\n2. Sodik to Dafam Hotel Cilacap (Owned): 2 Feb 26 - 8 Feb 26 (Annual Maintenance).\n3. Jaja & Mamat to Maha Resort Party -Bali: 2 Feb 26 - 8 Mar 26 (Continue Implementation Cloud Full Version).\n4. Ichwan to The Tribrata Convention Center - Jakarta: 2 Feb 26 - 6 Feb 26 (Mentoring EOM Consolidation).\n5. Ridwan to Bumi Surabaya City Resort: 2 Feb 26 - 8 Feb 26 (Annual Maintenance).\n6. Fachri to Batiqa Hotel Cirebon: 9 Feb 26 - 15 Feb 26 (Refresh Training).\n7. Danang to JoyLive Hotel BSD City: 2 Feb 26 - 7 Feb 26 (Refresh Training & Scan BF POS).\n\n28 Jan 26.\n1.Vincent to Sol Beach House Benoa Bali: 4 Feb 26 - 8 Feb 26 (Refresh Training).	2026-01-30	2026-02-02 11:59:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
30ae6ffd-415d-4dcc-9857-517b25489daf	67	2026-02-09	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Prepare pengganti Dhani tanggal 15 Feb 26 karena akan masuk project ke D’Prima Yogyakarta	Konfirmasi ke Prad apakah ada extend lagi di Morazen Hotel Surabaya. | Prad extend karena sedang standarisasi laporan. | Jadi challenge Ridho agar bisa masuk sendiri dengan gantinya mendapatkan EO.	2026-02-09	2026-02-18 19:32:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
311e04a8-da00-42c8-a4f3-00f3fb9545ad	139	2026-03-24	8df1e174-6803-4772-8d55-d0158eedd8c8	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	59e31f95-3412-487c-aa14-60a023fd7953	\N	Prepare tiket pesawat Indra & Vincent to Bali tanggal 25 Mar 26	Sudah dicarikan tiket pesawat dengan detail:\n1. Vincent to Bali tanggal 25 Mar 26.\n2. Indra to Bali tanggal 30 Apr 26.	2026-03-24	2026-03-31 07:20:00+00	\N	\N	2026-03-24 03:21:04+00	2026-03-31 07:20:00+00	Komeng
127b8411-5a52-4eaf-a7ca-42e11779d9d8	148	2026-03-31	64537827-c8db-41cc-a854-c0e3d0641928	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	1d6ab38b-d853-4994-9c86-254f5b880ed7	\N	Prepare Project dan PIC untuk Training online pada hari Rabu, 1 April 2026.	31 Mar 26\n* Project ID 5115\nArrange Rama	2026-03-31	2026-03-31 07:39:29+00	\N	\N	2026-03-31 05:24:28+00	2026-03-31 07:39:29+00	Bapak Steel Punuh | IT Corporate
ba4df39e-9f8e-4616-a310-3edf2589f41a	142	2026-03-25	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	8a021f3c-f995-48f2-87c9-c7df98c9aa0b	\N	Prepare Project dan PIC untuk training E-Commerce pada 31 Mar 26 - 1 Apr 26\nArrange Akbar.	Arrange Rama.	2026-03-26	2026-03-31 07:20:20+00	\N	\N	2026-03-25 11:13:22+00	2026-03-31 07:20:20+00	Bapak Irianto | CA
aad4ec3d-15c4-4c3e-b3bc-7732fb070602	44	2026-01-29	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"Buat Weblink agar lebih rapih setelah meeting menggunakan Plaud Note, contoh yang sudah ada seperti dibawah ini (original dari Plaud Note).\n\nhttps://web.plaud.ai/s/pub_2bf830fb-3af3-4cac-b1cb-dbc328bd9fda::FpW9iMHuXBKSR9l7-FZ3QAgxx0tWnIMjMTswNBRw7xWHQSmE6I_UnB12Mce42snx21NDBJMUxGlTbUwC"	\N	2026-02-09	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
96f0c1b7-d7d7-4954-8f10-9704f63b6def	5	2026-01-05	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	1f155836-c001-404d-9dd3-4f0edc2b39b0	\N	Prepare PIC Refresh Training ke Karawang 6,7,8 Jan 26.	Arrange Aris.	2026-01-05	2026-01-29 15:04:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Warman | IT
e93b1186-c7c5-418f-9d0a-bf6759b8cf6d	94	2026-02-21	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Permintaan Penawaran Software	Opening Hotel\nBoutique Hotel area Bukit Tinggi\nRoom: 17\nOutlet: 2\nKeylock: Belum diketahui\nPABX: Belum diketahui\nPIC: Pak Robi | IT | Grand Inna Padang\nWA: +62 812-7603-8299\nEmail: robbywira@outlook.com\n\nSudah di WA ke Pak Denny.	2026-02-23	2026-02-23 19:38:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Bapak Robi
0915178d-eeaa-48d8-9b43-6b9d3d062a78	107	2026-02-27	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	\N	\N	\N	\N	\N	\N	2026-03-23 19:41:49+00	2026-03-23 19:41:49+00	\N
e47b8a23-0574-4a52-980d-596699f3ae16	109	2026-03-02	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Create OpenClaw for Office	Fase 1: Pembuatan\n2 Feb 26\nOpenClaw yang sekarang sudah terbuat di VPS Sumopod dan di Laptop.\n\nFase 2: Pengetesan\n2-3 Feb 26\n1. Dewi AI Assistant (VPS) \nAI yang ada di Sumopod, adapun kendalanya adalah:\n  • Respon yang lama\n  • Untuk melihat data pada spreadsheet yang sudah dishare sangat tidak kompeten, walaupun menggunakan model yang bagus.\n\n2. Power Claw (Local)\n\n4 Feb 26\nProblem Solving\n1. Dewi AI Assistant (VPS) \n  • Coba dengan server tetap di Sumopod, tapi mengganti API Key langsung dari Openrouter\n\n\nFase 3: Result	2026-03-06	\N	\N	\N	2026-03-23 19:41:49+00	2026-03-23 19:41:49+00	\N
2ac105a7-6aae-43c6-b14a-ba7f71fcad55	2	2026-01-02	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Preview Green Plan sampai tahun 2030.	\N	2026-01-06	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
5f806190-186f-40d1-813a-f5d39b2af6b3	3	2026-01-02	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Publish Schedule Competence Academia Power Pro.	\N	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
26d4676f-297b-4e8e-9f1d-a48aaad6b7a4	4	2026-01-02	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	d1ec1039-9568-4fc1-98c7-b7056b7b0968	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	1. Yang dibutuhkan dukungan dari Management untuk menjalankan OKR 2026.\n2. Tambahkan Project Type di CNCMaintenance Seamless."	1. Yang dibutuhkan dukungan dari Management untuk menjalankan OKR 2026:\n1. Status PIC yang akan melakukan assessment karena tidak bisa menjalankan project, dengan detail:\n1.1. OKR 1: Assessor: Danang, Mamat & Rama.\n1.2.OKR 2: Ilham & Apri.\n\n2. Tambahkan Project Type di CNC: \n  • Maintenance Seamless\n  • Meeting Online\n  • Cut Off	\N	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
5b0e9b43-bb4e-44b7-a953-95a37188a4e1	110	2026-03-02	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update SPK	02 Feb 26\n1. Ridwan at Samara Resort Hotel Batu Malang: 1 Mar 26 - 8 Mar 26 (Extend: Maintenance System).\n2. Aris at Dewarna Bojonegoro Hotel & Convention: 2 Mar 26 - 8 Mar 26 (Extend: Mentoring EOM).\n3. Sodik at GranDhika Pemuda Semarang: 2 Mar 26 - 4 Mar 26 (Extend: Maintenance System).\n4. Mamat at GDAS Health & Wellness Ubud: 2 Mar 26 (Extend: Review Data).\n5. Mamat to Swiss-BelExpress Kuta Bali (Galesong): 3 Mar 26 - 6 Mar 26 (Annual Maintenance).\n6. Prad at Hotel Lamora Sagan - Yogyakarta: 5 Mar 26 - 7 Mar 26 (Extend: Refresh Training).\n7. Ridwan to Yunna Hotel Lampung: 10 Mar 26 - 18 Mar 26 (Annual Maintenance).\n\n03 Feb 26\n1. Apri at Moriah Hills Hotel - Gading Serpong: 12 Jan 26 - 13 Jan 26 (Extend: Overview Back Office Module).\n2. Yosa & Andreas to Kiara Beach Front: 10 Mar 26 - 8 May 26 (Implementation Cloud Full Version).\n\n2. Fachri to Swiss-BelInn Cibitung: 4 Mar 26 - 6 Mar 26 (Mentoring EOM).\n\n4 Feb 26\n1. Widi at Bogor Valley Hotel-Bogor: 4 Feb 26 - 6 Feb 26 (Mentoring EOM)	2026-03-06	2026-03-06 09:33:00+00	\N	\N	2026-03-23 19:41:49+00	2026-03-23 19:41:49+00	Komeng
0a9afa4d-b955-4ea8-b614-c76dcf2e9784	111	2026-03-03	3980a337-dc61-4d8e-961d-a80b8e615a7b	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Permintaan Penawaran Softrware	The valmont Bukittinggi\nRoom: 92\nOutlet: 5\nKeylock: No Vendor (beli dari luar negri)\nPABX: Belum ada informasi\nEstimasi Opening: 21 Maret 2025\nContact:\nPak Doni\nWA: +62 813-6307-5878\nEmail: mailto:recruitmentvalmont@gmail.com\n\nSudah kirim via WA ke Pak Denny.	2026-03-03	2026-03-04 08:20:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Bapak Doni
57e746b0-ab97-4fc4-bc50-ae7a782705c4	10	2026-01-05	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Petakan pada Partners untuk Area dan Sub Area	\N	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
a5a232f2-cd8e-44fc-b1f5-94fba6939813	137	2026-03-17	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	\N	\N	\N	\N	\N	\N	2026-03-23 19:41:49+00	2026-03-23 19:41:49+00	\N
7874b15a-0b44-44ca-be6f-18fc746d8c78	138	2026-03-17	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Dhika Req masuk malam tanggal 12 April 25	Perlu dicek lebih detail.	\N	\N	\N	\N	2026-03-23 19:41:49+00	2026-03-23 20:07:59+00	\N
6480028f-1baa-4684-8582-652433e198f2	16	2026-01-06	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"Kebutuhan Update CNC:\n1. Project Type:\n* Zoom Meeting\n* Maintenance Seamless"	\N	2026-01-29	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	MJ
84d6ce70-815b-4260-b89b-757a82b4fe91	20	2026-01-07	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	1d82cc09-f1d7-41f2-acfc-43dd03eac5a7	\N	Prepare PIC untuk project hotel baru di Veranda	Konfirmasi lagi dengan Pak Den.	2026-01-30	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Pak Den
6c5a7e79-4957-48bf-ab23-6b813ba7d2ab	144	2026-03-27	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat agar AI Assistant membuat summary dari percakapan via telpon\n- Setelah itu langsung otomatis buat Time Boxing.	\N	\N	\N	\N	\N	2026-03-27 04:03:34+00	2026-03-27 04:10:02+00	Komeng
689a6d4d-84d7-491e-a3a3-584bfa4aa075	49	2026-02-02	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buatkan materi per Department or Jobdesk, contoh: Revenue Management, IT Department.	\N	2026-02-28	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
a69be8d3-c197-4d04-8dc0-fc37989144c0	136	2026-03-16	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update SPK	1. Sahrul to Dafam Enkadeli Thamrin Jakarta: 16 Mar 26 - 18 Mar 26 (Migration CM from STAAH to D-EDGE).\n2. Danang at Novena Hotel Bandung: 16 Mar 26 - 18 Mar 26 (Extend Maintenance).	2026-03-18	2026-03-31 07:24:36+00	\N	\N	2026-03-23 19:25:37+00	2026-03-31 07:24:36+00	Komeng
59327dde-0bf9-4aa9-8ce7-80a2f832f051	24	2026-01-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	b2c0b217-73f9-4439-b72c-fc2c0354382d	\N	Prepare Persiapan untuk merger antara Atria Hotel dan Atria Residence.	sebelumnya request training juga.	2026-01-29	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Fazar | IT
3877ce2a-2252-4a93-a99b-7a0a8e2bd33f	6	2026-01-05	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	43b4dd40-04ad-4cda-a66d-b5f3bb6d2f84	\N	Prepare PIC Refresh Training Tanggal 6-12 Jan 26.	Arrange Widi.	2026-01-05	2026-01-29 15:07:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Agus | GM
e4deb1fb-baea-43b2-8f93-f97c045c6af0	8	2026-01-05	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat n8n otomatis kirim email untuk PMS Activity Report 2026	Sudah dibuatkan di n8n terbaru.	2026-01-07	2026-01-29 15:09:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
3ca5bb82-0c6f-49d1-8dd8-c503e511330d	45	2026-01-31	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat integrasi antara Notion x Tally	Sudah dibuatkan trial integrasi, namun perlu rules yang lebih baik, diantaranya\n1. Buat Generate Link Tally dari Project, lalu setelah diisi akan masuk ke list PHS.	\N	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
a26a7727-dc67-4ba2-ab0f-7953edcb41d7	140	2026-03-24	8df1e174-6803-4772-8d55-d0158eedd8c8	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cek Jobsheet periode Feb 26 - Mar 26	Sudah dilakukan pengecek dengan Rio.	2026-03-24	2026-03-26 09:04:55+00	\N	\N	2026-03-24 03:23:43+00	2026-03-26 09:04:55+00	Komeng
70ddc63c-20ed-45bd-983e-75392f74ec6d	146	2026-03-27	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Project History	\N	\N	\N	\N	\N	2026-03-27 04:17:05+00	2026-03-27 04:17:05+00	Komeng
ee2142d7-6f9c-450c-9299-eb81d11f56d6	141	2026-03-24	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Prepare Mujiono ke Bali tanggal 30 Mar 26	\N	2026-03-26	\N	\N	\N	2026-03-24 06:36:19+00	2026-03-25 11:14:34+00	Komeng
e53a03dd-5dea-4503-8e0d-06212d2f3c08	80	2026-02-11	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Untuk assessment selanjutnya agar peserta menggunakan Zoom Meeting agar bisa capture tampilan laptop peserta.	Perlu disiapkan Tools untuk mengakomodir hal tersebut.	2026-02-16	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
ce5c9bbd-7ea4-4181-9885-c4d60a03573f	81	2026-02-11	c5166ed9-cb08-4495-8138-457ecc03fcd8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Perlu tambahan akses Ilham dan Iam di CNC	Ilham perlu tambahan akses di CNC:\n  1. Akses Customer: Untuk melihat license yang digunakan (sebagai patokan Power Pro Health Score)\n  2. Drive: Untuk melihat backup database yang sudah diupload oleh team setelah project.\n  3. Project: Untuk compare project mana saja yang sudah ada PHS nya atau belum.\n\nIam perlu tambahan akses di CNC\n  1. Update Activity di Project - Activty - (Load Activity, Delete Task, Open, Done)	2026-02-12	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
30cf5e86-7e2d-44a0-a8e3-f10eb2f9e730	86	2026-02-16	07ca6d21-5843-4856-8667-10a2cf3df1f6	d1ec1039-9568-4fc1-98c7-b7056b7b0968	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Sosialisasi BA yang baru dan rules project yang benar.	Rules:\n- Informasi project hanya ke Pak Harly, Pak Den, Bang Ivan (Teknis), Ichsan (Teknis), selebihnya abaikan.	2026-02-20	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
6e77bd2c-00e8-4691-943e-1048d1b67ff2	134	2026-03-11	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	a75ca943-ef01-45fa-bbe3-fda6d5120f02	\N	Request Training tanggal 6-11 April 2026	\N	2026-03-25	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Ibu Fitri | GSA
d6fdf331-3324-43d3-99a5-4fba7ca26a4d	135	2026-03-11	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	014de9a1-0390-45f9-bd65-fe2751190cad	\N	Prepare PIC untuk Maintenance: 30 Mar 26 - 5 Apr 26	\N	2026-03-25	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Ary | Asst IT Manager
71ab7855-1847-4a24-81c9-333bc56238a3	7	2026-01-05	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"1. Ridwan at Swiss-Belhotel Maleosan Manado: 5 Jan 26 - 7 Jan 26 (Extend Review EOY).\n2. Apip at Palm Park Hotel Surabaya: 5 Jan 26 - 11 Jan 26 (Extend Mentoring Update Data (Database Down).\n3. Aris to Swiss-Belinn Karawang: 6 Jan 26 - 8 Jan 26 (Refresh Training).\n4. Widi to The Aliante Hotel: 6 Jan 26 - 12 Jan 26 (Refresh Training)."	Sudah diupdate project dan ttd SPKnya.	2026-01-05	2026-01-29 15:08:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
86eb7812-b385-4f87-9ffc-030361b03a3d	9	2026-01-05	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	d1d04e92-35b2-4716-8343-4079679660ce	\N	Follow up project Kiara Ocean Place & Kiara Beach Front.	Sudah WA ke Pak Jo pada 10.57, namun sampai 14.50 belum ada respon. | Respon jam 15.17 dan akan dikonfirmasi pada hari Selasa, 6 Jan 26. | Terkonfirmasi Projek akan mulai pada 19 Jan 26.	2026-01-05	2026-01-29 15:11:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Jo | FC Corporate
1d004640-e39a-4136-9b1e-08795da6eea7	12	2026-01-05	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	a637b3b0-78b3-4a30-be50-cafbb6852721	\N	Prepare PIC untuk training online Cost Control Module pada hari Senin, 12 Januari 2026 jam 10.00 WIB.	Arrange Sodik.	2026-01-05	2026-01-29 15:31:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Ibu Anom | CA
dbe054e3-c5c4-4a32-83db-04fcacd466f6	13	2026-01-05	c5166ed9-cb08-4495-8138-457ecc03fcd8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Flow kerja Iam diganti agar lebih cepat dan mudah yaitu Iam update semua pada hastag project, jadi request ke MJ agar log masih tersimpan selama 3 tahun.	Untuk Iam sudah sepakat menjalankan mekanisme kerja seperti itu.	2026-01-05	2026-01-29 15:32:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Iam
ef4a053f-9d4a-46b7-a1a9-67fd8eee0301	14	2026-01-05	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Request log pada hastag project masih tersimpan selama 3 tahun.	Sudah diupdate di CNC, jadi akan menyimpan selamanya.	2026-01-05	2026-01-29 15:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	MJ
9228a321-1bab-4f46-87d0-2773323cbabe	15	2026-01-06	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	62b304ee-e439-4b87-a092-0f5d56fed544	\N	Prepare PIC untuk upgrade pada 26 Jan 26 - 8 Feb 26.	Arrange Basir, prepare untuk pickup database untuk dipelajari terlebih dahulu.	2026-01-27	2026-02-23 08:41:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Ibu Ayu | FC
50a1bb55-9394-4d75-8d22-e92a78f5dbc9	17	2026-01-06	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	2c76018a-5087-45c1-a513-8961245c8129	\N	Prepare Project & SPK Ridwan.	Sudah dibuatkan project dan SPK.	2026-01-06	2026-01-29 15:35:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Oky | IT
e03016c6-07b7-4c23-9143-0ab6b8e643db	48	2026-02-01	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	20cc56c1-ebd8-42bf-b331-d713bdba3f04	\N	Konfirmasi Team Bali untuk Training Online pada Selasa, 3 Feb 26	Informasi Indra bisa diagendakan Vincent. | Update via email dari Pak Andika | IT bahwa dipostponed ke tanggal 9-11 Feb 26. | Perlu arrangement dari Jakarta, karena team di Bali sedang masuk project. | Arrange Rama untuk tgl 9 Feb 26.\n\nArrangement Rama dan Ridho pada tanggal 9-11 Feb 26	2026-02-05	2026-03-31 07:32:52+00	\N	\N	2026-03-23 19:25:37+00	2026-03-31 07:32:52+00	Bapak Andika | IT
7da43356-febe-4cdc-9798-bdb510359eff	99	2026-02-26	64537827-c8db-41cc-a854-c0e3d0641928	d1ec1039-9568-4fc1-98c7-b7056b7b0968	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Timeline untuk Noema Gili dengan Opening 1 Juni 2026	• Konfirmasi terlebih dahulu ke Pak Den, jika memang diperbolehkan akan dikirimkan sore ini. \n  • Pak Den sudah approved dan informasi masa implementasi 60 hari.\n  • Sudah kirim via email ke Pak Liverto dan cc Ke Pak Den.	2026-02-26	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Bapak Liverto | IT Corporate
07dabd48-1863-4a9d-a328-4919a66f8044	90	2026-02-19	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	1d82cc09-f1d7-41f2-acfc-43dd03eac5a7	\N	Informasi Kick Off Meeting Marqen Hotel > Veranda bintang 5	Informasi dari Pak Den\n  • Estimasi opening bulan Juli 2026.\n  • Pihak hotel mengadakan agenda kickoff meeting pada hari Jum’at, 27 Feb 26 jam 14.00 WIB.\n  • Perlu kirimkan template setup dan timeline implementasi.\n  • Arrange Danang.\n\nPerlu dibuatkan Timeline dengan estimasi live 1 Juli 2026	2026-02-24	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	\N
f8f76792-4ffb-4f5d-bdd9-b3ef2e1acbf5	93	2026-02-20	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Perlu akses ke Database Customer di Spreadsheet	Karena Database Partner masih proses migrasi dari Spreadsheet to Notion, maka belum bisa, estimasi bisa dilakukan sync pada hari Kamis, 26 Feb 26.	2026-02-26	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Ilham
0308e4bc-2784-4984-a566-16ebf4339078	95	2026-02-23	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	14135078-278e-4e0c-b913-c385b8173908	\N	Request Maintenance 2-7 Mar 26 dengan PIC area Bali	Sudah WA ke Indra untuk kordinasikan project tersebut, namun Indrad tidak available dan menyarankan sesudah lebaran. | Lalu komunikasikan dengan Mamat untuk handle project tersebut dan akan dikonfirmasi pada tanggal 25 Feb 26.	2026-02-23	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Ibu Dewi | CA
0da79d4e-3c39-4281-b15f-a1e727db561c	100	2026-02-26	07ca6d21-5843-4856-8667-10a2cf3df1f6	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Meeting membahas tentang Berita Acara, Schedule Submission & Assessment	1. Berita Acara\n  • Maintenance & Refresh Training\n\n2. Schedule Submission (Periode 21-20):\n2.1. Support Need\n2.1.1. CNC Based (must show CNC)\n2.2. Phase\nPhase 1 (Submission): Tanggal 15-17 every periode.\n  • Jika tidak membuat submission, maka siap incharge ditanggal berapa saja.\nPhase 2 (Reconciliation): Tanggal 18 every periode.\nPhase 3 (Publication): Tanggal 19 every periode.\n2.3. Regulation\n  • Middle: Max 5 every periode.\n  • Duty: Max 6 every periode.\n  • Weekend / Public Holiday: Max 2 every periode.\n\nAssessment Result:	2026-02-27	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
4cfb81ef-3100-44fd-843b-e7376f938c75	102	2026-02-26	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	64520e04-a114-4bc4-acb3-67c067cd41d8	\N	CWS minta konfirmasi upgrade per April 2026	• Pak Dudu sudah ada email ke Pak Den dan ke pms juga.\n  • Sudah WA Pak Den untuk konfirmasi bisa atau tidaknya mulai pada bulan April 2026.	2026-02-26	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Dudu | IT
0dd17051-e85b-427c-8150-4e502b4c92bf	103	2026-02-27	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	bbea96e0-ea1b-4480-8e33-19b874f81bf6	\N	Buat Timeline Project Yosa dan Andreas	Masih menunggu konfirmasi dari Yosa untuk tanggal mulai projeknya.\n\n30 Mar 26\n* Sudah terkonfirmasi via WA, project mulai pada tanggal 30 Mar 26 s/d 28 May 26.	2026-03-09	2026-03-31 07:35:52+00	\N	\N	2026-03-23 19:25:37+00	2026-03-31 07:35:52+00	Pak Jo | FC Corporate
06c6862e-d3c3-4af8-8910-d4c44957528e	91	2026-02-20	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	08f1f66e-0b7c-4dc6-8c96-d8af9eefed0a	\N	Prepare PIC Training Online INV & GL Module tgl 23-24 Feb 26 jam 14.00 WIB	Assign Akbar.	2026-02-20	2026-02-26 15:56:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Wawan | IT
2dc0104f-4a90-4074-8297-bfa78ba71989	18	2026-01-06	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"1. Apri at Moriah Hills Hotel - Gading Serpong: 6 Jan 26 - 9 Jan 26 (Overview Back Office Module).\n2. Ridwan to Swiss-Belhotel Makassar: 8 Jan 26 - 14 Jan 26 (Annual Maintenance)."	Sudah dibuatkan SPK nya.	2026-01-07	2026-01-29 15:36:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
b5656222-6fb0-4e1a-9ffa-46553331045f	19	2026-01-06	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	08f1f66e-0b7c-4dc6-8c96-d8af9eefed0a	\N	Training AR Module: Kamis, 8 Januari 2026 jam 14.00 WIB.	Arrange Aldi.	2026-01-06	2026-01-29 15:36:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Wawan | IT
38424fc4-3357-4e08-9846-93b588be4ad6	21	2026-01-08	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Project Aldi Training Online.	Sudah dibuat, untuk Training Online AR Module Hotel Ciputra Semarang (HCS).	2026-01-09	2026-01-29 16:40:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
885fed5c-7ca1-4f3e-8dbc-815cf4cbe2d2	119	2026-03-09	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cari pengganti Dhani Midde tgl 12-13 Mar 26	\N	2026-03-09	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
e0c80cca-dc96-4a47-a6bf-3ea3146e4da5	122	2026-03-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	f4b8221c-12b2-4828-845a-2b70712d403a	2d21ed5c-acc9-465e-9342-3fad6ef33370	014de9a1-0390-45f9-bd65-fe2751190cad	\N	Respon Email dari Pak Ary perihal request kunjungan tgl 30 Mar - 5 Apr 26	3 Mar 26\nKonfirmasi dari Indra bahwa bisa pada tanggal 6 April 2026.\n\n9 Mar 26\nJadi kirim PIC yang akan incharge di Bali, start tgl 30 Maret 2026.	2026-03-09	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Ary | IT
b4dffef6-1ccb-4c2e-b771-b4a8ccf4661d	123	2026-03-09	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	0046a638-e915-4748-a019-c0e5a85e4e89	\N	Prepare PIC 13-16 Apr 26 untuk Refresh Training	\N	2026-03-16	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Taka | IT
e815f500-cc64-4dbe-877b-fe91fef0f16f	124	2026-03-09	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	08f1f66e-0b7c-4dc6-8c96-d8af9eefed0a	\N	Prepare PIC Training Inventory Module Rabu jam 14.00 WIB	Assign Akbar	2026-03-09	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Wawan | IT
9d03348c-8db6-4d5b-9470-1de8abc19e27	125	2026-03-10	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	bbea96e0-ea1b-4480-8e33-19b874f81bf6	\N	Rencana Project	Secara actual Opening 1 Mei 2026, namun\n1 April 2026 sudah menerima tamu, jadi secara system akan diakui Live System	\N	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	\N
37b7a057-1a91-4d22-a79f-df666a4c372e	127	2026-03-10	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	66471964-8368-4683-90b5-63422bdd9894	\N	Informasi penggunaan Pepperless	10 Mar 26\n  • Perlu arrange PIC untuk Zoom Meeting bahas semuanya, dengan ada license 1 PowerGO.\n  • Sudah diagendakan dengan Pak Novan | IT Zoom meeting pada hari Kamis, 12 Maret 2026.	2026-03-10	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Khadafi | GM
cdfaf49b-2ab3-4b06-af7d-79081a3b847d	128	2026-03-10	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cari Pengganti Middle Apri, karena harus pagi untuk handle Taman Dayu	\N	\N	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Komeng
e3df1b11-8c51-4bb7-956b-36c112cc62d1	31	2026-01-15	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	66471964-8368-4683-90b5-63422bdd9894	\N	Prepare PIC untuk training online AR & GL Module via online jam 10.00 WIB.	Arrange Hasbi.	2026-01-15	2026-01-29 16:49:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Ferrys | Acct
67ec3da6-f3a0-48a3-9b6e-37cbac1cc7b2	22	2026-01-09	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	1. Yosa to Kiara Ocean Place: 12 Jan 26 - 12 Mar 26 (Implementation Cloud Version).	Sudah dibuatkan SPK nya.	2026-01-12	2026-01-29 16:41:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
d5c20a65-3bab-418b-ac2c-829b95a33dbd	23	2026-01-09	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"Buat daily analysis untuk Iam dipublikasikan ke team dengan ketentuan:\n1. Muncul otomatis mana yang telat dan yang ontime"	Sudah dibbuat otomatis, start dari row 101 untuk piC yang ontime dan 131 untuk pic yang telat.	2026-01-12	2026-01-29 16:41:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
7b3a8876-e368-4491-80c4-4b79f9d7007b	25	2026-01-12	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Kirim invitation email untuk proses assessment besok.	Sudah dikirim via email.	2026-01-12	2026-01-29 16:43:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
ffb883cf-69fa-4b77-a29c-2322aed23b29	27	2026-01-14	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"1. Ichwan & Sodik at The Tribrata Convention Center - Jakarta: 13 Jan 26 - 18 Jan 26 (Extend: Validation Data).\n2. Widi at The Aliante Hotel: 13 Jan 26 - 15 Jan 26 (Extend Retraining).\n3. Akbar to Jambuluwuk Thamrin Hotel Jakarta: 15 Jan 26 (Training PowerME).\n4. Akbar & Farhan to The Heirloom Hotel - Jakarta: 19 Jan 26 - 14 Feb 26 (Continue Implementation).\n5. Sodik to Ana Hotel Jakarta: 19 Jan 26 - 25 Jan 26 (Refresh Training)"	Sudah dibuatkan SPK nya.	2026-01-14	2026-01-29 16:44:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
0fb2ecfd-aa3e-434e-b7d2-c996c289e377	29	2026-01-15	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"1. Ichwan & Sodik at The Tribrata Convention Center - Jakarta: 13 Jan 26 - 23 Jan 26 (Extend: Validation Data).\n2. Yosa & Andreas to Kiara Ocean Place: 19 Jan 26 - 19 Mar 26 (Implementation Cloud Version).\n3. Indra & Wahyudi to Swiss-Belhotel Rainforest Bali: 19 Jan 26 - 01 Feb 26 (Upgrade to Cloud Version).\n4. Mulya to Galeri Ciumbuleuit Hotel & Apartment: 19 Jan 26 - 21 Jan 26 (Update Exe for License).\n5. Ridwan to Aerotel Smile Hotel Makassar: 19 Jan 26 - 25 Jan 26 (Annual Maintenance).\n6. Sodik to Ana Hotel Jakarta: 26 Jan 26 - 1 Feb 26 (Refresh Training).\n7. Ridwan at Swiss-Belhotel Makassar: 15 Jan 26 - 18 Jan 26 (Extend Maintenance)."	Sudah dibuatkan project dan SPK nya.	2026-01-15	2026-01-29 16:46:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
1cf5852d-6bf4-432c-b22b-3b367a684ae5	68	2026-02-09	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	9abaa011-65a1-4458-8f2b-c056957f6f9a	\N	Konfirmasi ke Pak Nurman Server dihotel menggunakan On Premise atau On Cloud	Cek data di CNC menggunakan On Premise.	2026-02-09	2026-02-10 17:43:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Nurman | IT
ca879d65-221e-4acd-bb83-865a8aa695c9	129	2026-03-10	ced36e5b-8236-47c1-ad25-1cf4323d0f81	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	59e31f95-3412-487c-aa14-60a023fd7953	\N	Tiket balik team Bali	10 Mar 26\n  1. Indra: Jum’at 13 Maret 2026 ke Surabaya.\n  2. Afip & Jaja: Jum’at 13 Mar 26 ke Jakarta.\n\n\nSudah dicarikan langsung oleh Pak Sampurna.	2026-03-11	2026-03-31 07:24:20+00	\N	\N	2026-03-23 19:25:37+00	2026-03-31 07:24:20+00	Pak Denny
67761e7c-3014-4e9f-928a-8604361d82ef	126	2026-03-10	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	92fb134a-68bc-4409-a20d-8fa3775a720f	bbea96e0-ea1b-4480-8e33-19b874f81bf6	\N	Update perubahan Customer Name untuk kebutuhan license	10 Mar 26\n  • Sekarang namanya Kiara Beach Front, harusnya Kiara Beachtown\n\n  • Sudah info ke group WA Coordinator dan mention koh Rusli.\n\n10 Mar 26\n* Sudah diupdate oleh Pak Denny.	2026-03-10	2026-03-31 07:34:53+00	\N	\N	2026-03-23 19:25:37+00	2026-03-31 07:34:53+00	Komeng
f02be69d-01e8-4303-96b1-0a8e5cf19bc1	11	2026-01-05	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Reply email yang membutuhkan Upgrade bulan Feb 26.	Sudah direply emailnya.	2026-01-05	2026-01-29 15:14:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:41:49+00	Ibu Ayu | FC
751ad45b-e633-499a-a5b3-f61c6980a268	132	2026-03-11	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	453856b8-7c55-49bf-8940-7208ebd2320e	\N	Prepare PIC Refresh Training 20-24 Apr 26	\N	2026-04-06	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Bapak Mujahidin | IT Supervisor
8c9c2495-1c99-48ab-adc5-617658fecca0	133	2026-03-11	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	80738fd0-6419-4aa5-806e-2b51819a9a0f	2d21ed5c-acc9-465e-9342-3fad6ef33370	0046a638-e915-4748-a019-c0e5a85e4e89	\N	Prepare PIC untuk Refresh Training 13-16 Apr 26	Arrange Fachri	2026-04-06	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:25:37+00	Ibu Maria Sita | FAM
ac77097c-1f2b-4e19-b805-b3aa363731fc	85	2026-02-16	07ca6d21-5843-4856-8667-10a2cf3df1f6	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Agendakan sosialisasi PowerRA dari Ichwan	Ichwan sudah siapkan materinya dan akan dilaksanakan pada hari Rabu, 18 Feb 26 jam 16.30 WIB.	2026-02-16	2026-02-18 19:34:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
59f43473-9866-4cf9-af07-dc34ae4fd55b	88	2026-02-18	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	7c9bb617-0077-456d-a84d-62f783674768	\N	Prepare PIC untuk training online Inventory Module (Purchasing & Store) hari Jum’at jam 14.00 WIB	Assign Ridho.	2026-02-18	2026-02-20 14:47:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Manuarang | CA
bd405c9d-05d8-4f0f-ade3-675623720ffd	89	2026-02-18	07ca6d21-5843-4856-8667-10a2cf3df1f6	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Meeting membahas tentang: Rencana Penambahan Fitur Room Checklist di PowerRunner dengan Ichwan dan Ichsan sebagai speaker.	Sudah berjalan dengan baik, adapun MOM dibawah ini\n\nhttps://web.plaud.ai/s/pub_b9f67382-7bd1-4cd2-893a-a317be6dc0a8::R2DRxHFJ26aCQzM2hG-WOzs7WqXZmpcaP4PtNGV3eb_hU_2MyW2a2YAZi1Ern53Hs3YVUObiq8KhoVsC	2026-02-18	2026-02-18 19:28:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
13d67c22-7ef5-4565-b4e8-56845cf245d6	131	2026-03-11	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	2c8453fc-c6dc-469d-a8ca-b0606bc18dba	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update Website Power Schedule	10 Mar 26\n  • Start Build\n\n11 Mar 26\n  • Buat menjadi full agar bisa digunakan juga untuk project management.\n  • Buat Version History diwebsite.\n  • Buat Reopen reason.\n\n28 Mar 26\n* Buat virtual office untuk PIC yang login diwebsite, jadi bisa melihat seolah-olah orang yang login diwebsite masuk kedalam kantor\n\nKendala saat mobile view sidebar tidak muncul.	2026-03-28	\N	\N	\N	2026-03-23 19:25:37+00	2026-03-27 23:53:23+00	Komeng
729326a8-4780-4bd5-a2f5-051cd4769c52	33	2026-01-20	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	"1. Widi to Swiss-BelInn Simatupang Jakarta: 22 Jan 26 (Refresh Training PO & RECV Module).\n2. Robi to The Gunawarman Luxury Residence (Prana Nadi): 22 Jan 26 (Maintenance Billing Issue).\n3. Rama to Kedaton Hotel Bandung: 26 Jan 26 - 1 Feb 26 (Annual Maintenance).\n4. Fachri to Batiqa Hotel Jababeka: 26 Jan 26 - 1 Feb 26 (Refresh Training).\n\n1. Prad to LAMORA Kota Lama Surabaya: 26 Jan 26 - 31 Jan 26 (Refresh Training & Annual Maintenance).\n2. Hasbi to to Arion Suites Hotel Kemang: 26 Jan 26 - 28 Jan 26 (Migration Server & Refresh Training)."	Sudah dibuatkan SPK nya.	2026-01-22	2026-01-29 16:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
de4f94b3-b1db-4ca7-a28d-18729fb2cda1	32	2026-01-15	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	916d5c42-bb16-4dba-a75d-28a68a987ec0	\N	Prepare PIC Training Online	Arrange Fachri.	2026-01-16	2026-01-29 16:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Yance | IT
f7251b22-4178-41d2-ac68-aca30e31fc90	36	2026-01-22	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	c3b88985-393a-4836-add7-a4f5ee20bcc0	\N	Prepare PIC untuk Training Revenue Manager.	Arrange Vincent.	2026-01-30	2026-02-02 15:14:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Liverto | IT Corporate
bc4e5bbd-43be-4a09-8ba6-886c820c344b	37	2026-01-23	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat kolom Completed Date yang akan terisi otomatis saat Status berubah menjadi Completed.	Sudah dibuatkan menggunakan Notion Automation pada field Completed Date. \nLakukan update yang Completed pada tanggal 29 Jan 26, walaupun sudah Completed pada tanggal sebelumnya karena diupdate pada tanggal 29 Jan 26, maka pada field Completed Date menjadi tanggal 29 Januari 2026.	2026-01-23	2026-01-29 16:55:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
95e972ef-eb1f-4eae-96c4-881500dd5600	38	2026-01-23	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	2c20bf6f-b3db-40f3-b521-83930411e7e0	\N	Prepare PIC untuk Online Training Training AP Module [14.00].	Arrange Robi.	2026-01-26	2026-02-02 15:14:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Alvin | IT
1d599906-b6cc-48e6-b7b4-05e54fbb377e	39	2026-01-23	8df1e174-6803-4772-8d55-d0158eedd8c8	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	9e38ab00-65dd-49ce-ba41-5ddd0b849318	\N	Makesure Opening yang sebelumnya diinformasikan pada hari Senin, 26 Januari 2026 untuk mengirimkan karangan bunga.	Sudah WA Akbar untuk memastikan. | Konfirmasi dari Akbar tidak diperlukan karangan bunga, karena tidak opening untuk umum, hanya untuk rekan owner saja.	2026-01-23	2026-02-02 15:30:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Hotel Management
992aa3e0-b5ec-453c-886b-5c257400156f	40	2026-01-23	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Request change schedule yang sebelumna diagendakan 26 - 30 masuk Duty, request menjadi Day karena ada meeting dengan SBI dan juga mengerjakan issue CM.	"Sudah dicarikan penggantinya dengan Aldi, jadi change menjadi:\n1. Aris sebelumnya: 26 Jan 26 - 30 Jan 26 adalah Duty,\nchange menjadi: Day.\n2. Aldi sebelumnya: 26 Jan 26 - 30 Jan 26 adalah Day,\nchange menjadi: Duty.\n3. Aris sebelumnya: 2 Feb 26 - 6 Feb 26 adalah Day,\nchange menjadi: Duty.\n4. Aldi sebelumnya: 2 Feb 26 - 6 Feb 26 adalah Duty,\nchange menjadi: Day."	2026-01-23	2026-01-29 16:57:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Aris
5b1db59b-219b-46fe-9d41-7985f9185644	46	2026-01-30	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update SPK	02 Feb 26.\n1. Ridwan to Bumi Surabaya City Resort: 29 Jan 26 - 8 Feb 26 (Annual Maintenance).\n2. Basir & Rizky to Swiss-Belhotel Borneo Banjarmasin: 2 Feb 26 - 15 Feb 26 (Upgrade to Cloud Version).\n3. Sahrul & Iqhtiar at Swiss-Belboutique Yogyakarta: 2 Feb 26 - 8 Feb 26 (Extend: Mentoring EOM).\n4. Indra & Wahyudi at Swiss-Belhotel Rainforest Bali: 2 Feb 26 - 8 Feb 26 (Extend: Mentoring EOM).\n5. Prad at LAMORA Kota Lama Surabaya: 2 Feb 26 - 3 Feb 26 (Extend Maintenance).\n6. Mamat to Grand Kolopaking: 2 Feb 26 - 8 Feb 26 (Refresh Training).\n7. Rama to PT. Primahotel Manajemen Indonesia (Head Office): 3 Feb 26 (Overview Financial Report).	2026-02-02	2026-02-03 10:43:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
d9d8d551-b778-4bfd-b551-325a781c0947	47	2026-02-01	906fd8d5-bc3a-46d3-94a7-b1914d65ec47	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update Automation di Notion agar Information Date terisi otomatis tanggal pembuatan list.	Sudah diupdate trigger untuk mengambil date dari Today.	2026-02-01	2026-02-02 12:57:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
c676f065-ad51-439e-a607-2344ad78b9e9	50	2026-02-02	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	f845cfe9-2d07-4c7d-8563-69b938edadf6	\N	Prepare PIC Refresh Training 23 Feb 26 - 1 Mar 26.	Arrange Naufal. | Karena Naufal masuk malam, jadi Robi yang akan berangkat.	2026-02-09	2026-02-18 19:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Reynaldi | IT
d560f69d-1777-4feb-bcae-0c6cdebf3c91	51	2026-02-03	fe796280-7e80-4f76-a44c-a0d8d4064d8e	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	2dd6eedd-9089-49f8-898e-9d069063f707	\N	Prepare PIC untuk kunjungan perihal Asset Issue pada 9-15 Feb 26.	Arrange Yudi.	2026-02-03	2026-02-09 15:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Eko | CA
3e7f3eec-53f4-48b9-bceb-aacac1a35d4a	52	2026-02-03	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update SPK	3 Feb 26\n1. Aldi to Maxone Hotel-Kota Harapan Indah: 4 Feb 26 - 6 Feb 26 (Review Standardization Report).\n2. Vincent & Adi to eL Hotel & Resort Bali - Sanur: 9 Feb 26 - 9 Apr 26 (Implementation Cloud Full Version).\n3. Ridwan to Golden Palace Hotel Lombok: 9 Feb 26 - 5 Feb 26 (Annual Maintenance).\n4. Prad to Morazen Hotel Surabaya: 4 Feb 26 - 6 Feb 26 (Refresh Training).\n5. Fachri to Nusantara International Convention Exhibition: 4 Feb 26 - 6 Feb 26 (Reporting Issue).\n\n4 Feb 26\n1. Jaja to Maha Resort Party -Bali: 6 Feb 26 - 12 Mar 26 (Continue Implementation Cloud Full Version).\n2. Indra to Maha Resort Party -Bali: 9 Feb 26 - 12 Mar 26 (Continue Implementation Cloud Full Version).\n3. Rama at PT. Primahotel Manajemen Indonesia (Head Office): 4 Feb 26 (Extend: Overview Financial Report).	2026-02-04	2026-02-06 11:06:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
549e7159-6c83-41f1-90de-a6742f4b2c42	53	2026-02-03	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update Project Brody to Morazen Surabaya	Sudah dibuatkan, dengan Project ID 5056.	2026-02-03	2026-02-03 13:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
94176fd8-93be-4392-9be1-f2b60ae96f9e	54	2026-02-06	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Prepare pengganti Brody masuk malam, karena extend di Morazen Hotel Surabaya	Sabtu / Minggu bisa menggunakan Joki\nSenin - Jum’at malam bisa dengan Tier 1 yang melanjutkan (alasan karena bukan waktu closingan dan dengan Mulya juga). | Challenge Dhika untuk masuk malam dengan Mulya.	2026-02-06	2026-02-18 19:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
4087bb96-14c2-453c-adbf-55f2df537a76	55	2026-02-06	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Project Mujiono untuk request permintaan Arch House	Sudah dibuatkan project di CNC.	2026-02-06	2026-02-06 15:35:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
b4e2a18f-597a-42a7-9719-ff6ddc686c58	56	2026-02-06	c5166ed9-cb08-4495-8138-457ecc03fcd8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cari pengganti Assesor Mujiono, karena ada project Arch House yang perlu diselesaikan	Arrange Ilham.	2026-02-09	2026-02-10 17:48:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
cde0a6dd-ba16-4c56-ab98-9d8f6dd7c4af	57	2026-02-06	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	53a9faac-c20a-4436-991d-fa5bcb0aa928	\N	Update Project extend Brody	Sudah diextendkan sampai tanggal 13 Februari 2026.	2026-02-06	2026-02-09 15:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	\N
94e7baad-c9ff-43fb-86ea-b16636e18e7e	58	2026-02-06	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	34ca9efe-bf13-41e9-b5e9-a952c34da562	\N	Prepare Tiket kereta Fachri tgl 9 Feb 26	Sudah mendapatkan tiket kereta api untuk tanggal 9 Feb 26.	2026-02-06	2026-02-09 15:52:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
24758905-32da-4a51-b858-8596d2a337d8	59	2026-02-06	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	22add061-44d9-4e1c-988e-a28cd2d77fc2	\N	Prepare Project & Tiket Sodik	Sudah mendapatkan tiket kereta api dengan keberangkatan pada tanggal 8 Feb 26	2026-02-06	2026-02-09 15:52:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
837a1c31-af79-4753-a1cd-284a2070e46e	60	2026-02-06	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Work Order	6 Feb 26\n1. Prad at Morazen Hotel Surabaya: 7 Feb 26 - 13 Feb 26 (Extend: Standardization Reports).\n2. Mamat at Grand Kolopaking: 9 Feb 26 - 13 Feb 26 (Extend Refresh Training).\n3. Hasbi at JHL Jeep Station Indonesia Resort (JSI): 9 Feb 26 - 15 Feb 26 (Extend: Refresh Training).\n4. Sodik to Dafam Hotel Semarang (Owned): 9 Feb 26 - 15 Feb 26 (Annual Maintenance).\n5. Danang to The NewTon Bandung: 8 Feb 26 - 15 Feb 26 (Annual Maintenance).	2026-02-06	2026-02-09 15:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
7af1e211-0389-4ac9-ae72-f432e906e6c0	61	2026-02-06	c5166ed9-cb08-4495-8138-457ecc03fcd8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	5cfa9c2b-9954-48da-ae6b-de4ef3207b3f	\N	Konfirmasi Keylock sudah interce atau belum	Terlihat data project di CNC bahwa keylock Stedy belum interface, dan sudah di WA juga ke Pak Deddy.	2026-02-06	2026-02-09 15:52:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Deddy | IT Corporate
3f0b0136-3ddc-4769-9667-6f29348e59c4	62	2026-02-09	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Work Order	9 Feb 26\n1. Sahrul & Iqhtiar at Swiss-Belboutique Yogyakarta: 9 Feb 26 - 12 Feb 26 (Extend: Mentoring EOM).\n2. Hasbi at JHL Jeep Station Indonesia Resort (JSI): 9 Feb 26 - 10 Feb 26 (Extend: Refresh Training).\n3. Ridwan to Savana Hotel & Convention Malang: 16 Feb 26 - 22 Feb 26 (Annual Maintenance).\n\n10 Feb 26\n1. Hasbi to Sahira Butik Hotel Paledang Bogor: 11 Feb 26 - 13 Feb 26 (Refresh Training).\n\n12 Feb 26\n1. Rama & Dhani to d'primahotel Yogyakarta: 13 Feb 26 - 4 Mar 26 (Implementation Cloud LITE Version).\n\n13 Feb 26\n1. Ichwan to Grand Cikarang Hotel: 13 Feb 26 - 14 Feb 26 (Review System Low)\n2. Ridwan to Savana Hotel & Convention Malang: 16 Feb 26 - 22 Feb 26 (Annual Maintenance)\n3. Danang at The NewTon Bandung: 16 Feb 26 - 22 Feb 26 (Extend: Standardization Report).\n4. Sodik at Dafam Hotel Semarang (Owned): 16 Feb 26 - 22 Feb 26 (Extend: Refresh Training).	2026-02-12	2026-02-16 10:01:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
54c166d4-736b-4f02-8f4b-b2ce7023c2a8	63	2026-02-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	a47b066f-294a-4865-ae26-52214803feb8	\N	Update Project Taman Dayu untuk Mujiono	Sudah dibuatkan dengan Project ID 5062.	2026-02-09	2026-02-09 15:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
08e90ff4-dc26-4fd1-9eeb-a73f6ae5ed99	64	2026-02-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Konfirmasi Status Indra bantu Jaja atau bagaimana	Konfirmasi via telpon dari Indra, akan membantu Jaja di Maha Party.	2026-02-09	2026-02-09 15:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
a301a022-db8f-4e65-b924-8efac14aca71	65	2026-02-09	4fe4b040-17c0-4763-94aa-4764c69bf2da	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	69043bf5-9691-4ff9-ad36-dd3e33f8268b	\N	Prepare Meeting online dengan Kristal Kupang hati Rabu, 14.00 WIB pembahasan tentang kebutuhan laporan pajak	Arrange Robi\n\nBerikut MOM dari meeting tersebut\nhttps://web.plaud.ai/s/pub_4f76f086-dbfb-48d4-88c1-6745e0430ed2::YTyB8bPmll2vdtXGflxozMHTcjiEgA5F9n-niwKgL-BrS8AKPG8fSyWsgy7Ppvo2nOpYiOEgpIoPJ00C	2026-02-09	2026-02-11 19:05:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Ibu Tina | Acct
2f00d026-00de-4363-bfa1-10a0bdffa486	66	2026-02-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	d9952ec4-6c9f-422b-8991-4e87678ed513	\N	Prepare PIC ke D’Prima Yogyakarta mulai 12 Feb 26	Arrange Rama & Dhani. | Tiket dibantu provide dari hotel.	2026-02-09	2026-02-18 19:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
823244bc-98b6-4d96-bab8-a59c5f7bd7f3	106	2026-02-27	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	5a808269-a953-4284-8a63-86f804bcd6b0	\N	Offline Mode auto on	Sudah dibantu Sahrul untuk setting Offline Mode, dan sudah berhasil	2026-02-27	2026-03-10 14:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Budi
c6d907d3-f5e5-4f1b-995c-ba361314e28e	69	2026-02-09	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Prepare PIC untuk ikut meeting dengan SBI Regional membahas tentang merger antara SBHB & GBHB	Arrange Ridwan, karena dia sudah paham konsep lebih detail.\nBerikut MOM nya\n\nhttps://web.plaud.ai/s/pub_602cfdcc-42d9-4ea0-a212-2a1f12cc59fd::hsj8NXO6Z7SyRnIjmluP2oUSte-U1FWMMKbO2wWusoaf_iIDEMMe_0qriB3Ui_cSlPXXjuK64RDWY3UC	2026-02-09	2026-02-10 17:46:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
e5c2dacb-780d-437c-b275-623fb4dfb023	70	2026-02-10	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	c4bde408-14c0-4ff1-8c34-78dae5d16501	\N	Prepare PIC untuk  On Line Training Logistic Module 11-12 Feb 26 jam 10.00 WIB	Arrange Aldi.	2026-02-10	2026-02-11 09:46:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Ibu Deviary | CC
b6836ec2-b7a1-4d00-a96a-5786152225e9	71	2026-02-10	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	ab75e6b5-6a9f-4a5e-982c-3e9189dfd0f3	\N	Prepare PIC untuk training online Kamis, 12 Feb 26	Informasi dikirim oleh IT department via email.  | Assign Widi.	2026-02-10	2026-02-20 09:00:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Nofan | IT
f206e832-78c6-48d0-b130-f062ee2a5cf2	72	2026-02-10	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	2be1610e-9844-430d-9595-5db2ccb37d09	\N	Prepare PIC Retraining & Maintenance pada 22 - 28 Feb 26	Arrange Mamat, ganti ke Mujiono, karena Mamat akan ke GDAS pada tanggal 23 Feb 26.	2026-02-10	2026-02-18 19:32:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Salman | IT
1893c125-4499-405b-91db-f7ec3e9725f5	73	2026-02-10	ced36e5b-8236-47c1-ad25-1cf4323d0f81	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Permintaan penawaran Power Pro	Java Village Resort\nRoom: 87 + 1 Villa\nOutlet: Existing ada 14, namun actual digunakan 4-5 saja\nKeylock: Dexon\nPABX: Panasonic TDA 100D\n\nPIC:\nBapak Alief | IT\nEmail: mailto:it@javavillageresort.com mailto:it.javavillageresortjogja@gmail.com\nWA: +62 812-2625-0740\n\nSudah dikirim via WA ke Pak Denny Tan.	2026-02-10	2026-02-10 11:23:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Alief | IT
c1627d9b-835c-4f85-901f-6e83f9e34507	76	2026-02-10	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	e1226384-731f-473c-8029-f3528f134095	\N	Update Project Ridho untuk Training Online: FO Module tanggal 10 Feb 26 jam 14.00 WIB	Sudah dibuatkan dengan Project ID 5048.	2026-02-10	2026-02-10 17:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Aden | IT
2cbcc04a-1009-4e6d-91d4-12906184f491	77	2026-02-10	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Note untuk Dhani	* Calm\n* Tidak perlu panik\n* Jika ada yang tidak tahu bisa bilang akan dikordinasikan dengan Mas Rama\n\nSudah disampaikan direct untuk membuat target juga.	2026-02-10	2026-02-10 17:47:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
2265128e-6077-45f2-b686-919c16bcc003	78	2026-02-10	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	049fe264-7095-4162-b07f-4370a628bce6	\N	Create Project Megalos Secana dan akan dihandle Yosa	Konfirmasi Yosa bisa bantu. | Sudah dibuatkan dengan Project ID 5068.	2026-02-10	2026-02-11 09:55:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	\N
788772d6-d07b-4ab8-bb7b-333546d8cfe1	79	2026-02-10	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	a7e2a8c5-10ea-4686-b941-69903c3a737a	\N	Create Project Hasbi ke Paledang 3 hari	Sudah dibuat dengan Project ID 5067.	2026-02-10	2026-02-11 09:45:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Adjie | IT
9d32182d-6a79-4b69-ab5d-fe432fbcfb11	82	2026-02-11	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	7c9bb617-0077-456d-a84d-62f783674768	\N	Prepare PIC Training Online Jum’at, 13 Feb 26 jam 14.00 WIB dengan materi Purchasing & Store	Assign Ridho.	2026-02-12	2026-02-20 14:54:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Manuarang | CA
7e31527d-7e2b-45ad-bd3d-92052745741c	83	2026-02-13	c5166ed9-cb08-4495-8138-457ecc03fcd8	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	0fd14e71-fd9d-4d10-b2a5-87a76ade15fd	\N	Kirim karangan bunga ke Maha Party tanggal 14 Feb 26	Sudah dikirimkan pada tanggal 14 Feb 26.	2026-02-13	2026-02-18 19:28:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	\N
3460ae1f-0ad5-4971-9498-8b97e127a5a5	84	2026-02-16	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cek status Cuti Aldi tanggal 22 Jan 26.	Aldi sudah membuat cuti tanggal 22 Jan 26.	2026-02-18	2026-02-23 08:42:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
4bfd928c-927c-49ae-b1e4-4c7141d3deec	87	2026-02-16	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	SPK	16 Feb 26\n1. Basir & Rizky at Swiss-Belhotel Borneo Banjarmasin: 16 Feb 26 - 22 Feb 26 (Extend: Validation Financial Data).\n2. Hasbi at Sahira Butik Hotel Paledang Bogor: 16 Feb 26 - 20 Feb 26 (Extend: Refresh Training).\n3. Prad to LAMORA Kota Lama Surabaya: 16 Feb 26 - 22 Feb 26 (Standardization Reports).\n4. Mamat to The Manohara Hotel Yogyakarta: 22 Feb 26 - 28 Feb 26 (Refresh Training & Annual Maintenance).\n\n18 Feb 26\n1. Akbar & Farhan at The Heirloom Hotel - Jakarta: 18 Feb 26 - 20 Feb 26 (Extend: Refresh Training).\n2. Apri to The Manohara Hotel Yogyakarta: 22 Feb 26 - 28 Feb 26 (Refresh Training & Annual Maintenance).\n3. Robi to Swiss-Belinn Kemayoran: 23 Feb 26 - 01 Mar 26 (Refresh Training).\n4. Sahrul to Bentani Hotel & Residence - Cirebon: 24 Feb 26 - 28 Feb 26 (Refresh Training).\n5. Aris to Dewarna Bojonegoro Hotel & Convention: 22 Feb 26 - 1 Mar 26 (Refresh Training).\n6. Apip to Maha Resort Party -Bali: 19 Feb 26 - 12 Mar 26 (Continue Implementation Cloud Full Version)\n\n19 Feb 26\n1. Mulya to Sapphire Sky Hotel - BSD City: 23 Feb 26 - 1 Mar 26 (Refresh Training Accounting Module).\n2. Mamat to GDAS Health & Wellness Ubud: 23 Feb 26 - 1 Mar 26 (Annual Maintenance).\n3. Widi to Bogor Valley Hotel-Bogor: 25 Feb 26 - 03 Mar 26 (Annual Maintenance & Refresh Training).\n\n19 Feb 26\n1. Sodik to GranDhika Pemuda Semarang: 23 Feb 26 - 1 Mar 26 (Annual Maintenance).\n2. Yudi to eL Royale Hotel & Resort Banyuwangi: 1 Mar 26 - 7 Mar 26 (Refresh Training).\n\n20 Feb 26\n1. Ridwan to Samara Resort Hotel Batu Malang: 23 Feb 26 - 28 Feb 26 (Annual Maintenance).\n2. Yudi to Swiss-Belhotel Bogor: 23 Feb 26 - 25 Feb 26 (Review Report).\n3. Prad to Morazen Hotel Yogyakarta: 23 Feb 26 - 24 Feb 26 (Maintenance Data).\n4. Mamat to Merumatta Senggigi Lombok Kila Senggigi Beach-Aero: 2 Mar 26 - 8 Mar 26 (Annual Maintenance).	2026-02-20	2026-02-23 08:42:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
0e422d36-8013-4a46-a6be-ee8dff287b60	92	2026-02-20	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	c3b88985-393a-4836-add7-a4f5ee20bcc0	\N	Training Regulasi Deposit FO	Assign Danang.	2026-02-23	2026-02-23 19:42:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Liverto | IT Corporate
27e9a8b0-dc34-4cfd-9435-04e41b8eed9c	96	2026-02-23	8df1e174-6803-4772-8d55-d0158eedd8c8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Cek Jobsheet	1. Akbar: 16 Feb 26\n  2. Aldi: 22 Jan 26\n  3. Aldi: 16 Feb 26\n  4. Apip: 22 Jan 26\n  5. Aris: 16 Feb 26\n  6. Dhani: 02 Feb 26\n  7. Fachri: 20 Feb 26 \n  8. Farhan: 16 Feb 26\n  9. Ilham: 21-22 Jan 26 \n  10. Ilham: 16 Feb 26\n  11. Ilham: 20 Feb 26\n  12. Iqhtiar: 13 Feb 26\n  13. Mulya: 26-30 Jan 26\n  14. Mulya: 16 Feb 26\n  15. Naufal: 02 Feb 26\n  16. Rama: 12 Feb 26\n  17. Rey: 04 Feb 26\n  18. Rey: 16 Feb 26\n  19. Ridho: 28 Jan 26\n  20. Ridho: 09 Feb 26\n  21. Robi: 09 Feb 26\n  22. Widi: 16 Feb 26\n  23. Tri: 22-23 Jan 26\n  24. Tri: 29 Jan 26\n  25. Tri: 5 Feb 26\n  26. Tri: 18 Feb 26\n\nSudah diapproved oleh Rio.	2026-02-23	2026-02-23 19:38:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
58603b6b-44b9-4ad6-9c41-9d59775b2119	97	2026-02-24	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	9abaa011-65a1-4458-8f2b-c056957f6f9a	\N	Prepare training POS: Void Billing jam 14.00 WIB	Assign Lifi.	2026-02-24	2026-02-26 15:56:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Idris | Owner Rep
64b83841-9b2d-4bf4-8dfa-ea28eb158d85	98	2026-02-25	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Update SPK	25 Feb 26\n  1. Prad to Hotel Lamora Sagan - Yogyakarta: 25 Feb 26 - 4 Feb 26 (Refresh Training)	2026-02-27	2026-03-16 09:42:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
161dcac0-2ce4-4cb5-8e8a-279361a5c4c7	104	2026-02-27	64537827-c8db-41cc-a854-c0e3d0641928	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	537a0e3b-1893-417f-b998-edade4af164f	\N	Request Presentasi Power Pro terbaru, waktunya hari ini, karena owner sedang dihotel	Konfirmasi akan dibantu oleh Pak Sam, dan pada akhirnya tidak jadi, ownernya dadakan ada meeting.	2026-02-27	2026-03-10 14:33:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Ngurah | CA
3e1a193a-5333-4fc2-b445-d81cb7c898c9	105	2026-02-27	c77e712d-f987-483c-8005-a9e61873b006	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	d9952ec4-6c9f-422b-8991-4e87678ed513	\N	Kirim Karangan Bunga Projectnya Rama	Ucapan : \nCongratulations\nOpening\nd’primahotel Yogyakarta\n\nPengirim ditulis dipapan:\n(Logo) Power Pro Hotel System\n(Bawahnya menggunakan logo dan tulisan seperti attachment)\n\nTanggal pengiriman :\nSabtu, 28 Februari 2026.\n\nSudah dikirimkan pada Sabtu, 28 Februari 2026.	2026-02-27	2026-03-06 11:12:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Hotel
59dea093-4e9b-49e6-8c4a-0870cd97bdeb	108	2026-03-03	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	efc26821-f3f8-4693-8a23-187f063731cd	\N	Training Online FO Module Selasa, 10 Mar 26 jam 15.00 WIB	• Arrange Brody.\n  • Link Zoom Meeting:\nPower Pro Hotel System is inviting you to a scheduled Zoom meeting.\n\nTopic: Tijili Seminyak Hotel: Training FO Module\nTime: Mar 10, 2026 13:30 Bangkok\nJoin Zoom Meeting\nhttps://us02web.zoom.us/j/83533945402?pwd=TrQnagPQt1w1Bi1ZHMRkLakxWZucuh.1\n\nMeeting ID: 835 3394 5402\nPasscode: 296297	2026-03-06	2026-03-10 09:51:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Aji | ITM
4f364971-7165-4c4d-a45f-87a22752189c	112	2026-03-03	c77e712d-f987-483c-8005-a9e61873b006	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	75e27541-f57d-46cd-915d-8d5aa7c58d51	\N	Karangan Bunga Opening	Ucapan : \nCongratulations\nSoft Opening\néL Hotel & Resort Bali - Sanur\n\nPengirim ditulis dipapan:\n(Logo) Power Pro Hotel System\n(Bawahnya menggunakan logo dan tulisan seperti attachment)\n\nTanggal pengiriman :\nRabu, 4 Maret 2026.\n\n  • Sudah dipesankan dan dikirimkan ke hotel pada Rabu, 4 Maret 2026.	2026-03-03	2026-03-06 09:38:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Management Hotel
4c419693-9fe5-4534-acf4-2d373164573e	113	2026-03-06	666b1a27-7e84-43cf-a4bb-f7f8d846773e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Summary MAP combine antara Plaudnote x Zoom Meeting	9 Mar 26\n  • Sudah dibuatkan, dan dikirim ke Rio\nhttps://web.plaud.ai/s/pub_fab997a1-25e2-4f1b-8144-c7b94943d47b::uheLwoeTgYhhAY53Tx1vsgfeqKuXL4Xe0L7PFQ1_JHG17UP5ELLv5bc2yKEZMugGfGV7Q-RNOgpeYpMC	2026-03-06	2026-03-10 21:42:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
94b4011d-83c2-484d-8f8b-27ec42f58e0a	114	2026-03-04	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Work Order	6 Mar 26\n1. Rama & Dhani at d'primahotel Yogyakarta: 5 Mar 26 - 8 Mar 26 (Extend Implementation).\n2. Mamat to Sanur Resort Watu Jimbar: 7 Mar 26 - 14 Mar 26 (Annual Maintenance).\n3. Apri to Jambuluwuk Thamrin Hotel Jakarta: 9 Mar 26 - 11 Mar 26 (Update Request Report).\n4. Ichwan & Naufal to Hotel Ciputra World Surabaya (CWS): 1 Apr 26 - 14 Apr 26 (Upgrade to Cloud Version).\n\n5. Aris at Dewarna Bojonegoro Hotel & Convention: 9 Mar 26 - 12 Mar 26 (Extend: Mentoring Validation Data (Allowance next Year)).\n6. Danang to Novena Hotel Bandung: 9 Mar 26 - 15 Mar 26 (Annual Maintenance). \n7. Ridwan to Yunna Hotel Lampung: 9 Mar 26 - 18 Mar 26 (Annual Maintenance).	2026-03-06	2026-03-09 11:38:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
4d652802-2a79-4dcb-9c7a-650da6ec80ed	115	2026-03-05	666b1a27-7e84-43cf-a4bb-f7f8d846773e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Standarisasi Opening MAP	Full Script Opening Webinar MAP13\n(Malam Hari, 19.00 - 21.00)\n\n1. Opening & Ramadhan Vibes\n"Assalamu’alaikum Warahmatullahi Wabarakatuh. Selamat malam dan salam sejahtera untuk kita semua.\nMarhaban ya Ramadhan. Selamat menunaikan ibadah di bulan suci bagi rekan-rekan yang menjalankan. Alhamdulillah, setelah tadi kita berbuka puasa, malam ini kita masih diberikan energi ekstra untuk berkumpul di ruang virtual ini.\nPerkenalkan saya Rudianto sebagai moderator malam ini, merasa bangga bisa melihat wajah-wajah penuh semangat yang tetap ingin 'upgrade diri' meski di jam istirahat. Semoga pertemuan kita malam ini membawa keberkahan dan ilmu yang bermanfaat."\n\n2. Bridging Topik (The Hook)\n"Rekan-rekan, mari kita jujur sejenak. Di dunia hospitality, momen 'Order Taking' atau pengambilan pesanan adalah gerbang utama kepuasan tamu. Tapi, seringkali di lapangan kita menghadapi situasi yang 'chaos'—antrean panjang, pesanan yang tertukar, atau proses input yang memakan waktu lama. Apalagi kalau sudah masuk musim peak season seperti libur Lebaran nanti.\nTopik kita hari ini sangat krusial untuk operasional sehari-hari, yaitu MAP13: Level Up Your Order Taking: Faster, Simpler & Better.\nKita semua tahu, di industri kita, kecepatan dan kemudahan adalah kunci. Kita ingin tamu merasa happy karena dilayani dengan gesit, tapi di sisi lain, kita tidak ingin tim di balik layar (back of house) malah pusing karena sistemnya rumit. Nah, pertanyaannya: Gimana caranya agar proses order kita nggak cuma cepat, tapi juga lebih simpel dan hasilnya jauh lebih baik (Better)? Rahasia 'Level Up' inilah yang akan kita bedah tuntas malam ini."\n\n3. Memperkenalkan Narasumber\n"Untuk menjawab rasa penasaran tersebut, sudah hadir bersama kita sosok yang sangat kompeten dan ahli di bidangnya. Mari kita sapa dengan hangat, Mas Ade Septian Nugroho, atau yang akrab kita panggil Pak Bowo.\nSelamat malam, Pak Bowo! Wah, kelihatannya sudah siap sekali ya membagikan 'resep rahasia' agar operasional teman-teman di hotel jadi lebih smooth?"\nKeyboard Warrior\n\n4. Housekeeping & Agenda (Notice Penting)\n"Sebelum layar saya serahkan kepada Pak Bowo, ada beberapa hal yang perlu saya ingatkan kepada rekan-rekan peserta:\n• PENTING: Mohon pastikan nama akun Zoom Anda sudah diganti dengan format: [NAMA] - [NAMA HOTEL]. Ini supaya Pak Bowo dan saya bisa menyapa rekan-rekan dengan lebih akrab. Silakan di-rename sekarang ya.\n• INTERAKTIF: Malam ini bukan sesi dengerin radio ya. Kita akan ada dua sesi seru: Session Interactive Summary (untuk menguji pemahaman kita) dan Session Interactive Q&A. Jadi, kalau ada kendala di hotel masing-masing, langsung siapkan pertanyaannya!"\n\n5. Closing Opening (Call to Action)\n"Baik, tanpa memperpanjang mukadimah lagi, mari kita siapkan catatan dan fokus kita. Kepada Pak Bowo, waktu dan layar kami persilakan dengan hormat."	2026-03-05	2026-03-06 09:35:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
a588f757-a0ab-4a67-9e82-3d4f364a682c	116	2026-03-05	666b1a27-7e84-43cf-a4bb-f7f8d846773e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Quiz Interactive	Evaluasi Sistem POS Power Pro\nPertanyaan 1\nManakah dari pernyataan berikut yang merupakan karakteristik utama dari Mode Retail (Toko/Swalayan) pada sistem POS Power Pro?\nA. Menggunakan fitur Table Management yang kompleks untuk memantau status meja pelanggan [1].\nB. Alur pembayaran dilakukan di akhir setelah pelanggan selesai makan atau menggunakan sistem Open Bill [1].\nC. Menggunakan input order berbasis barcode scanner dan otomatis mengurangi stok gudang pada manajemen inventori [1, 2].\nD. Mengutamakan tombol menu bergambar dan berukuran besar karena ditujukan untuk bisnis yang mengutamakan kecepatan layanan cepat saji [2].\nE. Menampilkan pop-up pilihan Mixer secara otomatis saat melakukan order minuman beralkohol [3].\n> Jawaban: C\n> Alasan: Mode Retail secara khusus digunakan untuk toko eceran, minimarket, dan swalayan dengan fokus utama pada kecepatan transaksi dan pengelolaan stok [1]. Karakteristik utama dari mode ini adalah input order yang dioptimalkan menggunakan barcode scanner dan adanya manajemen inventori di mana setiap barang yang terjual akan otomatis mengurangi stok gudang [1, 2].\n>\nPertanyaan 2\nDalam sistem Power Pro, apa perbedaan utama antara penggunaan fitur Modifier dan Side Dish?\nA. Modifier memengaruhi harga jual dan inventori, sedangkan Side Dish hanya berupa instruksi untuk dapur [4, 5].\nB. Side Dish memengaruhi harga pokok (COGS) serta tercetak di bill tamu, sedangkan Modifier tidak memengaruhi harga maupun inventori dan tidak tercetak di bill tamu [4-6].\nC. Keduanya sama-sama memengaruhi harga jual akhir, namun hanya Side Dish yang memengaruhi pengurangan stok inventori bahan baku [4, 5].\nD. Modifier digunakan sebagai minuman pendamping koktail, sedangkan Side Dish digunakan untuk menyesuaikan tingkat kepedasan makanan [4, 7].\nE. Side Dish tidak tercetak pada bill tamu karena biayanya sudah otomatis tergabung dalam menu utama, berbeda dengan Modifier [5, 8].\n> Jawaban: B\n> Alasan: Side Dish adalah makanan pendamping yang memengaruhi harga jual serta harga pokok (COGS), berpengaruh pada inventori, dan tercetak secara terpisah di tagihan (bill) tamu [4, 9]. Sebaliknya, Modifier hanyalah keterangan atau instruksi khusus untuk chef atau barista (misalnya: "Tanpa bawang" atau "Kurang manis"), sehingga tidak memengaruhi harga, tidak mengurangi inventori, dan tidak tercetak di bill tamu [5, 6, 9].\n>\nPertanyaan 3\nApa fungsi dan manfaat utama dari diaktifkannya fitur Drill-Down Menu saat staf melakukan Add Order?\nA. Menandai menu yang telah habis secara otomatis agar sistem menolak pesanan jika Maximal Sold sudah tercapai [10, 11].\nB. Menampilkan susunan kolom khusus menu favorit yang paling sering dipesan oleh pelanggan untuk mempercepat pesanan [12].\nC. Membangun pangkalan data tamu (CRM) untuk melacak riwayat pembelian dan memberikan promosi pemasaran yang tepat sasaran [13, 14].\nD. Mengelompokkan item menu ke dalam struktur bertingkat (layer dan kategori) agar layar kasir tetap rapi, mempercepat pencarian, dan meminimalkan kesalahan input [15, 16].\nE. Menyediakan opsi bagi tamu untuk melakukan pemesanan dan pembayaran secara mandiri melalui smartphone mereka dengan memindai kode QR di meja [17].\n> Jawaban: D\n> Alasan: Fitur Drill Down Menu berfungsi untuk mengorganisir item menu yang berjumlah banyak ke dalam beberapa struktur lapisan (layer) atau kategori [15, 16]. Manfaat utamanya adalah agar tampilan layar kasir tetap rapi, mempermudah kasir menemukan item berdasarkan kategori tanpa mencari satu per satu di daftar panjang, serta meminimalkan risiko salah memilih menu yang memiliki nama serupa [16].	2026-03-05	2026-03-06 09:36:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
27d3ce76-ef42-4646-88a7-ce3285d95452	117	2026-03-05	666b1a27-7e84-43cf-a4bb-f7f8d846773e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat Standarisasi Closing MAP	"Alhamdulillah, rekan-rekan semua, tidak terasa kita sudah berada di penghujung acara. Dua jam berlalu begitu cepat karena materinya benar-benar 'daging' semua.\n\nTadi Pak Bowo sudah membedah tuntas bagaimana caranya agar Order Taking kita tidak hanya sekadar cepat (Faster), tapi juga praktis (Simpler), dan yang paling penting kualitasnya jauh lebih unggul (Better). Semoga ilmu yang dibagikan Pak Bowo tadi bukan cuma jadi catatan di buku, tapi benar-benar bisa kita 'gas pol' di hotel masing-masing, apalagi sebentar lagi kita menyambut peak season Lebaran."\n\n2. Terima Kasih kepada Narasumber\n"Sekali lagi, kami ucapkan terima kasih yang sebesar-besarnya kepada Pak Bowo atas waktu dan ilmu yang luar biasa malam ini. Sehat selalu Pak Bowo, semoga jadi amal jariyah yang berlipat ganda di bulan Ramadhan ini."\n\n3. Terima Kasih kepada Peserta\n"Terima kasih juga untuk rekan-rekan hotelier dari berbagai hotel yang sudah bertahan, tetap interaktif, dan semangat belajar meski sudah jam 9 malam. Bapak / Ibu semua adalah bukti bahwa profesionalisme tidak kenal waktu!"\n\n4. Pantun Penutup (Ramadhan & Hospitality)\n"Sebelum kita benar-benar berpisah, izinkan saya menutupnya dengan sedikit pantun ya:\n\nMakan kolak dicampur santan,\nRasanya manis tak terlupakan.\nMohon maaf jika ada kekurangan,\nSampai jumpa di lain kesempatan."\n\n5. Salam Penutup\n"Saya Rudianto selaku moderator, pamit undur diri. Selamat beristirahat, selamat melanjutkan ibadah malamnya.\n\nWassalamu’alaikum Warahmatullahi Wabarakatuh.\nSelamat malam dan salam sukses untuk kita semua!”	2026-03-05	2026-03-06 09:35:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
3b8fff32-1d0a-40c8-8c53-38bae2bac852	118	2026-03-06	fe796280-7e80-4f76-a44c-a0d8d4064d8e	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	66471964-8368-4683-90b5-63422bdd9894	\N	Training Online IT untuk Clossing System	9 Mar 26\nDetail Training:\n10 Mar 26 jam 14.00 WIB: IT Module\n11 Mar 26 jam 14.00 WIB: Accounting Module\n\n10 Mar 26\nArrange Ridho.\n\nLink Zoom Meeting:\nTopic: Grand Inna Tunjungan Surabaya (Simpang): Training IT & Accounting Module\nTime: Mar 10, 2026 02:00 PM Bangkok\nJoin Zoom Meeting\nhttps://us02web.zoom.us/j/87972711758?pwd=dOSvKidc9xezAiuGSk4xrU6pzSGbBv.1\n\nMeeting ID: 879 7271 1758\nPasscode: 552438	2026-03-06	2026-03-10 09:50:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Bapak Ferrys
9688cdcf-7e32-49c0-88d3-3b2688be3383	120	2026-03-09	64537827-c8db-41cc-a854-c0e3d0641928	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	1a0e7f9e-6a7f-4e39-9600-cb5ac99a51fb	\N	Tambahkan project Rama dan Dhani ke HO Prima 9-13 Mar 26	Sudah dibuatkan Project dan SPK nya.\nProject ID: 5101.	2026-03-09	2026-03-09 16:41:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
72bf02c2-c643-43da-8c86-23543ed2991d	121	2026-03-09	03d05e24-dd4e-4fba-b257-5cb0f78817e8	bbffc2f0-48e6-4e7d-87cd-51c36e9c0df9	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Surat Perintah Kerja	1. Rama & Dhani at PT. Primahotel Manajemen Indonesia (Head Office): 9 Mar 26 - 13 Mar 26 (Review Setup Project d'primahotel Yogyakarta).	2026-03-13	2026-03-10 21:41:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Komeng
d28319e4-e133-40a9-bed4-17b081c84a0e	130	2026-03-10	ced36e5b-8236-47c1-ad25-1cf4323d0f81	d1ec1039-9568-4fc1-98c7-b7056b7b0968	94647a1c-2d0f-43f0-a2d9-9db1aee119bd	2d21ed5c-acc9-465e-9342-3fad6ef33370	59e31f95-3412-487c-aa14-60a023fd7953	\N	Buat TImeline Grand Swiss-Belhotel Harbour Bay Opening 25 April 2026	Sudah dibuatkan dan dikirimkan via email ke Pak Wahyu, cc ke Pak Den.\nto\nmailto:itbatam@swiss-belhotel.com\ncc\nmailto:fcbatam@swiss-belhotel.com \nmailto:denny@powerpro.id	2026-03-10	2026-03-11 09:14:00+00	\N	\N	2026-03-23 19:25:37+00	2026-03-23 19:28:00+00	Pak Denny
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.user_roles (user_id, role_id) FROM stdin;
2d21ed5c-acc9-465e-9342-3fad6ef33370	bad66a1d-a1c7-492c-be3a-d4819055db9a
92fb134a-68bc-4409-a20d-8fa3775a720f	bad66a1d-a1c7-492c-be3a-d4819055db9a
00105146-5aa4-48e4-8257-da9fa978ae39	4a4095a3-fdbd-4914-aae8-250585c598c5
d4e4cc9a-981b-494b-b2ef-0393ae528db4	4a4095a3-fdbd-4914-aae8-250585c598c5
de5c51db-2597-4f0a-a4d5-535d635782ff	4a4095a3-fdbd-4914-aae8-250585c598c5
2e4d58b3-dac8-45e8-8264-4a45b1efadb4	4a4095a3-fdbd-4914-aae8-250585c598c5
c5488362-73c9-4786-a3c3-ec225bede94d	4a4095a3-fdbd-4914-aae8-250585c598c5
a8821cd4-0d6b-41d8-904e-0125c6f6df60	4a4095a3-fdbd-4914-aae8-250585c598c5
c759001d-4938-4e9e-93f7-3ce268e01baa	4a4095a3-fdbd-4914-aae8-250585c598c5
ddbb523c-5584-41f4-9692-d4aa0a075cb9	4a4095a3-fdbd-4914-aae8-250585c598c5
e813a763-a655-4d68-b2e4-09c58090da8c	4a4095a3-fdbd-4914-aae8-250585c598c5
bc996806-6084-4106-860f-9af8a384ceb8	4a4095a3-fdbd-4914-aae8-250585c598c5
c22cfdee-91ea-4dc9-8a95-e6e04e8587b5	4a4095a3-fdbd-4914-aae8-250585c598c5
fcd64106-857c-4c07-b8fe-319f24464ed8	4a4095a3-fdbd-4914-aae8-250585c598c5
50b1bb9c-e2a7-4649-89fd-900a7b183769	4a4095a3-fdbd-4914-aae8-250585c598c5
33ead343-037c-4395-ba6b-7623875b835e	4a4095a3-fdbd-4914-aae8-250585c598c5
22d30bba-8bc2-4f47-bdbb-0f4aac0f5785	4a4095a3-fdbd-4914-aae8-250585c598c5
e946a4ee-42df-479d-a5d2-23a113ae0e67	4a4095a3-fdbd-4914-aae8-250585c598c5
dcc984d4-0872-4d3e-b65b-6661d9b006a2	4a4095a3-fdbd-4914-aae8-250585c598c5
1242a32b-67f2-4e6b-b696-5ccae03aabc3	4a4095a3-fdbd-4914-aae8-250585c598c5
a6ef812d-753b-470f-bffb-976fe7e4ef1e	4a4095a3-fdbd-4914-aae8-250585c598c5
e40f0ce5-c2cd-4b6a-84d0-d4ed70c8a820	4a4095a3-fdbd-4914-aae8-250585c598c5
bd8fe829-e0aa-4e8a-80da-1914869e699c	4a4095a3-fdbd-4914-aae8-250585c598c5
d02a8865-a87e-4833-9456-0eb18d07b74c	4a4095a3-fdbd-4914-aae8-250585c598c5
66767b13-30fc-4d74-bfc5-6a62e0a413fc	4a4095a3-fdbd-4914-aae8-250585c598c5
55ff30f3-1ace-4939-88c7-5bb0222359a4	4a4095a3-fdbd-4914-aae8-250585c598c5
5b7eea2c-c1b6-4283-8c3e-9b64db29c3b5	4a4095a3-fdbd-4914-aae8-250585c598c5
6d2c4318-af44-4731-a0b8-eb3befea9ff6	4a4095a3-fdbd-4914-aae8-250585c598c5
b892a3bf-8eca-4935-8f0d-8f93b4dd9671	3c6fd8e9-45db-4489-ad9a-f9e9eb5eaf18
c06bfddc-43fa-4164-a273-91a325d14609	3c6fd8e9-45db-4489-ad9a-f9e9eb5eaf18
2d21ed5c-acc9-465e-9342-3fad6ef33370	05639d9b-5775-44bd-8a08-7a110a44dc34
a56adef3-469d-4bc7-8c40-e73d6e55bf8c	4a4095a3-fdbd-4914-aae8-250585c598c5
b154b761-ee54-4077-88d1-bcba0774a03e	4a4095a3-fdbd-4914-aae8-250585c598c5
657967a8-be13-47b5-a0bf-7799039a9855	4a4095a3-fdbd-4914-aae8-250585c598c5
849dec85-7ef2-4e75-bf63-1ef5d18ad95f	4a4095a3-fdbd-4914-aae8-250585c598c5
8aecca1e-e075-4ad5-98ba-f5b1f61094d1	4a4095a3-fdbd-4914-aae8-250585c598c5
e551a175-fbc0-49c1-b062-8cc5268462ac	4a4095a3-fdbd-4914-aae8-250585c598c5
04eaa201-11bc-4d30-8e77-9a871b613f28	4a4095a3-fdbd-4914-aae8-250585c598c5
cc5abe29-0605-4d3c-a23a-e7806bb92b54	4a4095a3-fdbd-4914-aae8-250585c598c5
759ae0a9-d2b1-4b91-abde-2cb530cd072c	4a4095a3-fdbd-4914-aae8-250585c598c5
61e99596-7868-4467-a7e8-90ecaecd4b8f	4a4095a3-fdbd-4914-aae8-250585c598c5
8d416fea-80ef-4ecf-97d0-6ca06b924091	4a4095a3-fdbd-4914-aae8-250585c598c5
d974b549-7113-4295-978a-9f03b602eda1	4a4095a3-fdbd-4914-aae8-250585c598c5
56390b79-3748-49f3-8831-1c7dcb578772	4a4095a3-fdbd-4914-aae8-250585c598c5
f24dba6c-1fb4-4cef-a595-78ab40b9247d	bad66a1d-a1c7-492c-be3a-d4819055db9a
d95224f6-f0b6-46a3-aee9-52798feeb6c6	4a4095a3-fdbd-4914-aae8-250585c598c5
287e0e1b-1a63-434a-be66-394a54d9ebe4	4a4095a3-fdbd-4914-aae8-250585c598c5
504d1ac1-6ee0-46cb-ae8a-0ceeda5e0716	4a4095a3-fdbd-4914-aae8-250585c598c5
9ca1f3c9-54a0-4c05-9e31-ce2aabbca236	bad66a1d-a1c7-492c-be3a-d4819055db9a
6c285dd0-cfee-4828-a872-275a8fd7feda	4a4095a3-fdbd-4914-aae8-250585c598c5
bf7e1721-eaab-483f-aca4-bb092f554633	4a4095a3-fdbd-4914-aae8-250585c598c5
5b54b801-06ad-4044-93d9-be37f74a79dd	4a4095a3-fdbd-4914-aae8-250585c598c5
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: ppm
--

COPY public.users (id, email, name, password_hash, is_active, profile_photo_path, created_at, updated_at) FROM stdin;
ddbb523c-5584-41f4-9692-d4aa0a075cb9	hanip@powerpro.co.id	Hanip	$2y$12$0u8FlJWvZLx.g13Qm320hOuA1sOeX/ZduzElISK1K9CMY1cAgQWPy	t	\N	2026-03-18 22:26:51+00	2026-03-18 23:14:48+00
00105146-5aa4-48e4-8257-da9fa978ae39	dhika@powerpro.co.id	Dhika	$2y$12$q6fDP7rqUhxLO.62F1fU0uQLyqx7ruzG4lONTOZrl3us1GhabGBeK	t	\N	2026-03-18 22:26:50+00	2026-03-18 23:14:47+00
2d21ed5c-acc9-465e-9342-3fad6ef33370	admin@local.test	Administrator	$2y$12$5t.fpya0XWSsJd7XHiU6qOWQUZgS7VvOqZxLj.yweJKbWhP7ij65m	t	\N	2026-03-18 08:37:29+00	2026-03-18 08:37:29+00
2e4d58b3-dac8-45e8-8264-4a45b1efadb4	farhan@powerpro.co.id	Farhan	$2y$12$zIAT1k4UAdLFnIeT9i3HpeQvB6RQ2R2bRZcs5VbbvDqJeoRxwIk9S	t	\N	2026-03-18 22:26:51+00	2026-03-18 23:14:47+00
33ead343-037c-4395-ba6b-7623875b835e	indra@powerpro.co.id	Indra	$2y$12$q2XpdCG3EXZgUkRIF2ngSuEtNMsqRbDdZHWadYZqHuX733WOply1y	t	\N	2026-03-18 22:26:53+00	2026-03-18 23:14:49+00
504d1ac1-6ee0-46cb-ae8a-0ceeda5e0716	akbar@powerpro.co.id	Akbar	$2y$12$RbpNwVCkEg269z0dBDyFEezhYo68kP9Y4waejFwbQ0yd0tmXqYy.y	t	\N	2026-03-18 22:26:47+00	2026-03-27 08:37:35+00
50b1bb9c-e2a7-4649-89fd-900a7b183769	imam@powerpro.id	Imam	$2y$12$46h0mApo6kaV9ykIArn78uSC9D2jtrY5DX4VGq0BDooygaYaDZ14W	t	\N	2026-03-18 22:26:52+00	2026-03-18 23:14:49+00
5b54b801-06ad-4044-93d9-be37f74a79dd	lifi@powerpro.co.id	Lifi	$2y$12$I6p4VhafVgTLxwdCrDg77.k9ZetVrmo.bvC.GttYMxlKUbYu3hJku	t	\N	2026-03-18 22:26:54+00	2026-03-18 23:14:50+00
657967a8-be13-47b5-a0bf-7799039a9855	muji@powerpro.co.id	Apri	$2y$12$uh95QpZwcOPVbuXz4SwQXeN3Ok9nCWOv0xkSpH53Lvr90hAYIIjgm	t	\N	2026-03-18 22:26:48+00	2026-03-18 23:14:45+00
6c285dd0-cfee-4828-a872-275a8fd7feda	iqhtiar@powerpro.co.id	Iqhtiar	$2y$12$orsOQ/A.omgDAJBagFyh7.0RPRhabMzulAfuFREfu7I9gEv5jH8Fa	t	\N	2026-03-18 22:26:53+00	2026-03-18 23:14:49+00
849dec85-7ef2-4e75-bf63-1ef5d18ad95f	aldi@powerpro.co.id	Aldi	$2y$12$j0q5Pkuy2A4LRBE82eHeGeE9DHFdxlCEJPrD09Obwog9wZ6UDnf3e	t	\N	2026-03-18 22:26:47+00	2026-03-18 23:14:44+00
8aecca1e-e075-4ad5-98ba-f5b1f61094d1	aris@powerpro.co.id	Aris	$2y$12$vxnXex4a4LZ8OHEOriA.KO4/74K3GKTERgbt8OEuQJ79z8.EUr0my	t	\N	2026-03-18 22:26:48+00	2026-03-18 23:14:46+00
92fb134a-68bc-4409-a20d-8fa3775a720f	pms@powerpro.id	Komeng	$2y$12$.UDTYt4hdWMHOuvc31iUUuQACExUEuXbFCsTXGW3FtZCPYx0G6/iG	t	\N	2026-03-18 22:26:54+00	2026-03-23 10:06:50+00
a56adef3-469d-4bc7-8c40-e73d6e55bf8c	andreas@powerpro.co.id	Andreas	$2y$12$QQnNvpIwXaRERJYQbonfeu.dpBMiq8BDN4nz5VdXYJYJJ.m7AFqx.	t	\N	2026-03-18 22:26:47+00	2026-03-18 23:14:45+00
a8821cd4-0d6b-41d8-904e-0125c6f6df60	danang.bagas@powerpro.co.id	Danang	$2y$12$h37u6/t79tmQBllDORH5ienG4SNGLVVZaqWN.PDB2eP/RTGeA.4am	t	\N	2026-03-18 22:26:49+00	2026-03-18 23:14:46+00
b154b761-ee54-4077-88d1-bcba0774a03e	afip@powerpro.co.id	Apip	$2y$12$w34nB01jVEXKC6y/zbyuF.WP6XAkEA7HVVFHgQRc0u81yVFJ/1K1S	t	\N	2026-03-18 22:26:48+00	2026-03-18 23:14:45+00
bc996806-6084-4106-860f-9af8a384ceb8	ichsan@powerpro.co.id	Ichsan	$2y$12$1cISslzHAsGk1rx/pj5neezgInRUPiuNPRQ0NUnN9OB5eWeXVl0e6	t	\N	2026-03-18 22:26:52+00	2026-03-18 23:14:48+00
bf7e1721-eaab-483f-aca4-bb092f554633	jaja@powerpro.co.id	Jaja	$2y$12$aDSSrCxtRzcx9eNm5cKDy.CCayCLOyVl.7VUO1yhzvaBK61v3cQtK	t	\N	2026-03-18 22:26:53+00	2026-03-18 23:14:50+00
c22cfdee-91ea-4dc9-8a95-e6e04e8587b5	ichwan@powerpro.co.id	Ichwan	$2y$12$w0Qnb0RH8XwLMmUFIXzjMu9WDQjWnbKzkBKVxw5PUtALN1oYtFbvG	t	\N	2026-03-18 22:26:52+00	2026-03-18 23:14:48+00
c5488362-73c9-4786-a3c3-ec225bede94d	bowo@powerpro.co.id	Bowo	$2y$12$UmFuoM2CeWoAsHuTFn35Q.dgNKTAY8wYKMpVnnsl37c7oklBPGu4G	t	\N	2026-03-18 22:26:49+00	2026-03-18 23:14:46+00
c759001d-4938-4e9e-93f7-3ce268e01baa	dhani@powerpro.co.id	Dhani	$2y$12$jk2QGrsHSUtZvHPPgM21h.RmgcE.2lbsHs8aORCyZEA14a64m3jQW	t	\N	2026-03-18 22:26:50+00	2026-03-18 23:14:47+00
d4e4cc9a-981b-494b-b2ef-0393ae528db4	fachri@powerpro.co.id	Fachri	$2y$12$6np/yU7F6EjCyyu3mmIbQePUclTA/KSDnnGdsaIJGZN8HIfJdxyHC	t	\N	2026-03-18 22:26:50+00	2026-03-18 23:14:47+00
de5c51db-2597-4f0a-a4d5-535d635782ff	arbi@powerpro.co.id	Arbi	$2y$12$lVHs5FWqOxGf3gEXuajAUOB82o268.d9ZUeYC/CcEKzYl8xMci51K	t	\N	2026-03-18 22:26:48+00	2026-03-18 23:14:45+00
e551a175-fbc0-49c1-b062-8cc5268462ac	basir@powerpro.co.id	Basir	$2y$12$QJL0oS9sILl35QzKkzAkQuqi.XwJ//KXW84h11SV7eIUBqkDxJ49S	t	\N	2026-03-18 22:26:49+00	2026-03-18 23:14:46+00
e813a763-a655-4d68-b2e4-09c58090da8c	hasbi@powerpro.co.id	Hasbi	$2y$12$K3yKswJvNihZLi.qClxNVeuIZlWKVoXh2pI8UfNYPbsoeixQHHW32	t	\N	2026-03-18 22:26:51+00	2026-03-18 23:14:48+00
fcd64106-857c-4c07-b8fe-319f24464ed8	ilham@powerpro.co.id	Ilham	$2y$12$i3xItoWWFcU.d0JhuIt/lubTQ.8FQ00VON1gw4TzlfpDXjodTSbb6	t	\N	2026-03-18 22:26:52+00	2026-03-18 23:14:49+00
9ca1f3c9-54a0-4c05-9e31-ce2aabbca236	dewi@powerpro.cloud	Dewi	$2y$12$CS8sev/wGx5leQXHdwtv6upX6T6i1s3/2RJGl6rqmjS1AHsx/BjHi	t	\N	2026-03-30 08:00:21+00	2026-03-30 08:00:21+00
04eaa201-11bc-4d30-8e77-9a871b613f28	rahmad.zaelani@powerpro.co.id	Mamat	$2y$12$CNg/zDWPG3YVbRkFJ8i9we68QIh4agCJtpGWsf/ihpbk6RMUPIiLK	t	\N	2026-03-18 22:26:54+00	2026-03-18 23:14:50+00
1242a32b-67f2-4e6b-b696-5ccae03aabc3	robi@powerpro.co.id	Robi	$2y$12$M.XBfS94KMisX3AhakA2ZeFOSOUcLDXcm7IbyNnH9.RJCW9OeENlK	t	\N	2026-03-18 22:26:58+00	2026-03-18 23:14:53+00
22d30bba-8bc2-4f47-bdbb-0f4aac0f5785	ridho@powerpro.co.id	Ridho	$2y$12$nDzdMDnDuIH2tOmiinKifeJtbpGM1QOdmU4PG9Kqr865h0OtSQaAu	t	\N	2026-03-18 22:26:57+00	2026-03-18 23:14:52+00
287e0e1b-1a63-434a-be66-394a54d9ebe4	permuser@powerpro.co.id	Perm User	$2y$12$TuJgt3H.unpomyfPxk10juWcEFzc/3Z8/MqKi7gX1fCWRGR8/IHpe	t	\N	2026-03-19 04:25:14+00	2026-03-19 04:25:14+00
55ff30f3-1ace-4939-88c7-5bb0222359a4	yosa@powerpro.co.id	Yosa	$2y$12$WsLMu8Q.n8AimchfTlUC4eIUutKdexvCZNam2I0kJdq0Sb.q/PUQO	t	\N	2026-03-18 22:27:00+00	2026-03-18 23:14:55+00
56390b79-3748-49f3-8831-1c7dcb578772	rama@powerpro.co.id	Rama	$2y$12$7oljMhwXgz/6ZMHp0jl02uTA1gwD9.XjGwlo07bHix05XEhOgdsB.	t	\N	2026-03-18 22:26:56+00	2026-03-18 23:14:52+00
5b7eea2c-c1b6-4283-8c3e-9b64db29c3b5	wahyudi@powerpro.co.id	Yudi	$2y$12$kc349JPcQEJxlvJNzd4YxOd0mb9U47RJWMB1ASoBuQbRVnXa0D2XC	t	\N	2026-03-18 22:27:00+00	2026-03-18 23:14:55+00
61e99596-7868-4467-a7e8-90ecaecd4b8f	nur@powerpro.co.id	Nur	$2y$12$7Ixe6xHumEJ4t88ozsoNbOgtZeJlFVU1DqDNNq2JPgXXBiVbLBvF2	t	\N	2026-03-18 22:26:55+00	2026-03-18 23:14:51+00
66767b13-30fc-4d74-bfc5-6a62e0a413fc	widi@powerpro.co.id	Widi	$2y$12$meR2ldaez5QNItxcDr5pmu63IGbNjZ6XuFK7HTOk2kLW1wQl13Wwy	t	\N	2026-03-18 22:27:00+00	2026-03-18 23:14:54+00
6d2c4318-af44-4731-a0b8-eb3befea9ff6	irvan@powerpro.id	Ivan	$2y$12$4DCcviWkV9ltR4WwpV5oZuwH3.bFX6CmoH.T89DBqW45y.AKH2cAe	t	\N	2026-03-18 22:27:01+00	2026-03-18 23:14:55+00
759ae0a9-d2b1-4b91-abde-2cb530cd072c	naufal@powerpro.co.id	Naufal	$2y$12$0pXd1uSHFQTDlfQw9bi9sOJHh.Xk0ys46qbk3aHNIlCA7IOq9Ska.	t	\N	2026-03-18 22:26:55+00	2026-03-18 23:14:51+00
8d416fea-80ef-4ecf-97d0-6ca06b924091	pradana@powerpro.co.id	Prad	$2y$12$fDFM7znAJDz5ZASyk5Mxz.x7GvcG0YNoSzSOcltO4n0NqIfkAwacm	t	\N	2026-03-18 22:26:56+00	2026-03-18 23:14:51+00
a6ef812d-753b-470f-bffb-976fe7e4ef1e	sahrul@powerpro.co.id	Sahrul	$2y$12$abvGWj476fr1BVDzPrhDWuNAYazRDTnEw5ANnABbP.aFn6Px5N3vG	t	\N	2026-03-18 22:26:58+00	2026-03-18 23:14:53+00
b892a3bf-8eca-4935-8f0d-8f93b4dd9671	account.executive@powerpro.id	Tri	$2y$12$yjoatHBNCKQEkxfaLJEJYeIfLz8zrrjWMACw.kt0ltYrE3/gZDu3.	t	\N	2026-03-18 22:27:01+00	2026-03-18 23:14:55+00
bd8fe829-e0aa-4e8a-80da-1914869e699c	vincent@powerpro.co.id	Vincent	$2y$12$CEVzJ5rxYT.vCmo7LpnT2uSlyC7tJZx9NueXuJAMjQ6GvHP0DDIG2	t	\N	2026-03-18 22:26:59+00	2026-03-18 23:14:54+00
c06bfddc-43fa-4164-a273-91a325d14609	iam@powerpro.co.id	Iam	$2y$12$1keZWriPeOcxW9AiAeEOh.6U/FJ9Jo02imAiMG6CQR2wSFqppIWZW	t	\N	2026-03-18 22:27:01+00	2026-03-18 23:14:56+00
cc5abe29-0605-4d3c-a23a-e7806bb92b54	mulya@powerpro.co.id	Mulya	$2y$12$moCJBpAXpMA5ajM/DfbxqeUTQeSFcVAgyOqPs6lTSWbHH.W8mhXc.	t	\N	2026-03-18 22:26:55+00	2026-03-18 23:14:51+00
d02a8865-a87e-4833-9456-0eb18d07b74c	ilham.tri@powerpro.co.id	Wahyudi	$2y$12$D8n3aUWjkUPiwbtiPXVZLeNESOCpUw5TqP8nIyc3NYD0XxsdE88ZW	t	\N	2026-03-18 22:26:59+00	2026-03-18 23:14:54+00
d95224f6-f0b6-46a3-aee9-52798feeb6c6	rey@powerpro.co.id	Rey	$2y$12$1OzzDPUIs1G79UAU/f1in.acV18OD9nIGfviqp3S6hdLV/d0wY3ve	t	\N	2026-03-18 22:26:57+00	2026-03-18 23:14:52+00
d974b549-7113-4295-978a-9f03b602eda1	rafly@powerpro.co.id	Rafly	$2y$12$rW4qhsMmEnpzngUFx98xIe/4UISMv4zEq0MX7quSnh/N3Mei7A0Tm	t	\N	2026-03-18 22:26:56+00	2026-03-18 23:14:52+00
dcc984d4-0872-4d3e-b65b-6661d9b006a2	rizky@powerpro.co.id	Rizky	$2y$12$RhTZMuBRgXrXn9gKqVyJsenVWpIDN.VEJQOAnlupfiavE5bUm.5Da	t	\N	2026-03-18 22:26:58+00	2026-03-18 23:14:53+00
e40f0ce5-c2cd-4b6a-84d0-d4ed70c8a820	sodek@powerpro.co.id	Sodik	$2y$12$P7YyWBm4AgLq6gEfClJxZuyVXL81WFVh3Ypu28MNRrAm5bLbebwFS	t	\N	2026-03-18 22:26:59+00	2026-03-18 23:14:54+00
e946a4ee-42df-479d-a5d2-23a113ae0e67	ridwan@powerpro.co.id	Ridwan	$2y$12$IoYsSg6v6TCMuH/Vgg950u8PXCtJ1AxSe2CJ4hLwnXhT.h.9k40u2	t	\N	2026-03-18 22:26:57+00	2026-03-18 23:14:53+00
f24dba6c-1fb4-4cef-a595-78ab40b9247d	admin@powerpro.cloud	Admin	$2y$12$ZHEf3G9CSeMKSf7OJ1MFneaIpPKjjKg8gbDMuLeALrUCGLrlc3WQG	t	\N	2026-03-18 22:57:53+00	2026-03-18 23:00:37+00
\.


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: ppm
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 11, true);


--
-- Name: time_boxings_no_seq; Type: SEQUENCE SET; Schema: public; Owner: ppm
--

SELECT pg_catalog.setval('public.time_boxings_no_seq', 1, false);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: arrangement_batches arrangement_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_batches
    ADD CONSTRAINT arrangement_batches_pkey PRIMARY KEY (id);


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_pkey PRIMARY KEY (id);


--
-- Name: arrangement_jobsheet_periods arrangement_jobsheet_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_periods
    ADD CONSTRAINT arrangement_jobsheet_periods_pkey PRIMARY KEY (id);


--
-- Name: arrangement_jobsheet_periods arrangement_jobsheet_periods_slug_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_periods
    ADD CONSTRAINT arrangement_jobsheet_periods_slug_key UNIQUE (slug);


--
-- Name: arrangement_pickups arrangement_pickups_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_pkey PRIMARY KEY (id);


--
-- Name: arrangement_schedules arrangement_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_schedules
    ADD CONSTRAINT arrangement_schedules_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: backup_runs backup_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.backup_runs
    ADD CONSTRAINT backup_runs_pkey PRIMARY KEY (id);


--
-- Name: arrangement_pickups ex_arrangement_pickups_user_overlap; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT ex_arrangement_pickups_user_overlap EXCLUDE USING gist (user_id WITH =, pickup_range WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: health_score_answers health_score_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_answers
    ADD CONSTRAINT health_score_answers_pkey PRIMARY KEY (id);


--
-- Name: health_score_question_options health_score_question_options_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_question_options
    ADD CONSTRAINT health_score_question_options_pkey PRIMARY KEY (id);


--
-- Name: health_score_questions health_score_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_questions
    ADD CONSTRAINT health_score_questions_pkey PRIMARY KEY (id);


--
-- Name: health_score_sections health_score_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_sections
    ADD CONSTRAINT health_score_sections_pkey PRIMARY KEY (id);


--
-- Name: health_score_surveys health_score_surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_pkey PRIMARY KEY (id);


--
-- Name: health_score_surveys health_score_surveys_share_token_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_share_token_key UNIQUE (share_token);


--
-- Name: health_score_templates health_score_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_templates
    ADD CONSTRAINT health_score_templates_pkey PRIMARY KEY (id);


--
-- Name: holidays holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (id);


--
-- Name: lookup_categories lookup_categories_key_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_categories
    ADD CONSTRAINT lookup_categories_key_key UNIQUE (key);


--
-- Name: lookup_categories lookup_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_categories
    ADD CONSTRAINT lookup_categories_pkey PRIMARY KEY (id);


--
-- Name: lookup_values lookup_values_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_values
    ADD CONSTRAINT lookup_values_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: partner_contacts partner_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partner_contacts
    ADD CONSTRAINT partner_contacts_pkey PRIMARY KEY (id);


--
-- Name: partners partners_cnc_id_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_cnc_id_key UNIQUE (cnc_id);


--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_key_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_key_key UNIQUE (key);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: project_pic_assignments project_pic_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: time_boxings time_boxings_no_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_no_key UNIQUE (no);


--
-- Name: time_boxings time_boxings_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_pkey PRIMARY KEY (id);


--
-- Name: arrangement_jobsheet_entries uq_arrangement_jobsheet_entries_period_user_date; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT uq_arrangement_jobsheet_entries_period_user_date UNIQUE (period_id, user_id, work_date);


--
-- Name: arrangement_pickups uq_arrangement_pickups_schedule_id_user_id; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT uq_arrangement_pickups_schedule_id_user_id UNIQUE (schedule_id, user_id);


--
-- Name: health_score_answers uq_health_score_answers_survey_question; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_answers
    ADD CONSTRAINT uq_health_score_answers_survey_question UNIQUE (survey_id, question_id);


--
-- Name: health_score_surveys uq_health_score_surveys_partner_project_year_quarter; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT uq_health_score_surveys_partner_project_year_quarter UNIQUE (partner_id, project_id, year, quarter);


--
-- Name: lookup_values uq_lookup_values_category_id_value; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_values
    ADD CONSTRAINT uq_lookup_values_category_id_value UNIQUE (category_id, value);


--
-- Name: role_permissions uq_role_permissions_role_id_permission_id; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT uq_role_permissions_role_id_permission_id UNIQUE (role_id, permission_id);


--
-- Name: user_roles uq_user_roles_user_id_role_id; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT uq_user_roles_user_id_role_id UNIQUE (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_arrangement_batches_created_by; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_batches_created_by ON public.arrangement_batches USING btree (created_by);


--
-- Name: ix_arrangement_jobsheet_entries_period_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_jobsheet_entries_period_id ON public.arrangement_jobsheet_entries USING btree (period_id);


--
-- Name: ix_arrangement_jobsheet_entries_user_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_jobsheet_entries_user_id ON public.arrangement_jobsheet_entries USING btree (user_id);


--
-- Name: ix_arrangement_jobsheet_entries_user_work_date; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_jobsheet_entries_user_work_date ON public.arrangement_jobsheet_entries USING btree (user_id, work_date);


--
-- Name: ix_arrangement_jobsheet_periods_created_by; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_jobsheet_periods_created_by ON public.arrangement_jobsheet_periods USING btree (created_by);


--
-- Name: ix_arrangement_jobsheet_periods_start_end; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_jobsheet_periods_start_end ON public.arrangement_jobsheet_periods USING btree (start_date, end_date);


--
-- Name: ix_arrangement_pickups_schedule_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_pickups_schedule_id ON public.arrangement_pickups USING btree (schedule_id);


--
-- Name: ix_arrangement_pickups_status_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_pickups_status_id ON public.arrangement_pickups USING btree (status_id);


--
-- Name: ix_arrangement_pickups_user_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_pickups_user_id ON public.arrangement_pickups USING btree (user_id);


--
-- Name: ix_arrangement_schedules_batch_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_schedules_batch_id ON public.arrangement_schedules USING btree (batch_id);


--
-- Name: ix_arrangement_schedules_created_by; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_schedules_created_by ON public.arrangement_schedules USING btree (created_by);


--
-- Name: ix_arrangement_schedules_status_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_arrangement_schedules_status_id ON public.arrangement_schedules USING btree (status_id);


--
-- Name: ix_audit_logs_action; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_audit_logs_action ON public.audit_logs USING btree (action);


--
-- Name: ix_audit_logs_actor_created_at; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_audit_logs_actor_created_at ON public.audit_logs USING btree (actor_user_id, created_at);


--
-- Name: ix_audit_logs_entity_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_audit_logs_entity_id ON public.audit_logs USING btree (entity_id);


--
-- Name: ix_audit_logs_entity_type; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_audit_logs_entity_type ON public.audit_logs USING btree (entity_type);


--
-- Name: ix_audit_logs_entity_type_entity_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_audit_logs_entity_type_entity_id ON public.audit_logs USING btree (entity_type, entity_id);


--
-- Name: ix_backup_runs_requested_by; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_backup_runs_requested_by ON public.backup_runs USING btree (requested_by);


--
-- Name: ix_backup_runs_status; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_backup_runs_status ON public.backup_runs USING btree (status);


--
-- Name: ix_health_score_answers_question_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_answers_question_id ON public.health_score_answers USING btree (question_id);


--
-- Name: ix_health_score_answers_survey_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_answers_survey_id ON public.health_score_answers USING btree (survey_id);


--
-- Name: ix_health_score_question_options_question_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_question_options_question_id ON public.health_score_question_options USING btree (question_id);


--
-- Name: ix_health_score_questions_section_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_questions_section_id ON public.health_score_questions USING btree (section_id);


--
-- Name: ix_health_score_sections_template_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_sections_template_id ON public.health_score_sections USING btree (template_id);


--
-- Name: ix_health_score_surveys_template_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_health_score_surveys_template_id ON public.health_score_surveys USING btree (template_id);


--
-- Name: ix_messages_recipient_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_messages_recipient_id ON public.messages USING btree (recipient_id);


--
-- Name: ix_messages_recipient_read_created; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_messages_recipient_read_created ON public.messages USING btree (recipient_id, read_at, created_at);


--
-- Name: ix_messages_sender_created; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_messages_sender_created ON public.messages USING btree (sender_id, created_at);


--
-- Name: ix_messages_sender_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_messages_sender_id ON public.messages USING btree (sender_id);


--
-- Name: ix_notifications_user_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: ix_notifications_user_read_created; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_notifications_user_read_created ON public.notifications USING btree (user_id, read_at, created_at);


--
-- Name: ix_partner_contacts_partner_id_role_key; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_partner_contacts_partner_id_role_key ON public.partner_contacts USING btree (partner_id, role_key);


--
-- Name: ix_project_pic_assignments_pic_user_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_project_pic_assignments_pic_user_id ON public.project_pic_assignments USING btree (pic_user_id);


--
-- Name: ix_project_pic_assignments_project_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_project_pic_assignments_project_id ON public.project_pic_assignments USING btree (project_id);


--
-- Name: ix_projects_partner_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_projects_partner_id ON public.projects USING btree (partner_id);


--
-- Name: ix_time_boxings_deleted_at; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_deleted_at ON public.time_boxings USING btree (deleted_at);


--
-- Name: ix_time_boxings_due_date; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_due_date ON public.time_boxings USING btree (due_date);


--
-- Name: ix_time_boxings_partner_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_partner_id ON public.time_boxings USING btree (partner_id);


--
-- Name: ix_time_boxings_project_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_project_id ON public.time_boxings USING btree (project_id);


--
-- Name: ix_time_boxings_status_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_status_id ON public.time_boxings USING btree (status_id);


--
-- Name: ix_time_boxings_user_id; Type: INDEX; Schema: public; Owner: ppm
--

CREATE INDEX ix_time_boxings_user_id ON public.time_boxings USING btree (user_id);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: ppm
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: arrangement_pickups trg_arrangement_pickups_sync_dates; Type: TRIGGER; Schema: public; Owner: ppm
--

CREATE TRIGGER trg_arrangement_pickups_sync_dates BEFORE INSERT OR UPDATE OF schedule_id ON public.arrangement_pickups FOR EACH ROW EXECUTE FUNCTION public.sync_arrangement_pickup_dates();


--
-- Name: arrangement_schedules trg_arrangement_schedules_propagate_dates; Type: TRIGGER; Schema: public; Owner: ppm
--

CREATE TRIGGER trg_arrangement_schedules_propagate_dates AFTER UPDATE OF start_date, end_date ON public.arrangement_schedules FOR EACH ROW EXECUTE FUNCTION public.propagate_arrangement_schedule_dates();


--
-- Name: arrangement_batches arrangement_batches_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_batches
    ADD CONSTRAINT arrangement_batches_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: arrangement_batches arrangement_batches_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_batches
    ADD CONSTRAINT arrangement_batches_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_batches arrangement_batches_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_batches
    ADD CONSTRAINT arrangement_batches_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_code_id_fkey FOREIGN KEY (code_id) REFERENCES public.lookup_values(id);


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_period_id_fkey FOREIGN KEY (period_id) REFERENCES public.arrangement_jobsheet_periods(id) ON DELETE CASCADE;


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_jobsheet_entries arrangement_jobsheet_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_entries
    ADD CONSTRAINT arrangement_jobsheet_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_jobsheet_periods arrangement_jobsheet_periods_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_jobsheet_periods
    ADD CONSTRAINT arrangement_jobsheet_periods_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_pickups arrangement_pickups_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: arrangement_pickups arrangement_pickups_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.users(id);


--
-- Name: arrangement_pickups arrangement_pickups_picked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_picked_by_fkey FOREIGN KEY (picked_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_pickups arrangement_pickups_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES public.arrangement_schedules(id) ON DELETE CASCADE;


--
-- Name: arrangement_pickups arrangement_pickups_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: arrangement_pickups arrangement_pickups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_pickups
    ADD CONSTRAINT arrangement_pickups_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_schedules arrangement_schedules_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_schedules
    ADD CONSTRAINT arrangement_schedules_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.arrangement_batches(id) ON DELETE SET NULL;


--
-- Name: arrangement_schedules arrangement_schedules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_schedules
    ADD CONSTRAINT arrangement_schedules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: arrangement_schedules arrangement_schedules_schedule_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_schedules
    ADD CONSTRAINT arrangement_schedules_schedule_type_id_fkey FOREIGN KEY (schedule_type_id) REFERENCES public.lookup_values(id);


--
-- Name: arrangement_schedules arrangement_schedules_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.arrangement_schedules
    ADD CONSTRAINT arrangement_schedules_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: backup_runs backup_runs_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.backup_runs
    ADD CONSTRAINT backup_runs_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: health_score_answers health_score_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_answers
    ADD CONSTRAINT health_score_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.health_score_questions(id) ON DELETE RESTRICT;


--
-- Name: health_score_answers health_score_answers_selected_option_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_answers
    ADD CONSTRAINT health_score_answers_selected_option_id_fkey FOREIGN KEY (selected_option_id) REFERENCES public.health_score_question_options(id) ON DELETE SET NULL;


--
-- Name: health_score_answers health_score_answers_survey_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_answers
    ADD CONSTRAINT health_score_answers_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES public.health_score_surveys(id) ON DELETE CASCADE;


--
-- Name: health_score_question_options health_score_question_options_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_question_options
    ADD CONSTRAINT health_score_question_options_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.health_score_questions(id) ON DELETE CASCADE;


--
-- Name: health_score_questions health_score_questions_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_questions
    ADD CONSTRAINT health_score_questions_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.health_score_sections(id) ON DELETE CASCADE;


--
-- Name: health_score_sections health_score_sections_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_sections
    ADD CONSTRAINT health_score_sections_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.health_score_templates(id) ON DELETE CASCADE;


--
-- Name: health_score_surveys health_score_surveys_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: health_score_surveys health_score_surveys_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: health_score_surveys health_score_surveys_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: health_score_surveys health_score_surveys_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_surveys
    ADD CONSTRAINT health_score_surveys_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.health_score_templates(id) ON DELETE RESTRICT;


--
-- Name: health_score_templates health_score_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.health_score_templates
    ADD CONSTRAINT health_score_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: lookup_values lookup_values_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_values
    ADD CONSTRAINT lookup_values_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.lookup_categories(id) ON DELETE CASCADE;


--
-- Name: lookup_values lookup_values_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.lookup_values
    ADD CONSTRAINT lookup_values_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.lookup_values(id) ON DELETE SET NULL;


--
-- Name: messages messages_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: notifications notifications_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: partner_contacts partner_contacts_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partner_contacts
    ADD CONSTRAINT partner_contacts_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: partners partners_implementation_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_implementation_type_id_fkey FOREIGN KEY (implementation_type_id) REFERENCES public.lookup_values(id);


--
-- Name: partners partners_partner_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_partner_group_id_fkey FOREIGN KEY (partner_group_id) REFERENCES public.lookup_values(id);


--
-- Name: partners partners_partner_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_partner_type_id_fkey FOREIGN KEY (partner_type_id) REFERENCES public.lookup_values(id);


--
-- Name: partners partners_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: partners partners_system_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_system_version_id_fkey FOREIGN KEY (system_version_id) REFERENCES public.lookup_values(id);


--
-- Name: project_pic_assignments project_pic_assignments_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.lookup_values(id);


--
-- Name: project_pic_assignments project_pic_assignments_pic_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_pic_user_id_fkey FOREIGN KEY (pic_user_id) REFERENCES public.users(id);


--
-- Name: project_pic_assignments project_pic_assignments_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_pic_assignments project_pic_assignments_release_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_release_state_id_fkey FOREIGN KEY (release_state_id) REFERENCES public.lookup_values(id);


--
-- Name: project_pic_assignments project_pic_assignments_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.project_pic_assignments
    ADD CONSTRAINT project_pic_assignments_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: projects projects_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE RESTRICT;


--
-- Name: projects projects_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: projects projects_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.lookup_values(id);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: time_boxings time_boxings_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: time_boxings time_boxings_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: time_boxings time_boxings_priority_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_priority_id_fkey FOREIGN KEY (priority_id) REFERENCES public.lookup_values(id);


--
-- Name: time_boxings time_boxings_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: time_boxings time_boxings_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.lookup_values(id);


--
-- Name: time_boxings time_boxings_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.lookup_values(id);


--
-- Name: time_boxings time_boxings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.time_boxings
    ADD CONSTRAINT time_boxings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ppm
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict qtn8wLnnZYivi790bfKDW9KwAENAQA1pUumMjznR1l9rki9JHczoW3ehdaPkeml

