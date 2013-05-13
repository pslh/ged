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
-- Name: ged2; Type: SCHEMA; Schema: -; Owner: paul
--

CREATE SCHEMA ged2;


ALTER SCHEMA ged2 OWNER TO paul;

SET search_path = ged2, pg_catalog;

--
-- Name: closest_region_t; Type: TYPE; Schema: ged2; Owner: paul
--

CREATE TYPE closest_region_t AS (
	gadm_oid integer,
	gadm_id_0 integer,
	gadm_id_1 integer,
	gadm_id_2 integer,
	gadm_id_3 integer,
	distance double precision
);


ALTER TYPE ged2.closest_region_t OWNER TO paul;

--
-- Name: proportion; Type: DOMAIN; Schema: ged2; Owner: paul
--

CREATE DOMAIN proportion AS double precision
	CONSTRAINT proportion_check CHECK (((VALUE >= (0)::double precision) AND (VALUE <= (1)::double precision)));


ALTER DOMAIN ged2.proportion OWNER TO paul;

--
-- Name: build_study_region(numeric); Type: FUNCTION; Schema: ged2; Owner: zh
--

CREATE FUNCTION build_study_region(in_study_region_id numeric) RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
DECLARE  
	distribution_record RECORD;
	pop_summary RECORD;	
BEGIN
	-- entry function to generate output CSV file for a given study region  
	-- version 0.2
	-- by ZhengHui Hu
	-- last updated: 2013-04-08
   
	FOR distribution_record IN
		SELECT r.id as study_region_id, g.id as distribution_group_id, g.is_urban, g.occupancy_id,
		    r.geographic_region_id, geo.gadm_country_id as gadm_country_id, geo.gadm_admin_1_id, 
		    geo.gadm_admin_2_id, geo.gadm_admin_3_id, geo.custom_geography_id,
		    tot_pop, tot_num_dwellings, tot_num_buildings, avg_peop_dwelling, avg_floor_capita, avg_peop_building, avg_dwelling_area            
			FROM ged2.study_region r 
			INNER JOIN ged2.distribution_group g ON r.id=g.study_region_id
		    LEFT JOIN ged2.study_region_facts rf on g.id = rf.distribution_group_id
		    INNER JOIN ged2.geographic_region geo on r.geographic_region_id=geo.id
		    where r.id=in_study_region_id
	LOOP
		-- load all grid points
		drop table if exists tmp_grid_points;
		if distribution_record.custom_geography_id is not null then
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point p inner join ged2.custom_geography g on contains(transform(g.the_geom, 4326), transform(p.the_geom, 4326));
		elsif distribution_record.gadm_admin_3_id is not null then
		    create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_admin_3_id = distribution_record.gadm_admin_3_id;
		elsif distribution_record.gadm_admin_2_id is not null then
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_admin_2_id = distribution_record.gadm_admin_2_id;
		elsif distribution_record.gadm_admin_1_id is not null then
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_admin_1_id = distribution_record.gadm_admin_1_id;
		else
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_country_id = distribution_record.gadm_country_id;
		end if;

		-- get total population count
		select sum(pop_value) as total_population, count(*) as total_grid_count from tmp_grid_points t into pop_summary;
		raise notice 'grid_summary %', pop_summary;
		
-- 		-- temporary, should be loaded from updates DB schema
-- 		drop table if exists tmp_study_region_facts;
-- 		create temporary TABLE tmp_study_region_facts as
-- 		select * from ged2.study_region_facts where distribution_group_id=distribution_record.distribution_group_id;	
-- 
-- 		drop table if exists tmp_bldg_distribution;	
--  		CREATE temporary TABLE tmp_bldg_distribution as
-- 		select * from ged2.distribution_value 
-- 		    where distribution_group_id= distribution_record.distribution_group_id;
		
		return QUERY select ged2.make_exposure_pgsql(
				g.grid_point_id::bigint, g.lat, g.lon, 
				g.is_urban, g.pop_value, 
				pop_summary.total_population,
				intermediate.ms_sum_fraction_over_dwellings,
				pa.*,	-- pop_allocation
				sf.*::ged2.study_region_facts, 	-- study_region_facts
				dv.*::ged2.distribution_value)	-- dist_values				
			from tmp_grid_points g 			
			inner join ged2.pop_allocation pa on g.is_urban=pa.is_urban and pa.geographic_region_id=distribution_record.geographic_region_id and pa.is_urban=distribution_record.is_urban and pa.occupancy_id = distribution_record.occupancy_id
			left join ged2.study_region_facts sf on sf.distribution_group_id=distribution_record.distribution_group_id
			left join ged2.distribution_value dv on dv.distribution_group_id=distribution_record.distribution_group_id
			inner join 
				(select distribution_group_id, sum( case when avg_dwelling_per_build > 0 then dwelling_fraction / avg_dwelling_per_build else 0 end ) ms_sum_fraction_over_dwellings
				from ged2.distribution_value where distribution_group_id = distribution_record.distribution_group_id
				group by distribution_group_id) intermediate on intermediate.distribution_group_id = distribution_record.distribution_group_id;
	END LOOP;
	-- running the script
	-- copy (select ged2.build_study_region(252)) to '/home/zhu/population_scripts/output.csv';
	-- select ged2.build_study_region(15) limit 10;
END;
$$;


ALTER FUNCTION ged2.build_study_region(in_study_region_id numeric) OWNER TO zh;

--
-- Name: closest_gadm_region(public.geometry); Type: FUNCTION; Schema: ged2; Owner: paul
--

CREATE FUNCTION closest_gadm_region(grid_point_geom public.geometry) RETURNS closest_region_t
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
  sql     TEXT;
  ret     paul.closest_region;
