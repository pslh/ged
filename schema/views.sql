DROP VIEW IF EXISTS ged2.all_hazus_studies;

--
-- View for all HAZUS study regions
--
CREATE OR REPLACE VIEW ged2.all_hazus_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.name = 'HAZUS'
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).grid_id AS grid_id, 
 		(wrapped.bc).bldg_count AS bldg_count, 
 		(wrapped.bc).bldg_area AS bldg_area, 
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_hazus_studies
  OWNER TO paul;

--
-- View for all NERA Level 0 study regions
--
DROP VIEW IF EXISTS ged2.all_nera_l0_studies;
CREATE OR REPLACE VIEW ged2.all_nera_l0_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.name = 'NERA'
	   AND grg.g1name IS NULL  -- ONLY Level 0 studies
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).*,
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_nera_l0_studies
  OWNER TO paul;
  
--
DROP VIEW IF EXISTS ged2.all_nera_l1_studies;
CREATE OR REPLACE VIEW ged2.all_nera_l1_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.name LIKE '%, L1, NERA'
	   AND grg.g1name IS NOT NULL  -- ONLY Level 1 studies
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).*,
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_nera_l1_studies
  OWNER TO paul;
  
--
-- View for all PAGER Level 0 study regions
--
DROP VIEW IF EXISTS ged2.all_pager_l0_studies;
CREATE OR REPLACE VIEW ged2.all_pager_l0_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.notes LIKE '% PAGER mapping schemes'
	   AND grg.g1name IS NULL  -- ONLY Level 0 studies
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).grid_id AS grid_id, 
 		(wrapped.bc).bldg_count AS bldg_count, 
 		(wrapped.bc).bldg_area AS bldg_area, 
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_pager_l0_studies
  OWNER TO paul;

--
-- View for all UN Habitat Level 0 study regions
--
DROP VIEW IF EXISTS ged2.all_unhabitat_l0_studies;
CREATE OR REPLACE VIEW ged2.all_unhabitat_l0_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.name like '%L0, UN Habitat'
	   AND grg.g1name IS NULL  -- ONLY Level 0 studies
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).grid_id AS grid_id, 
 		(wrapped.bc).bldg_count AS bldg_count, 
 		(wrapped.bc).bldg_area AS bldg_area, 
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_unhabitat_l0_studies
  OWNER TO paul;

--
-- View for all UN Habitat Level 1 study regions
--
DROP VIEW IF EXISTS ged2.all_unhabitat_l1_studies;
CREATE OR REPLACE VIEW ged2.all_unhabitat_l1_studies 
AS 
 -- Obtain Study Regions in srs
 WITH srs AS (
 	SELECT sr.id AS sr_id
	  FROM ged2.study_region sr
      JOIN ged2.study study 
        ON study.id = sr.study_id
	  JOIN ged2.geographic_region_gadm grg 
	    ON grg.region_id = sr.geographic_region_id
	 WHERE study.name like '%L1, UN Habitat'
	   AND grg.g1name IS NOT NULL  -- ONLY Level 0 studies
	 ORDER BY sr.id
 )
 SELECT 
 	    -- Unwrap bc record and join on grid to obtain geom et al
 		wrapped.sr_id, 
 		(wrapped.bc).grid_id AS grid_id, 
 		(wrapped.bc).bldg_count AS bldg_count, 
 		(wrapped.bc).bldg_area AS bldg_area, 
 		grid.is_urban, 
 		grid.pop_value, 
 		grid.the_geom
   FROM (
   		-- Obtain totals for Study Region
   		-- result is "wrapped" in bc record
   		SELECT srs.sr_id, ged2.total_bldg_count_area(srs.sr_id) AS bc
          FROM srs
   ) AS wrapped
   JOIN ged2.grid_point grid 
     ON grid.id = (wrapped.bc).grid_id
;
ALTER TABLE ged2.all_unhabitat_l1_studies
  OWNER TO paul;
