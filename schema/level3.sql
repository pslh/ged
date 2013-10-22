--
-- PostgreSQL database dump
--
SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: idct; Type: SCHEMA; Schema: -; Owner: paul
--

CREATE SCHEMA level3;


ALTER SCHEMA level3 OWNER TO paul;

SET search_path = level3, pg_catalog;

SET default_tablespace = 'level3_ts';

SET default_with_oids = false;

--
-- Name: project; Type: TABLE; Schema: level3; Owner: paul; Tablespace: 
--

CREATE TABLE level3.project (
    proj_uid character varying NOT NULL PRIMARY KEY,
    proj_name character varying,
    proj_date character varying,
    hazrd_type character varying,
    proj_locle character varying,
    hazrd_name character varying,
    proj_sumry character varying,
    comment character varying,
    epsg_code character varying,
    date_made character varying,
    user_made character varying,
    date_chng character varying,
    user_chng character varying
) TABLESPACE level3_ts;

ALTER TABLE level3.project OWNER TO paul;

--
-- Name: object; Type: TABLE; Schema: level3; Owner: paul; Tablespace: 
--
CREATE TABLE level3.object (
    obj_uid character varying NOT NULL PRIMARY KEY,
    proj_uid character varying NOT NULL REFERENCES level3.project(proj_uid),
    x double precision,
    y double precision,
    source character varying,
    comments character varying,
    plan_shape character varying,
    "position" character varying,
    nonstrcexw character varying,
    roof_conn character varying,
    roofsysmat character varying,
    roofcovmat character varying,
    roof_shape character varying,
    roofsystyp character varying,
    mas_mort_l character varying,
    mas_mort_t character varying,
    mas_rein_l character varying,
    mas_rein_t character varying,
    mat_tech_l character varying,
    mat_tech_t character varying,
    mat_type_l character varying,
    mat_type_t character varying,
    steelcon_l character varying,
    steelcon_t character varying,
    llrs_qual character varying,
    llrs_l character varying,
    llrs_t character varying,
    llrs_dct_l character varying,
    llrs_dct_t character varying,
    str_hzir_p character varying,
    str_hzir_s character varying,
    str_veir_p character varying,
    str_veir_s character varying,
    str_irreg character varying,
    floor_conn character varying,
    floor_mat character varying,
    floor_type character varying,
    foundn_sys character varying,
    story_ag_q character varying,
    story_ag_1 integer,
    story_ag_2 integer,
    story_bg_q character varying,
    story_bg_1 integer,
    story_bg_2 integer,
    ht_gr_gf_q character varying,
    ht_gr_gf_1 integer,
    ht_gr_gf_2 integer,
    slope integer,
    yr_built_q character varying,
    yr_built_1 integer,
    yr_built_2 integer,
    yr_retro integer,
    occupcy character varying,
    occupcy_dt character varying,
    sample_grp character varying,
    direct_1 integer,
    direct_2 integer,
    date_made character varying,
    user_made character varying,
    date_chng character varying,
    user_chng character varying
) TABLESPACE level3_ts;

ALTER TABLE level3.object OWNER TO paul;

--
-- Name: object_use; Type: TABLE; Schema: level3; Owner: paul; Tablespace: 
--
CREATE TABLE level3.object_use (
    id SERIAL NOT NULL PRIMARY KEY,
    obj_uid character varying NOT NULL REFERENCES level3.object(obj_uid),
    day_occ integer,
    night_occ integer,
    trans_occ integer,
    num_dwell integer,
    plan_area double precision,
    replc_cost double precision,
    currency character varying,
    cost_date character varying,
    comments character varying,
    date_made character varying,
    user_made character varying,
    date_chng character varying,
    user_chng character varying
) TABLESPACE level3_ts;

ALTER TABLE level3.object_use OWNER TO paul;



--
-- Name: media_detail; Type: TABLE; Schema: level3; Owner: paul; Tablespace: 
--

CREATE TABLE media_detail (
    media_uid character varying NOT NULL PRIMARY KEY,
    obj_uid character varying NOT NULL REFERENCES level3.object(obj_uid),
    media_type character varying NOT NULL,
    comments character varying,
    filename character varying,
    media_numb integer,
    orig_filen character varying,
    date_made character varying,
    user_made character varying,
    date_chng character varying,
    user_chng character varying
);


ALTER TABLE level3.media_detail OWNER TO paul;


CREATE TABLE level3.contribution (
	id 		SERIAL PRIMARY KEY,
	proj_uid 	VARCHAR NOT NULL REFERENCES level3.project(proj_uid),
	proj_source 	VARCHAR, 
	proj_date	DATE,
	notes		TEXT
) TABLESPACE level3_ts;