BEGIN
  sql := ' SELECT gadm.objectid, gadm.id_0, gadm.id_1, gadm.id_2, gadm.id_3, ST_Distance(gadm.the_geom, $1) AS dist '
      || ' FROM ged2.gadm2 gadm'
      || ' WHERE ST_DWithin($1, the_geom, $2 * ($3 ^ $4))'
      || ' ORDER BY dist'
      || ' LIMIT 1';
  FOR i IN 0..10 LOOP
    EXECUTE sql INTO ret USING grid_point_geom , 0.0043 , 2 , i;
    IF ret.gadm_oid IS NOT NULL
    THEN
        RETURN ret;
    END IF;
  END LOOP;
  RETURN NULL;
END
$_$;


ALTER FUNCTION ged2.closest_gadm_region(grid_point_geom public.geometry) OWNER TO paul;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: distribution_value; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE distribution_value (
    id integer NOT NULL,
    distribution_group_id integer NOT NULL,
    building_type character varying NOT NULL,
    building_fraction double precision,
    dwelling_fraction double precision,
    replace_cost_per_area double precision,
    avg_dwelling_per_build double precision,
    avg_floor_area double precision
);


ALTER TABLE ged2.distribution_value OWNER TO paul;

--
-- Name: pop_allocation; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE pop_allocation (
    id integer NOT NULL,
    geographic_region_id integer NOT NULL,
    is_urban boolean NOT NULL,
    occupancy_id integer NOT NULL,
    day_pop_ratio proportion NOT NULL,
    night_pop_ratio proportion NOT NULL,
    transit_pop_ratio proportion NOT NULL
);


ALTER TABLE ged2.pop_allocation OWNER TO paul;

--
-- Name: study_region_facts; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE study_region_facts (
    distribution_group_id integer NOT NULL,
    tot_num_dwellings integer,
    tot_num_dwellings_source character varying,
    tot_num_dwellings_date date,
    tot_num_buildings integer,
    tot_num_buildings_source character varying,
    tot_num_buildings_date date,
    avg_peop_dwelling double precision,
    avg_peop_dwelling_source character varying,
    avg_peop_dwelling_date date,
    avg_peop_building double precision,
    avg_peop_building_source character varying,
    avg_peop_building_date date,
    avg_floor_capita double precision,
    avg_floor_capita_source character varying,
    avg_floor_capita_date date,
    avg_dwelling_area double precision,
    avg_dwelling_area_source character varying,
    avg_dwelling_area_date date,
    id integer NOT NULL
);


ALTER TABLE ged2.study_region_facts OWNER TO paul;

--
-- Name: make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, pop_allocation, study_region_facts, distribution_value); Type: FUNCTION; Schema: ged2; Owner: zh
--

CREATE FUNCTION make_exposure_pgsql(grid_id bigint, lat double precision, lon double precision, is_urban boolean, pop_value double precision, tot_pop double precision, ms_sum_fraction_over_dwellings double precision, pop_alloc pop_allocation, study_region_facts study_region_facts, dist_values distribution_value) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  bldg_type character varying(50);
  occ_type  character varying(50);
  dwelling_fraction float;
  bldg_fraction float;
  type_pop float;
  day_pop float;
  night_pop float;
  transit_pop float;

  total_bldgs  float;
  dwellings_count float;
  
  bldg_count float;
  bldg_count_quality integer;
  bldg_area float;
  bldg_area_quality integer;
  bldg_cost float;
  bldg_cost_quality integer;
