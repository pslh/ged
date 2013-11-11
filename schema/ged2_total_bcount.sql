--
-- Obtain grid_id, building count for a given study_region
--
DROP FUNCTION IF EXISTS ged2.total_bcount(INTEGER);


CREATE OR REPLACE FUNCTION ged2.total_bcount(study_region_id INTEGER)
  RETURNS TABLE(
  	grid_id INTEGER, 
  	total_bldg_count FLOAT, 
  	total_blgd_area FLOAT) AS
$BODY$
DECLARE
	exposure ged2.exposure_t;

	-- Temporary variables, names start with _
	_total_bldgs  float;
	_dwellings_count float;
BEGIN	
	RETURN QUERY SELECT
		exp1.grid_id,
		SUM(exp1.bldg_count) AS total_bldg_count,
		SUM(exp1.bldg_area) AS total_blgd_area
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
ALTER FUNCTION ged2.total_bcount(integer)
  OWNER TO paul;

