--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = paul, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: grump_pop_ur; Type: TABLE; Schema: paul; Owner: paul; Tablespace: 
--
CREATE TABLE grump_pop_ur2 (
    id serial  PRIMARY KEY NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    pop_value double precision NOT NULL,
    is_urban boolean ,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 4326))
);



--
-- Name: paul_grump_pop_ur_the_geom; Type: INDEX; Schema: paul; Owner: paul; Tablespace: 
--

-- CREATE INDEX paul_grump_pop_ur_the_geom ON grump_pop_ur USING gist (the_geom);