BEGIN	

   -- generate building count using algorithm defined in document
   -- 'UNIPV_USGS_revised_procedure_1.5.doc'    
   -- version 0.2
   -- by ZhengHui Hu
   -- last updated: 2013-04-08

   bldg_type = dist_values.building_type;
   occ_type = pop_alloc.occupancy_id;
   dwelling_fraction = dist_values.dwelling_fraction;
   -- population used to calculate building count
   -- based on communication with HC, use total population 
   type_pop = pop_value * dwelling_fraction;
   day_pop = pop_value * dwelling_fraction * pop_alloc.day_pop_ratio;
   night_pop = pop_value * dwelling_fraction * pop_alloc.night_pop_ratio;
   transit_pop = pop_value * dwelling_fraction * pop_alloc.transit_pop_ratio;

   total_bldgs=-1;
   dwellings_count = -1;
   
   bldg_count = -1;
   bldg_count_quality = 0;
   bldg_area = -1;
   bldg_area_quality = 0;
   bldg_cost = -1;
   bldg_cost_quality = 0;
      
   bldg_fraction = 0;

   -- calculate building count

   -- method 5 (best quality)
   if (bldg_count = -1 and  					-- bldg count not set
       study_region_facts.tot_num_buildings is not null		-- required parameter exists	
       and dist_values.building_fraction is not null) then
      -- do calculation
      total_bldgs = (pop_value / tot_pop) * study_region_facts.tot_num_buildings;
      bldg_count = total_bldgs * dist_values.building_fraction;
      bldg_count_quality = 5;

   -- method 4 
   elsif (bldg_count = -1 and  					-- bldg count not set
       study_region_facts.tot_num_buildings is not null and 		-- required parameter exists
       tot_pop is not null and
       dwelling_fraction is not null and
       dist_values.avg_dwelling_per_build is not null and
       ms_sum_fraction_over_dwellings <> 0) then		-- sum(dwelling_fraction/average_bldg_per_bldg)
      -- do calculation
      total_bldgs = (pop_value / tot_pop) * study_region_facts.tot_num_buildings;
      if (dist_values.building_fraction is not null) then
         bldg_fraction = dist_values.building_fraction;
      else
         bldg_fraction = (dwelling_fraction / dist_values.avg_dwelling_per_build ) / ms_sum_fraction_over_dwellings; 
      end if;
      bldg_count = total_bldgs * bldg_fraction;
      bldg_count_quality = 4;

   -- method 3
   elsif (bldg_count = -1 and  					-- bldg count not set
       study_region_facts.tot_num_dwellings is not null and		-- required parameter exists
       tot_pop is not null and
       dist_values.avg_dwelling_per_build is not null) then
      -- do calculation
      dwellings_count = (pop_value / tot_pop) * study_region_facts.tot_num_dwellings * dwelling_fraction;      
      bldg_count = dwellings_count / dist_values.avg_dwelling_per_build;      
      bldg_count_quality = 3;

   -- method 2 
   elsif (bldg_count = -1 and  					-- bldg count not set
       study_region_facts.avg_peop_dwelling is not null and 		-- required parameter exists
       dist_values.avg_dwelling_per_build is not null) then
      -- do calculation
      dwellings_count = (pop_value * dwelling_fraction) / study_region_facts.avg_peop_dwelling;
      bldg_count = dwellings_count / dist_values.avg_dwelling_per_build;
      bldg_count_quality = 2;
   
   -- method 1
   elsif (bldg_count = -1 and  					-- bldg count not set
       study_region_facts.avg_peop_building is not null	and		-- required parameter exists
       dwelling_fraction is not null and
       ms_sum_fraction_over_dwellings <> 0 ) then		-- sum(dwelling_fraction/average_bldg_per_bldg)
      -- do calculation
      total_bldgs = (pop_value) / study_region_facts.avg_peop_building;
      if (dist_values.building_fraction is not null) then
         bldg_fraction = dist_values.building_fraction;
      else
	bldg_fraction = (dwelling_fraction / dist_values.avg_dwelling_per_build ) / ms_sum_fraction_over_dwellings; 
      end if;
      bldg_count = total_bldgs * bldg_fraction;
      bldg_count_quality = 1;

   -- error ?, set to 0
   else
      bldg_count = 0;
      bldg_count_quality = 0;

   end if;
   
   -- calculate building area
   -- method 3
   if (bldg_area = -1 and 					-- bldg area not set
       bldg_count is not null and 				-- required parameter exists
       dist_values.avg_floor_area is not null) then
      -- do calculation
      bldg_area = bldg_count * dist_values.avg_floor_area;
      bldg_area_quality = bldg_count_quality;

   -- method 2
   elsif (bldg_area = -1 					-- bldg area not set
       and dwellings_count <> -1 and 				-- required parameter exists
       study_region_facts.avg_dwelling_area is not null) then 
      -- do calculation      
      bldg_area = dwellings_count * study_region_facts.avg_dwelling_area;
      bldg_area_quality = bldg_count_quality;

   -- method 1
   elsif (bldg_area = -1 and 					-- bldg area not set
       study_region_facts.avg_floor_capita is not null and 
       dwelling_fraction is not null) then			-- required parameter exists
      -- do calculation
      bldg_area = (pop_value * dwelling_fraction) * study_region_facts.avg_floor_capita;
      bldg_area_quality = 1;

   -- error ?, set to 0
   else 
      bldg_area = 0;
      bldg_area_quality = 0;
   end if;
   
   -- calculate building cost
   -- only 1 method   
   if (dist_values.replace_cost_per_area is not null) then		-- required parameter exists
      bldg_cost = bldg_area * dist_values.replace_cost_per_area;
      bldg_cost_quality = bldg_area_quality;	-- quality same as area quality 
      
   -- error ?, set to 0
   else
      bldg_cost = 0;
      bldg_cost_quality = 0;
   end if;

   -- raise notice '% % % % % %', bldg_count, bldg_count_quality, bldg_area, bldg_area_quality, bldg_cost, bldg_cost_quality;
   -- build output string
   return grid_id || ',' || lon || ',' || lat || ',"' || bldg_type || '","' || occ_type || '",' || is_urban || ',' || dwelling_fraction || ',' || bldg_fraction || ',' 
        || type_pop || ',' || day_pop || ',' || night_pop || ',' || transit_pop || ',' 
        || bldg_count || ',' || bldg_count_quality || ',' || bldg_area || ',' || bldg_area_quality || ',' || bldg_cost  || ',' || bldg_cost_quality;
END;
$$;


ALTER FUNCTION ged2.make_exposure_pgsql(grid_id bigint, lat double precision, lon double precision, is_urban boolean, pop_value double precision, tot_pop double precision, ms_sum_fraction_over_dwellings double precision, pop_alloc pop_allocation, study_region_facts study_region_facts, dist_values distribution_value) OWNER TO zh;

--
-- Name: test_func(); Type: FUNCTION; Schema: ged2; Owner: zh
--

CREATE FUNCTION test_func() RETURNS boolean
    LANGUAGE plpgsql
    AS $$begin
	return TRUE;
end$$;


ALTER FUNCTION ged2.test_func() OWNER TO zh;

--
-- Name: custom_geography; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE custom_geography (
    id integer NOT NULL,
    name character varying,
    shape_perimeter double precision,
    shape_area double precision,
    date timestamp without time zone,
    notes text,
    created_by integer,
    the_geom public.geometry,
    varname character varying,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'MULTIPOLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 4326))
);


ALTER TABLE ged2.custom_geography OWNER TO paul;

--
-- Name: custom_geography_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE custom_geography_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.custom_geography_id_seq OWNER TO paul;

--
-- Name: custom_geography_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE custom_geography_id_seq OWNED BY custom_geography.id;


--
-- Name: distribution_group; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE distribution_group (
    id integer NOT NULL,
    is_urban boolean NOT NULL,
    occupancy_id integer NOT NULL,
    compiled_by integer NOT NULL,
    study_region_id integer NOT NULL,
    building_fraction_source character varying,
    building_fraction_date date,
    dwelling_fraction_source character varying,
    dwelling_fraction_date date,
    replace_cost_per_area_source character varying,
    replace_cost_per_area_date date,
    replace_cost_per_area_currency character varying(3),
    avg_dwelling_per_build_source character varying,
    avg_dwelling_per_build_date date,
    avg_floor_area_source character varying,
    avg_floor_area_date date,
    area_unit_id integer,
    aggregate_pop integer,
    aggregate_pop_source character varying,
    aggregate_pop_date date,
    notes text
);


