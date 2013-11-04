
-- Function: ged2.make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value)

DROP FUNCTION IF EXISTS ged2.make_exposure_pgsql_retrec(
	bigint, double precision, double precision, boolean, 
	double precision, double precision, double precision, 
	ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);

DROP FUNCTION IF EXISTS ged2.make_exposure_pgsql_retrec(
	integer, double precision, double precision, boolean, 
	double precision, double precision, double precision, 
	ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);


DROP TYPE IF EXISTS ged2.exposure_t;

--
-- Composite type for exposure data
--
CREATE TYPE ged2.exposure_t AS (
	grid_id INTEGER,
	lat double precision, 
	lon double precision,
	bldg_type VARCHAR,
	occ_type INTEGER, 
	is_urban BOOLEAN,
	
	dwelling_fraction float;
	bldg_fraction float;
	type_pop float;
	day_pop float;
	night_pop float;
	transit_pop float;
  
 	bldg_count float,
	bldg_count_quality integer,
	bldg_area float,
	bldg_area_quality integer,
	bldg_cost float,
	bldg_cost_quality integer	
);


--
-- Calculate building count, area and cost
--
CREATE OR REPLACE FUNCTION ged2.make_exposure_pgsql_retrec(
	grid_id INTEGER, lat double precision, lon double precision, 
	is_urban boolean, 
	pop_value double precision, 
	tot_pop double precision, 
	ms_sum_fraction_over_dwellings double precision, 
	pop_alloc ged2.pop_allocation, 
	study_region_facts ged2.study_region_facts, 
	dist_values ged2.distribution_value)
  RETURNS text AS
$BODY$
DECLARE
	return_value ged2.exposure_t;

	-- Temporary variables, names start with _
	_total_bldgs  float;
	_dwellings_count float;
