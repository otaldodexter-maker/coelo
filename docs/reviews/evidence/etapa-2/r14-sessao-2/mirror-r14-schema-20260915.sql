--
-- PostgreSQL database dump
--

\restrict kH0BKzYbeGFQImIBVK2Jp7le9URXA48ZdPOjd3YESPlP4jRUso7DB9qAbrql9B8

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

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
-- Name: global_type_catalogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.global_type_catalogs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    entity_type text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_other boolean DEFAULT false NOT NULL,
    requires_free_text boolean DEFAULT false NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT global_type_catalogs_code_not_blank CHECK ((btrim(code) <> ''::text)),
    CONSTRAINT global_type_catalogs_entity_type_check CHECK ((entity_type = ANY (ARRAY['institution'::text, 'unit'::text, 'group'::text, 'activity'::text]))),
    CONSTRAINT global_type_catalogs_label_not_blank CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT global_type_catalogs_other_text_check CHECK (((NOT is_other) OR requires_free_text)),
    CONSTRAINT global_type_catalogs_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])))
);

ALTER TABLE ONLY public.global_type_catalogs FORCE ROW LEVEL SECURITY;


--
-- Name: health_care_allergies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_care_allergies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    label text NOT NULL,
    allergy_type text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    last_episode_at timestamp with time zone,
    episode_severity text,
    observed_reaction text DEFAULT ''::text NOT NULL,
    guidance text DEFAULT ''::text NOT NULL,
    notes text DEFAULT ''::text NOT NULL,
    inactivated_at timestamp with time zone,
    inactivation_reason text,
    created_by_person_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT health_care_allergies_allergy_type_check CHECK ((allergy_type = ANY (ARRAY['medication'::text, 'food'::text, 'restriction'::text, 'other'::text]))),
    CONSTRAINT health_care_allergies_episode_severity_check CHECK ((episode_severity = ANY (ARRAY['mild'::text, 'moderate'::text, 'severe'::text]))),
    CONSTRAINT health_care_allergies_inactivation_check CHECK (((active AND (inactivated_at IS NULL) AND (inactivation_reason IS NULL)) OR ((NOT active) AND (inactivated_at IS NOT NULL) AND (inactivation_reason IS NOT NULL) AND (btrim(inactivation_reason) <> ''::text)))),
    CONSTRAINT health_care_allergies_label_check CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT health_care_allergies_severity_check CHECK (((episode_severity IS NULL) OR (last_episode_at IS NOT NULL))),
    CONSTRAINT health_care_allergies_status_check CHECK ((status = ANY (ARRAY['active'::text, 'monitoring'::text, 'history'::text])))
);

ALTER TABLE ONLY public.health_care_allergies FORCE ROW LEVEL SECURITY;


--
-- Name: health_care_profile_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_care_profile_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    catalog_item_id text NOT NULL,
    other_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT health_care_profile_items_catalog_item_id_check CHECK ((catalog_item_id ~ '^[a-z][a-z0-9_]*$'::text)),
    CONSTRAINT health_care_profile_items_other_check CHECK ((((catalog_item_id = 'other'::text) AND (other_text IS NOT NULL) AND (btrim(other_text) <> ''::text)) OR ((catalog_item_id <> 'other'::text) AND (other_text IS NULL))))
);

ALTER TABLE ONLY public.health_care_profile_items FORCE ROW LEVEL SECURITY;


--
-- Name: global_type_catalogs global_type_catalogs_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_type_catalogs
    ADD CONSTRAINT global_type_catalogs_code_unique UNIQUE (code);


--
-- Name: global_type_catalogs global_type_catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_type_catalogs
    ADD CONSTRAINT global_type_catalogs_pkey PRIMARY KEY (id);


--
-- Name: health_care_allergies health_care_allergies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_allergies
    ADD CONSTRAINT health_care_allergies_pkey PRIMARY KEY (id);


--
-- Name: health_care_profile_items health_care_profile_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_profile_items
    ADD CONSTRAINT health_care_profile_items_pkey PRIMARY KEY (id);


--
-- Name: health_care_profile_items health_care_profile_items_profile_id_catalog_item_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_profile_items
    ADD CONSTRAINT health_care_profile_items_profile_id_catalog_item_id_key UNIQUE (profile_id, catalog_item_id);


--
-- Name: global_type_catalogs_entity_sort_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX global_type_catalogs_entity_sort_uidx ON public.global_type_catalogs USING btree (entity_type, sort_order, code);


--
-- Name: health_care_allergies_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_care_allergies_profile_idx ON public.health_care_allergies USING btree (profile_id, active, status);


--
-- Name: health_care_allergies health_care_allergies_collection_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER health_care_allergies_collection_limit AFTER INSERT OR UPDATE OF profile_id ON public.health_care_allergies DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION app_private.health_care_collection_limit_guard();


--
-- Name: health_care_profile_items health_care_profile_items_collection_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER health_care_profile_items_collection_limit AFTER INSERT OR UPDATE OF profile_id ON public.health_care_profile_items DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION app_private.health_care_collection_limit_guard();


--
-- Name: health_care_allergies health_care_allergies_created_by_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_allergies
    ADD CONSTRAINT health_care_allergies_created_by_person_id_fkey FOREIGN KEY (created_by_person_id) REFERENCES public.people(id) ON DELETE RESTRICT;


--
-- Name: health_care_allergies health_care_allergies_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_allergies
    ADD CONSTRAINT health_care_allergies_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.health_care_profiles(id) ON DELETE CASCADE;


--
-- Name: health_care_profile_items health_care_profile_items_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_care_profile_items
    ADD CONSTRAINT health_care_profile_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.health_care_profiles(id) ON DELETE CASCADE;


--
-- Name: global_type_catalogs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.global_type_catalogs ENABLE ROW LEVEL SECURITY;

--
-- Name: global_type_catalogs global_type_catalogs_platform_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY global_type_catalogs_platform_read ON public.global_type_catalogs FOR SELECT TO authenticated USING (app_private.has_platform_permission('platform.read'::text));


--
-- Name: health_care_allergies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.health_care_allergies ENABLE ROW LEVEL SECURITY;

--
-- Name: health_care_allergies health_care_allergies_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY health_care_allergies_read ON public.health_care_allergies FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.health_care_profiles profile_row
  WHERE ((profile_row.id = health_care_allergies.profile_id) AND app_private.health_care_scope_allowed('health_care.read'::text, profile_row.institution_id, NULL::uuid, NULL::uuid, profile_row.child_context_id)))));


--
-- Name: health_care_profile_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.health_care_profile_items ENABLE ROW LEVEL SECURITY;

--
-- Name: health_care_profile_items health_care_profile_items_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY health_care_profile_items_read ON public.health_care_profile_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.health_care_profiles profile_row
  WHERE ((profile_row.id = health_care_profile_items.profile_id) AND app_private.health_care_scope_allowed('health_care.read'::text, profile_row.institution_id, NULL::uuid, NULL::uuid, profile_row.child_context_id)))));


--
-- PostgreSQL database dump complete
--

\unrestrict kH0BKzYbeGFQImIBVK2Jp7le9URXA48ZdPOjd3YESPlP4jRUso7DB9qAbrql9B8