ALTER TABLE ged2.distribution_group OWNER TO paul;

--
-- Name: distribution_group_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE distribution_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.distribution_group_id_seq OWNER TO paul;

--
-- Name: distribution_group_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE distribution_group_id_seq OWNED BY distribution_group.id;


--
-- Name: distribution_value_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE distribution_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.distribution_value_id_seq OWNER TO paul;

--
-- Name: distribution_value_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE distribution_value_id_seq OWNED BY distribution_value.id;


--
-- Name: gadm2; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE gadm2 (
    objectid integer,
    id_0 integer,
    iso character varying(6),
    name_0 character varying(150),
    id_1 integer,
    name_1 character varying(150),
    varname_1 character varying(300),
    nl_name_1 character varying(100),
    id_2 integer,
    name_2 character varying(150),
    varname_2 character varying(300),
    nl_name_2 character varying(150),
    id_3 integer,
    name_3 character varying(150),
    varname_3 character varying(200),
    nl_name_3 character varying(150),
    id_4 integer,
    name_4 character varying(200),
    varname_4 character varying(200),
    id_5 integer,
    name_5 character varying(150),
    the_geom public.geometry,
    engtype_1 character varying(50),
    engtype_2 character varying(50),
    engtype_3 character varying(50),
    engtype_4 character varying(35),
    engtype_5 character varying(25),
    CONSTRAINT enforce_dims_the_geom CHECK ((public.ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'MULTIPOLYGON'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.srid(the_geom) = 4326))
);


ALTER TABLE ged2.gadm2 OWNER TO paul;

SET default_tablespace = ged2_ts;

--
-- Name: gadm_admin_1; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: ged2_ts
--

CREATE TABLE gadm_admin_1 (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    varname character varying(300),
    nl_name character varying(100),
    type character varying(50),
    engtype character varying(50),
    gadm_id_1 integer,
    gadm_country_id integer NOT NULL,
    date timestamp without time zone
);


ALTER TABLE ged2.gadm_admin_1 OWNER TO paul;

--
-- Name: gadm_admin_2; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: ged2_ts
--

CREATE TABLE gadm_admin_2 (
    id integer NOT NULL,
    name character varying(150),
    varname character varying(300),
    nl_name character varying(150),
    type character varying(50),
    engtype character varying(50),
    gadm_id_1 integer NOT NULL,
    gadm_id_2 integer NOT NULL,
    gadm_id_0 integer NOT NULL,
    gadm_admin_1_id integer NOT NULL,
    date timestamp without time zone
);


ALTER TABLE ged2.gadm_admin_2 OWNER TO paul;

--
-- Name: gadm_admin_3; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: ged2_ts
--

CREATE TABLE gadm_admin_3 (
    id integer NOT NULL,
    name character varying(150),
    varname character varying(200),
    nl_name character varying(150),
    type character varying(50),
    engtype character varying(50),
    gadm_id_1 integer NOT NULL,
    gadm_id_2 integer NOT NULL,
    gadm_id_3 integer NOT NULL,
    gadm_id_0 integer NOT NULL,
    gadm_admin_2_id integer NOT NULL,
    date timestamp without time zone
);


ALTER TABLE ged2.gadm_admin_3 OWNER TO paul;

--
-- Name: gadm_country; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: ged2_ts
--

CREATE TABLE gadm_country (
    id integer NOT NULL,
    iso character varying(6),
    name character varying(150)
);


ALTER TABLE ged2.gadm_country OWNER TO paul;

SET default_tablespace = '';

--
-- Name: ged_user; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE ged_user (
    id integer NOT NULL,
    first_name character varying NOT NULL,
    middle_name character varying,
    last_name character varying NOT NULL,
    organization character varying NOT NULL,
    user_type character varying,
    notes text,
    date_created timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    is_active boolean
);


ALTER TABLE ged2.ged_user OWNER TO paul;

--
-- Name: ged_user_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE ged_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.ged_user_id_seq OWNER TO paul;

--
-- Name: ged_user_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE ged_user_id_seq OWNED BY ged_user.id;


--
-- Name: geographic_region; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE geographic_region (
    id integer NOT NULL,
    gadm_country_id integer,
    gadm_admin_1_id integer,
    gadm_admin_2_id integer,
    gadm_admin_3_id integer,
    tot_pop integer,
    tot_pop_source character varying,
    tot_pop_date date,
    custom_geography_id integer,
    CONSTRAINT ged2_geographic_region_only_one_fk CHECK ((((((((((gadm_country_id IS NOT NULL) AND (gadm_admin_1_id IS NULL)) AND (gadm_admin_2_id IS NULL)) AND (gadm_admin_3_id IS NULL)) AND (custom_geography_id IS NULL)) OR (((((gadm_country_id IS NULL) AND (gadm_admin_1_id IS NOT NULL)) AND (gadm_admin_2_id IS NULL)) AND (gadm_admin_3_id IS NULL)) AND (custom_geography_id IS NULL))) OR (((((gadm_country_id IS NULL) AND (gadm_admin_1_id IS NULL)) AND (gadm_admin_2_id IS NOT NULL)) AND (gadm_admin_3_id IS NULL)) AND (custom_geography_id IS NULL))) OR (((((gadm_country_id IS NULL) AND (gadm_admin_1_id IS NULL)) AND (gadm_admin_2_id IS NULL)) AND (gadm_admin_3_id IS NOT NULL)) AND (custom_geography_id IS NULL))) OR (((((gadm_country_id IS NULL) AND (gadm_admin_1_id IS NULL)) AND (gadm_admin_2_id IS NULL)) AND (gadm_admin_3_id IS NULL)) AND (custom_geography_id IS NOT NULL))))
);


ALTER TABLE ged2.geographic_region OWNER TO paul;

--
-- Name: geographic_region_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE geographic_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.geographic_region_id_seq OWNER TO paul;

--
-- Name: geographic_region_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE geographic_region_id_seq OWNED BY geographic_region.id;