BEGIN	
	-- generate building count using algorithm defined in document
  	-- 'UNIPV_USGS_revised_procedure_1.5.doc'    
  	-- version 0.2
   	-- by ZhengHui Hu, modified by Paul Henshaw
   	-- last updated: 2013-11-04
	
	IF (tot_pop IS NULL OR tot_pop = 0) 
	THEN
		RAISE EXCEPTION 'Total population may not be NULL OR 0' 
			USING HINT 'Please check definition of study region';
	END IF
	
	--
	-- TODO consider removing values which are simply copied from inputs
	--
	return_value.bldg_type = dist_values.building_type;
	return_value.occ_type = pop_alloc.occupancy_id;
	return_value.dwelling_fraction = dist_values.dwelling_fraction;
   
	-- population used to calculate building count
	-- based on communication with HC, use total population
	-- NOTE if  dwelling_fraction IS NULL, all _pop values are also NULL
	return_value.type_pop = pop_value * return_value.dwelling_fraction;
	return_value.day_pop = pop_value * return_value.dwelling_fraction * 
		pop_alloc.day_pop_ratio;
	return_value.night_pop = pop_value * return_value.dwelling_fraction * 
		pop_alloc.night_pop_ratio;
	return_value.transit_pop = pop_value * return_value.dwelling_fraction * 
		pop_alloc.transit_pop_ratio;

	-- Initialise temporary variables
	_total_bldgs=-1;
	_dwellings_count = -1;
   
	-- Initialise actual return values
	-- TODO consider using NULL
	return_value.bldg_count = -1;
	return_value.bldg_count_quality = 0;
	return_value.bldg_area = -1;
	return_value.bldg_area_quality = 0;
	return_value.bldg_cost = -1;
	return_value.bldg_cost_quality = 0;
	
	return_value.bldg_fraction = 0;

	--
   	-- Calculate building count using one of the five methods described in
   	-- UNIPV_USGS_revised_procedure_1.5.doc
   	--

   	-- method 5 (best quality)
   	-- requires total_num_buildings and building_fraction
	IF (study_region_facts.tot_num_buildings IS NOT NULL AND 
		dist_values.building_fraction IS NOT NULL) 
	THEN
		return_value.bldg_count = (pop_value / tot_pop) * 
      		study_region_facts.tot_num_buildings * 
      		dist_values.building_fraction;
      	return_value.bldg_count_quality = 5;

   	-- method 4 
	ELSIF (	study_region_facts.tot_num_buildings IS NOT NULL AND 	
      		return_value.dwelling_fraction IS NOT NULL AND
       		dist_values.avg_dwelling_per_build IS NOT NULL AND
       		ms_sum_fraction_over_dwellings <> 0) 
	THEN		
      	_total_bldgs = (pop_value / tot_pop) * 
      		study_region_facts.tot_num_buildings;
      	IF (dist_values.building_fraction IS NOT NULL) 
      	THEN
         	return_value.bldg_fraction = dist_values.building_fraction;
      	ELSE
        	return_value.bldg_fraction = (return_value.dwelling_fraction / 
        		dist_values.avg_dwelling_per_build ) / 
        			ms_sum_fraction_over_dwellings; 
      	END IF;
      	return_value.bldg_count = _total_bldgs * bldg_fraction;
      	return_value.bldg_count_quality = 4;

   	-- method 3
	ELSIF (study_region_facts.tot_num_dwellings IS NOT NULL AND
	       dist_values.avg_dwelling_per_build is not null) 
	THEN
      	_dwellings_count = (pop_value / tot_pop) * 
      		study_region_facts.tot_num_dwellings * 
      			return_value.dwelling_fraction;      
      	return_value.bldg_count = _dwellings_count / 
      		dist_values.avg_dwelling_per_build;      
      	return_value.bldg_count_quality = 3;
      	
   	-- method 2 
	ELSIF (	study_region_facts.avg_peop_dwelling IS NOT NULL AND		
       		dist_values.avg_dwelling_per_build IS NOT NUL) 
    THEN
      	_dwellings_count = (pop_value * return_value.dwelling_fraction) / 
      		study_region_facts.avg_peop_dwelling;
      	return_value.bldg_count = _dwellings_count / 
      		dist_values.avg_dwelling_per_build;
      	return_value.bldg_count_quality = 2;

   	-- method 1
   	ELSIF (	study_region_facts.avg_peop_building IS NOT NULL AND		
       		return_value.dwelling_fraction IS NOT NULL AND
       		ms_sum_fraction_over_dwellings <> 0 ) 
	THEN
      	_total_bldgs = pop_value / study_region_facts.avg_peop_building;
      	IF (dist_values.building_fraction IS NOT NULL) 
      	THEN
         	return_value.bldg_fraction = dist_values.building_fraction;
      	ELSE
			return_value.bldg_fraction = (return_value.dwelling_fraction / 
				dist_values.avg_dwelling_per_build ) / 
					ms_sum_fraction_over_dwellings; 
      	END IF;
      	return_value.bldg_count = _total_bldgs * bldg_fraction;
      	return_value.bldg_count_quality = 1;

   	ELSE
   		RAISE WARNING 'No suitable building count method found, returning NULL';
		RETURN NULL;
   	END IF;
   
   	
   	
	--
   	-- Calculate building area
   	-- NOTE that at this point building count is set, area is NOT set
   	--
   	
   	-- method 3
   	IF (dist_values.avg_floor_area IS NOT NULL) 
   	THEN
    	return_value.bldg_area = return_value.bldg_count * 
    		dist_values.avg_floor_area;
    	return_value.bldg_area_quality = return_value.bldg_count_quality;

	-- method 2
   	ELSIF (	_dwellings_count <> -1 AND 				
       		study_region_facts.avg_dwelling_area IS NOT NULL) 
	THEN 
      -- do calculation      
      return_value.bldg_area = _dwellings_count * 
      	study_region_facts.avg_dwelling_area;
      return_value.bldg_area_quality = return_value.bldg_count_quality;

   	-- method 1
	ELSIF (	study_region_facts.avg_floor_capita IS NOT NULL AND 
       		return_value.dwelling_fraction IS NOT NULL) 
	THEN
      return_value.bldg_area = (pop_value * return_value.dwelling_fraction) * 
      	study_region_facts.avg_floor_capita;
      return_value.bldg_area_quality = 1;

   	-- error ?, set to 0
   	ELSE
   		RAISE WARNING 'No building area method, setting area value to NULL';
      	return_value.bldg_area = NULL;
      	return_value.bldg_area_quality = 0;
   	END IF;
   
   -- calculate building cost
   -- only 1 method   
   	IF (dist_values.replace_cost_per_area IS NOT NULL) 
   	THEN		
    	return_value.bldg_cost = return_value.bldg_area * 
      		dist_values.replace_cost_per_area;
      	-- quality same as area quality 
      	return_value.bldg_cost_quality = return_value.bldg_area_quality;	
   	-- error ?, set to 0
   	ELSE
		RAISE WARNING 'No building cost method, setting cost value to NULL';
      	return_value.bldg_cost = NULL;
      	return_value.bldg_cost_quality = 0;
   	END IF;

	RETURN return_value; 
END;
$BODY$
  LANGUAGE plpgsql 
  IMMUTABLE  -- Does not read or change DB, output depends only on input
  COST 100;
ALTER FUNCTION ged2.make_exposure_pgsql_retrec(integer, double precision, 
	double precision, boolean, double precision, double precision, 
	double precision, ged2.pop_allocation, ged2.study_region_facts, 
	ged2.distribution_value)
  OWNER TO paul;

