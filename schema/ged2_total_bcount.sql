--
-- Obtain grid_id, building count for a given study_region
--
--DROP FUNCTION IF EXISTS ged2.total_bcount(INTEGER);

DROP VIEW IF EXISTS ged2.all_nera_l0_studies;
DROP VIEW IF EXISTS ged2.all_hazus_studies;
DROP VIEW IF EXISTS ged2.all_pager_l0_studies;
DROP VIEW IF EXISTS ged2.all_unhabitat_l1_studies;
DROP VIEW IF EXISTS ged2.all_unhabitat_l0_studies;

DROP FUNCTION IF EXISTS ged2.total_bldg_count_area(INTEGER);


CREATE OR REPLACE FUNCTION ged2.total_bldg_count_area(study_region_id INTEGER)
  RETURNS TABLE(
  	grid_id INTEGER, 
  	bldg_count FLOAT, 
  	bldg_count_quality INTEGER,
  	bldg_area FLOAT,
  	bldg_area_quality INTEGER,
  	bldg_cost FLOAT,
  	bldg_cost_quality INTEGER
  	) AS
$BODY$
DECLARE
BEGIN	
	RETURN QUERY SELECT
		exp1.grid_id,
		SUM(exp1.bldg_count) AS bldg_count,
		MIN(exp1.bldg_count_quality) AS bldg_count_quality,
		SUM(exp1.bldg_area) AS bldg_area,
		MIN(exp1.bldg_area_quality) AS bldg_area_quality,
		SUM(exp1.bldg_cost) AS bldg_cost,
		MIN(exp1.bldg_cost_quality) AS bldg_cost_quality
	  FROM (
		SELECT *
		  FROM ged2.build_study_region_retrec(study_region_id)
		) AS exp1
	 GROUP BY exp1.grid_id;
END;
$BODY$
  LANGUAGE plpgsql 
  VOLATILE
  COST 100;
ALTER FUNCTION ged2.total_bldg_count_area(integer)
  OWNER TO paul;