--
-- Name: grid_point; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE grid_point (
    id integer NOT NULL,
    is_urban boolean,
    pop_value double precision,
    land_area double precision,
    the_geom public.geometry,
    distance double precision,
    gadm_country_id integer,
    gadm_admin_1_id integer,
    gadm_admin_2_id integer,
    gadm_admin_3_id integer,
    gadm_objectid integer,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.srid(the_geom) = 4326))
);


ALTER TABLE ged2.grid_point OWNER TO paul;

--
-- Name: occupancy; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE occupancy (
    id integer NOT NULL,
    occupancy_type character varying(7) NOT NULL
);


ALTER TABLE ged2.occupancy OWNER TO paul;

SET default_tablespace = ged2_ts;

--
-- Name: old_grid_point; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: ged2_ts
--

CREATE TABLE old_grid_point (
    id integer NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    pop_value double precision NOT NULL,
    is_urban boolean NOT NULL,
    land_area double precision NOT NULL,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.st_ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.st_srid(the_geom) = 4326))
);


ALTER TABLE ged2.old_grid_point OWNER TO paul;

SET default_tablespace = '';

--
-- Name: old_grid_point_gadm; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE old_grid_point_gadm (
    grid_point_id integer,
    iso character varying(6),
    id_0 integer,
    id_1 integer,
    id_2 integer,
    id_3 integer,
    name_1 character varying(150),
    name_2 character varying(150),
    name_3 character varying(150),
    varname_1 character varying(300),
    nl_name_1 character varying(100),
    varname_2 character varying(300),
    nl_name_2 character varying(150),
    varname_3 character varying(200),
    nl_name_3 character varying(150)
);


ALTER TABLE ged2.old_grid_point_gadm OWNER TO paul;

--
-- Name: orhpaned_grid_point; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE orhpaned_grid_point (
    id integer NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    pop_value double precision NOT NULL,
    is_urban boolean NOT NULL,
    land_area double precision NOT NULL,
    the_geom public.geometry,
    CONSTRAINT enforce_dims_the_geom CHECK ((public.ndims(the_geom) = 2)),
    CONSTRAINT enforce_geotype_the_geom CHECK (((public.geometrytype(the_geom) = 'POINT'::text) OR (the_geom IS NULL))),
    CONSTRAINT enforce_srid_the_geom CHECK ((public.srid(the_geom) = 4326))
);


ALTER TABLE ged2.orhpaned_grid_point OWNER TO paul;

--
-- Name: pop_allocation_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE pop_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.pop_allocation_id_seq OWNER TO paul;

--
-- Name: pop_allocation_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE pop_allocation_id_seq OWNED BY pop_allocation.id;


--
-- Name: study; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE study (
    id integer NOT NULL,
    name character varying NOT NULL,
    date_created timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    notes text
);


ALTER TABLE ged2.study OWNER TO paul;

--
-- Name: study_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE study_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.study_id_seq OWNER TO paul;

--
-- Name: study_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE study_id_seq OWNED BY study.id;


--
-- Name: study_region; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE study_region (
    id integer NOT NULL,
    study_id integer NOT NULL,
    geographic_region_id integer NOT NULL,
    taxonomy_name character varying,
    taxonomy_version character varying,
    taxonomy_date date
);


ALTER TABLE ged2.study_region OWNER TO paul;

--
-- Name: study_region_facts_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE study_region_facts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.study_region_facts_id_seq OWNER TO paul;

--
-- Name: study_region_facts_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE study_region_facts_id_seq OWNED BY study_region_facts.id;


--
-- Name: study_region_id_seq; Type: SEQUENCE; Schema: ged2; Owner: paul
--

CREATE SEQUENCE study_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ged2.study_region_id_seq OWNER TO paul;

--
-- Name: study_region_id_seq; Type: SEQUENCE OWNED BY; Schema: ged2; Owner: paul
--

ALTER SEQUENCE study_region_id_seq OWNED BY study_region.id;


--
-- Name: unit; Type: TABLE; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE TABLE unit (
    id integer NOT NULL,
    unit_abbreviation character varying(6) NOT NULL,
    unit_description character varying NOT NULL
);


ALTER TABLE ged2.unit OWNER TO paul;

