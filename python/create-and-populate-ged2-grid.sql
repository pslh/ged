--
-- Setup basic environment
--
SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = ged2, paul, public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Remove any old data
--
DROP TABLE IF EXISTS ged2.grid_point;

--
-- Create table without geometry
--
CREATE TABLE ged2.grid_point (
    id integer  PRIMARY KEY NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    pop_value double precision NOT NULL,
    is_urban boolean NOT NULL,
    land_area double precision NOT NULL
);


--
-- Load data from csv
--
-- COPY ged2.grid_point(id, lat, lon, pop_value, is_urban,land_area) FROM '/home/pslh/experiments/ged/python/test.csv';

COPY ged2.grid_point(id, lat, lon, pop_value, is_urban,land_area) FROM '/home/pslh/experiments/ged/python/gridded-pop-20130219.out';

--
-- Add the_geom, populate and generate index
--
SELECT AddGeometryColumn ('ged2','grid_point','the_geom',4326,'POINT',2);
UPDATE ged2.grid_point SET the_geom=ST_SetSRID(ST_Point(lon,lat),4326);
CREATE INDEX ged2_grid_point_the_geom ON grid_point USING gist (the_geom);

--select * from ged2.grid_point ;
