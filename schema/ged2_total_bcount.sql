--
-- Obtain grid_id, building count for a given study_region
--
--DROP FUNCTION IF EXISTS ged2.total_bcount(INTEGER);

DROP VIEW IF EXISTS ged2.all_nera_l0_studies;
DROP VIEW IF EXISTS ged2.all_hazus_studies;

DROP FUNCTION IF EXISTS ged2.total_bldg_count_area(INTEGER);


CREATE OR REPLACE FUNCTION ged2.total_bldg_count_area(study_region_id INTEGER)
  RETURNS TABLE(
  	grid_id INTEGER, 
  	bldg_count FLOAT, 
  	bldg_area FLOAT) AS
$BODY$
DECLARE
BEGIN	
	RETURN QUERY SELECT
		exp1.grid_id,
		SUM(exp1.bldg_count) AS bldg_count,
		SUM(exp1.bldg_area) AS bldg_area
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