--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY custom_geography ALTER COLUMN id SET DEFAULT nextval('custom_geography_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_group ALTER COLUMN id SET DEFAULT nextval('distribution_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_value ALTER COLUMN id SET DEFAULT nextval('distribution_value_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY ged_user ALTER COLUMN id SET DEFAULT nextval('ged_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY geographic_region ALTER COLUMN id SET DEFAULT nextval('geographic_region_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY pop_allocation ALTER COLUMN id SET DEFAULT nextval('pop_allocation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study ALTER COLUMN id SET DEFAULT nextval('study_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study_region ALTER COLUMN id SET DEFAULT nextval('study_region_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study_region_facts ALTER COLUMN id SET DEFAULT nextval('study_region_facts_id_seq'::regclass);


--
-- Name: custom_geography_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY custom_geography
    ADD CONSTRAINT custom_geography_pkey PRIMARY KEY (id);


--
-- Name: distribution_group_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY distribution_group
    ADD CONSTRAINT distribution_group_pkey PRIMARY KEY (id);


--
-- Name: distribution_value_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY distribution_value
    ADD CONSTRAINT distribution_value_pkey PRIMARY KEY (id);


--
-- Name: gadm_admin_1_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY gadm_admin_1
    ADD CONSTRAINT gadm_admin_1_pkey PRIMARY KEY (id);


--
-- Name: gadm_admin_2_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY gadm_admin_2
    ADD CONSTRAINT gadm_admin_2_pkey PRIMARY KEY (id);


--
-- Name: gadm_admin_3_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY gadm_admin_3
    ADD CONSTRAINT gadm_admin_3_pkey PRIMARY KEY (id);


--
-- Name: gadm_country_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY gadm_country
    ADD CONSTRAINT gadm_country_pkey PRIMARY KEY (id);


--
-- Name: ged_user_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY ged_user
    ADD CONSTRAINT ged_user_pkey PRIMARY KEY (id);


--
-- Name: geographic_region_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY geographic_region
    ADD CONSTRAINT geographic_region_pkey PRIMARY KEY (id);


--
-- Name: grid_point_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY old_grid_point
    ADD CONSTRAINT grid_point_pkey PRIMARY KEY (id);


--
-- Name: new_grid_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY grid_point
    ADD CONSTRAINT new_grid_pkey PRIMARY KEY (id);


--
-- Name: occupancy_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY occupancy
    ADD CONSTRAINT occupancy_pkey PRIMARY KEY (id);


--
-- Name: pop_allocation_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY pop_allocation
    ADD CONSTRAINT pop_allocation_pkey PRIMARY KEY (id);


--
-- Name: study_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY study
    ADD CONSTRAINT study_pkey PRIMARY KEY (id);


--
-- Name: study_region_facts_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY study_region_facts
    ADD CONSTRAINT study_region_facts_pkey PRIMARY KEY (id);


--
-- Name: study_region_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY study_region
    ADD CONSTRAINT study_region_pkey PRIMARY KEY (id);


--
-- Name: unit_pkey; Type: CONSTRAINT; Schema: ged2; Owner: paul; Tablespace: 
--

ALTER TABLE ONLY unit
    ADD CONSTRAINT unit_pkey PRIMARY KEY (id);


--
-- Name: gadm2_the_geom_idx; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX gadm2_the_geom_idx ON gadm2 USING gist (the_geom);


--
-- Name: ged2_grid_point_the_geom; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX ged2_grid_point_the_geom ON old_grid_point USING gist (the_geom);


--
-- Name: grid_point_gadm_id_idx; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX grid_point_gadm_id_idx ON old_grid_point_gadm USING btree (grid_point_id);


--
-- Name: grid_point_the_geom_idx; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX grid_point_the_geom_idx ON grid_point USING gist (the_geom);


--
-- Name: new_grid_gadm_country_id_idx; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX new_grid_gadm_country_id_idx ON grid_point USING btree (gadm_country_id);


--
-- Name: orhpaned_grid_point_the_geom_idx; Type: INDEX; Schema: ged2; Owner: paul; Tablespace: 
--

CREATE INDEX orhpaned_grid_point_the_geom_idx ON orhpaned_grid_point USING gist (the_geom);


--
-- Name: custom_geography_created_by_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY custom_geography
    ADD CONSTRAINT custom_geography_created_by_fkey FOREIGN KEY (created_by) REFERENCES ged_user(id);


--
-- Name: distribution_group_area_unit_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_group
    ADD CONSTRAINT distribution_group_area_unit_id_fkey FOREIGN KEY (area_unit_id) REFERENCES unit(id);


--
-- Name: distribution_group_compiled_by_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_group
    ADD CONSTRAINT distribution_group_compiled_by_fkey FOREIGN KEY (compiled_by) REFERENCES ged_user(id);


--
-- Name: distribution_group_occupancy_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_group
    ADD CONSTRAINT distribution_group_occupancy_id_fkey FOREIGN KEY (occupancy_id) REFERENCES occupancy(id);


--
-- Name: distribution_group_study_region_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_group
    ADD CONSTRAINT distribution_group_study_region_id_fkey FOREIGN KEY (study_region_id) REFERENCES study_region(id);


--
-- Name: distribution_value_distribution_group_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY distribution_value
    ADD CONSTRAINT distribution_value_distribution_group_id_fkey FOREIGN KEY (distribution_group_id) REFERENCES distribution_group(id);


--
-- Name: gadm_admin_1_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY gadm_admin_2
    ADD CONSTRAINT gadm_admin_1_id_fk FOREIGN KEY (gadm_admin_1_id) REFERENCES gadm_admin_1(id);


--
-- Name: gadm_admin_1_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY geographic_region
    ADD CONSTRAINT gadm_admin_1_id_fk FOREIGN KEY (gadm_admin_1_id) REFERENCES gadm_admin_1(id);


--
-- Name: gadm_admin_2_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY geographic_region
    ADD CONSTRAINT gadm_admin_2_id_fk FOREIGN KEY (gadm_admin_2_id) REFERENCES gadm_admin_2(id);


--
-- Name: gadm_admin_3_gadm_admin_2_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY gadm_admin_3
    ADD CONSTRAINT gadm_admin_3_gadm_admin_2_id_fkey FOREIGN KEY (gadm_admin_2_id) REFERENCES gadm_admin_2(id);


--
-- Name: gadm_admin_3_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY geographic_region
    ADD CONSTRAINT gadm_admin_3_id_fk FOREIGN KEY (gadm_admin_3_id) REFERENCES gadm_admin_3(id);


--
-- Name: gadm_country_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY gadm_admin_1
    ADD CONSTRAINT gadm_country_id_fk FOREIGN KEY (gadm_country_id) REFERENCES gadm_country(id);


--
-- Name: gadm_country_id_fk; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY geographic_region
    ADD CONSTRAINT gadm_country_id_fk FOREIGN KEY (gadm_country_id) REFERENCES gadm_country(id);


--
-- Name: pop_allocation_geographic_region_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY pop_allocation
    ADD CONSTRAINT pop_allocation_geographic_region_id_fkey FOREIGN KEY (geographic_region_id) REFERENCES geographic_region(id);


--
-- Name: pop_allocation_occupancy_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY pop_allocation
    ADD CONSTRAINT pop_allocation_occupancy_id_fkey FOREIGN KEY (occupancy_id) REFERENCES occupancy(id);


--
-- Name: study_region_facts_distribution_group_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study_region_facts
    ADD CONSTRAINT study_region_facts_distribution_group_id_fkey FOREIGN KEY (distribution_group_id) REFERENCES distribution_group(id);


--
-- Name: study_region_geographic_region_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study_region
    ADD CONSTRAINT study_region_geographic_region_id_fkey FOREIGN KEY (geographic_region_id) REFERENCES geographic_region(id);


--
-- Name: study_region_study_id_fkey; Type: FK CONSTRAINT; Schema: ged2; Owner: paul
--

ALTER TABLE ONLY study_region
    ADD CONSTRAINT study_region_study_id_fkey FOREIGN KEY (study_id) REFERENCES study(id);


--
-- Name: ged2; Type: ACL; Schema: -; Owner: paul
--

REVOKE ALL ON SCHEMA ged2 FROM PUBLIC;
REVOKE ALL ON SCHEMA ged2 FROM paul;
GRANT ALL ON SCHEMA ged2 TO paul;
GRANT USAGE ON SCHEMA ged2 TO gedusers;
GRANT ALL ON SCHEMA ged2 TO ged2admin;


--
-- Name: distribution_value; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE distribution_value FROM PUBLIC;
REVOKE ALL ON TABLE distribution_value FROM paul;
GRANT ALL ON TABLE distribution_value TO paul;
GRANT ALL ON TABLE distribution_value TO ged2admin;
GRANT SELECT ON TABLE distribution_value TO bwyss;
GRANT SELECT ON TABLE distribution_value TO gedusers;


--
-- Name: pop_allocation; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE pop_allocation FROM PUBLIC;
REVOKE ALL ON TABLE pop_allocation FROM paul;
GRANT ALL ON TABLE pop_allocation TO paul;
GRANT ALL ON TABLE pop_allocation TO ged2admin;
GRANT SELECT ON TABLE pop_allocation TO bwyss;
GRANT SELECT ON TABLE pop_allocation TO gedusers;


--
-- Name: study_region_facts; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE study_region_facts FROM PUBLIC;
REVOKE ALL ON TABLE study_region_facts FROM paul;
GRANT ALL ON TABLE study_region_facts TO paul;
GRANT ALL ON TABLE study_region_facts TO ged2admin;
GRANT SELECT ON TABLE study_region_facts TO bwyss;
GRANT SELECT ON TABLE study_region_facts TO gedusers;


--
-- Name: custom_geography; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE custom_geography FROM PUBLIC;
REVOKE ALL ON TABLE custom_geography FROM paul;
GRANT ALL ON TABLE custom_geography TO paul;
GRANT ALL ON TABLE custom_geography TO ged2admin;
GRANT SELECT ON TABLE custom_geography TO bwyss;
GRANT SELECT ON TABLE custom_geography TO gedusers;


--
-- Name: custom_geography_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE custom_geography_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE custom_geography_id_seq FROM paul;
GRANT ALL ON SEQUENCE custom_geography_id_seq TO paul;
GRANT ALL ON SEQUENCE custom_geography_id_seq TO ged2admin;


--
-- Name: distribution_group; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE distribution_group FROM PUBLIC;
REVOKE ALL ON TABLE distribution_group FROM paul;
GRANT ALL ON TABLE distribution_group TO paul;
GRANT ALL ON TABLE distribution_group TO ged2admin;
GRANT SELECT ON TABLE distribution_group TO bwyss;
GRANT SELECT ON TABLE distribution_group TO gedusers;


--
-- Name: distribution_group_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE distribution_group_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE distribution_group_id_seq FROM paul;
GRANT ALL ON SEQUENCE distribution_group_id_seq TO paul;
GRANT ALL ON SEQUENCE distribution_group_id_seq TO ged2admin;


--
-- Name: distribution_value_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE distribution_value_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE distribution_value_id_seq FROM paul;
GRANT ALL ON SEQUENCE distribution_value_id_seq TO paul;
GRANT ALL ON SEQUENCE distribution_value_id_seq TO ged2admin;


--
-- Name: gadm2; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE gadm2 FROM PUBLIC;
REVOKE ALL ON TABLE gadm2 FROM paul;
GRANT ALL ON TABLE gadm2 TO paul;
GRANT ALL ON TABLE gadm2 TO ged2admin;
GRANT SELECT ON TABLE gadm2 TO bwyss;
GRANT SELECT ON TABLE gadm2 TO gedusers;


--
-- Name: gadm_admin_1; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE gadm_admin_1 FROM PUBLIC;
REVOKE ALL ON TABLE gadm_admin_1 FROM paul;
GRANT ALL ON TABLE gadm_admin_1 TO paul;
GRANT ALL ON TABLE gadm_admin_1 TO ged2admin;
GRANT SELECT ON TABLE gadm_admin_1 TO bwyss;
GRANT SELECT ON TABLE gadm_admin_1 TO gedusers;


--
-- Name: gadm_admin_2; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE gadm_admin_2 FROM PUBLIC;
REVOKE ALL ON TABLE gadm_admin_2 FROM paul;
GRANT ALL ON TABLE gadm_admin_2 TO paul;
GRANT ALL ON TABLE gadm_admin_2 TO ged2admin;
GRANT SELECT ON TABLE gadm_admin_2 TO bwyss;
GRANT SELECT ON TABLE gadm_admin_2 TO gedusers;


--
-- Name: gadm_admin_3; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE gadm_admin_3 FROM PUBLIC;
REVOKE ALL ON TABLE gadm_admin_3 FROM paul;
GRANT ALL ON TABLE gadm_admin_3 TO paul;
GRANT ALL ON TABLE gadm_admin_3 TO ged2admin;
GRANT SELECT ON TABLE gadm_admin_3 TO bwyss;
GRANT SELECT ON TABLE gadm_admin_3 TO gedusers;


--
-- Name: gadm_country; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE gadm_country FROM PUBLIC;
REVOKE ALL ON TABLE gadm_country FROM paul;
GRANT ALL ON TABLE gadm_country TO paul;
GRANT ALL ON TABLE gadm_country TO ged2admin;
GRANT SELECT ON TABLE gadm_country TO bwyss;
GRANT SELECT ON TABLE gadm_country TO gedusers;


--
-- Name: ged_user; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE ged_user FROM PUBLIC;
REVOKE ALL ON TABLE ged_user FROM paul;
GRANT ALL ON TABLE ged_user TO paul;
GRANT ALL ON TABLE ged_user TO ged2admin;
GRANT SELECT ON TABLE ged_user TO bwyss;
GRANT SELECT ON TABLE ged_user TO gedusers;


--
-- Name: ged_user_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE ged_user_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE ged_user_id_seq FROM paul;
GRANT ALL ON SEQUENCE ged_user_id_seq TO paul;
GRANT ALL ON SEQUENCE ged_user_id_seq TO ged2admin;


--
-- Name: geographic_region; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE geographic_region FROM PUBLIC;
REVOKE ALL ON TABLE geographic_region FROM paul;
GRANT ALL ON TABLE geographic_region TO paul;
GRANT ALL ON TABLE geographic_region TO ged2admin;
GRANT SELECT ON TABLE geographic_region TO bwyss;
GRANT SELECT ON TABLE geographic_region TO gedusers;


--
-- Name: geographic_region_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE geographic_region_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE geographic_region_id_seq FROM paul;
GRANT ALL ON SEQUENCE geographic_region_id_seq TO paul;
GRANT ALL ON SEQUENCE geographic_region_id_seq TO ged2admin;


--
-- Name: grid_point; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE grid_point FROM PUBLIC;
REVOKE ALL ON TABLE grid_point FROM paul;
GRANT ALL ON TABLE grid_point TO paul;
GRANT ALL ON TABLE grid_point TO ged2admin;
GRANT SELECT ON TABLE grid_point TO bwyss;
GRANT SELECT ON TABLE grid_point TO gedusers;


--
-- Name: occupancy; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE occupancy FROM PUBLIC;
REVOKE ALL ON TABLE occupancy FROM paul;
GRANT ALL ON TABLE occupancy TO paul;
GRANT ALL ON TABLE occupancy TO ged2admin;
GRANT SELECT ON TABLE occupancy TO bwyss;
GRANT SELECT ON TABLE occupancy TO gedusers;


--
-- Name: old_grid_point; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE old_grid_point FROM PUBLIC;
REVOKE ALL ON TABLE old_grid_point FROM paul;
GRANT ALL ON TABLE old_grid_point TO paul;
GRANT SELECT ON TABLE old_grid_point TO gedusers;
GRANT ALL ON TABLE old_grid_point TO ged2admin;
GRANT SELECT ON TABLE old_grid_point TO bwyss;


--
-- Name: old_grid_point_gadm; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE old_grid_point_gadm FROM PUBLIC;
REVOKE ALL ON TABLE old_grid_point_gadm FROM paul;
GRANT ALL ON TABLE old_grid_point_gadm TO paul;
GRANT SELECT ON TABLE old_grid_point_gadm TO gedusers;
GRANT ALL ON TABLE old_grid_point_gadm TO ged2admin;
GRANT SELECT ON TABLE old_grid_point_gadm TO bwyss;


--
-- Name: orhpaned_grid_point; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE orhpaned_grid_point FROM PUBLIC;
REVOKE ALL ON TABLE orhpaned_grid_point FROM paul;
GRANT ALL ON TABLE orhpaned_grid_point TO paul;
GRANT ALL ON TABLE orhpaned_grid_point TO ged2admin;
GRANT SELECT ON TABLE orhpaned_grid_point TO bwyss;
GRANT SELECT ON TABLE orhpaned_grid_point TO gedusers;


--
-- Name: pop_allocation_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE pop_allocation_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE pop_allocation_id_seq FROM paul;
GRANT ALL ON SEQUENCE pop_allocation_id_seq TO paul;
GRANT ALL ON SEQUENCE pop_allocation_id_seq TO ged2admin;


--
-- Name: study; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE study FROM PUBLIC;
REVOKE ALL ON TABLE study FROM paul;
GRANT ALL ON TABLE study TO paul;
GRANT ALL ON TABLE study TO ged2admin;
GRANT SELECT ON TABLE study TO bwyss;
GRANT SELECT ON TABLE study TO gedusers;


--
-- Name: study_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE study_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE study_id_seq FROM paul;
GRANT ALL ON SEQUENCE study_id_seq TO paul;
GRANT ALL ON SEQUENCE study_id_seq TO ged2admin;


--
-- Name: study_region; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE study_region FROM PUBLIC;
REVOKE ALL ON TABLE study_region FROM paul;
GRANT ALL ON TABLE study_region TO paul;
GRANT ALL ON TABLE study_region TO ged2admin;
GRANT SELECT ON TABLE study_region TO bwyss;
GRANT SELECT ON TABLE study_region TO gedusers;


--
-- Name: study_region_facts_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE study_region_facts_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE study_region_facts_id_seq FROM paul;
GRANT ALL ON SEQUENCE study_region_facts_id_seq TO paul;
GRANT ALL ON SEQUENCE study_region_facts_id_seq TO ged2admin;


--
-- Name: study_region_id_seq; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON SEQUENCE study_region_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE study_region_id_seq FROM paul;
GRANT ALL ON SEQUENCE study_region_id_seq TO paul;
GRANT ALL ON SEQUENCE study_region_id_seq TO ged2admin;


--
-- Name: unit; Type: ACL; Schema: ged2; Owner: paul
--

REVOKE ALL ON TABLE unit FROM PUBLIC;
REVOKE ALL ON TABLE unit FROM paul;
GRANT ALL ON TABLE unit TO paul;
GRANT ALL ON TABLE unit TO ged2admin;
GRANT SELECT ON TABLE unit TO bwyss;
GRANT SELECT ON TABLE unit TO gedusers;


--
-- PostgreSQL database dump complete
--

