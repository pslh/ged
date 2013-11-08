
--
-- Composite type for building count with quality
-- Depending on the algorithm used to calculate number of buildings, the 
-- dwellings count and/or building fraction fields may also be set.  
--
DROP TYPE IF EXISTS ged2.bcount_t;
CREATE TYPE ged2.bcount_t AS (
 	bldg_count float,
	bldg_count_quality integer,
	dwellings_count float,
	bldg_fraction float
);

--
-- Composite type for building area with quality
--
DROP TYPE IF EXISTS ged2.barea_t;
CREATE TYPE ged2.barea_t AS (
	bldg_area float,
	bldg_area_quality integer
);

--
-- Calculate building area and quality  
--
CREATE OR REPLACE FUNCTION ged2.get_building_area(
	bcount ged2.bcount_t, 
	pop_value double precision, 
	study_region_facts ged2.study_region_facts, 
	dist_values ged2.distribution_value)
  RETURNS ged2.barea_t AS
$BODY$
DECLARE
	return_value	ged2.barea_t;
BEGIN	
   	-- method 3
   	IF (dist_values.avg_floor_area IS NOT NULL) 
   	THEN
    	return_value.bldg_area = bcount.bldg_count * 
    		dist_values.avg_floor_area;
    	return_value.bldg_area_quality = bcount.bldg_count_quality;

	-- method 2
   	ELSIF (	bcount.dwellings_count <> -1 AND 				
       		study_region_facts.avg_dwelling_area IS NOT NULL) 
	THEN 
      return_value.bldg_area = bcount.dwellings_count * 
      	study_region_facts.avg_dwelling_area;
      return_value.bldg_area_quality = bcount.bldg_count_quality;

   	-- method 1
	ELSIF (	study_region_facts.avg_floor_capita IS NOT NULL AND 
       		dist_values.dwelling_fraction IS NOT NULL) 
	THEN
      return_value.bldg_area = (pop_value * dist_values.dwelling_fraction) * 
      	study_region_facts.avg_floor_capita;
      return_value.bldg_area_quality = 1;

   	-- error ?, set to 0
   	ELSE
   		RAISE WARNING 'No building area method, setting area value to NULL';
      	return_value.bldg_area = NULL;
      	return_value.bldg_area_quality = 0;
   	END IF;
   	
	RETURN return_value; 
END;
$BODY$
  LANGUAGE plpgsql 
  IMMUTABLE  -- Does not read or change DB, output depends only on input
  COST 100;
ALTER FUNCTION ged2.get_building_area(	
	 ged2.bcount_t, 
	 double precision, 
	 ged2.study_region_facts, 
	 ged2.distribution_value)
  OWNER TO paul;
