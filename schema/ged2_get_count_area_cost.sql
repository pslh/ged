DROP FUNCTION IF EXISTS ged2.get_count_area_cost(
	integer, double precision, double precision, boolean, 
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
	lon double precision,
	lat double precision, 
	bldg_type VARCHAR,
	occ_type INTEGER, 
	is_urban BOOLEAN,
	
	dwelling_fraction float,
	bldg_fraction float,
	type_pop float,
	day_pop float,
	night_pop float,
	transit_pop float,
  
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
CREATE OR REPLACE FUNCTION ged2.get_count_area_cost(
	grid_id INTEGER, lat double precision, lon double precision, 
	is_urban boolean, 
	pop_value double precision, 
	tot_pop double precision, 
	ms_sum_fraction_over_dwellings double precision, 
	pop_alloc ged2.pop_allocation, 
	study_region_facts ged2.study_region_facts, 
	dist_values ged2.distribution_value)
  RETURNS ged2.exposure_t AS
$BODY$
DECLARE
	return_value ged2.exposure_t%ROWTYPE;

	-- Temporary variables, names start with _
	_total_bldgs  float;

	_bcount	ged2.bcount_t%ROWTYPE;
	_area ged2.barea_t%ROWTYPE;
	
	_genrec RECORD;
BEGIN
	-- RAISE NOTICE '!! Hello Paul: ged2.get_count_area_cost(%)', grid_id;
	
	IF (tot_pop IS NULL OR tot_pop = 0) 
	THEN
		RAISE EXCEPTION 'Total population may not be NULL OR 0' 
			USING HINT = 'Please check definition of study region';
	END IF;
	
	--
	-- TODO consider removing values which are simply copied from inputs
	--
	return_value.grid_id = grid_id;
	return_value.lat = lat;
	return_value.lon = lon;
	return_value.bldg_type = dist_values.building_type;
	return_value.occ_type = pop_alloc.occupancy_id;
	return_value.is_urban = is_urban;
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
	
	-- Initialise actual return values
	-- TODO consider using NULL
	return_value.bldg_area = -1;
	return_value.bldg_area_quality = 0;
	return_value.bldg_cost = -1;
	return_value.bldg_cost_quality = 0;
	
	return_value.bldg_fraction = 0;

	--
	-- Obtain building count (and dwelling count and bldg_fraction)
	--
	_bcount = ged2.get_building_count(
		pop_value, tot_pop, 
		ms_sum_fraction_over_dwellings, 
		study_region_facts, 
		dist_values);
		
	--RAISE NOTICE '!! Hello Paul: ged2.get_count_area_cost(%) DONE call to get_building_count %', grid_id, _bcount;
		
	return_value.bldg_count = _bcount.bldg_count;
	return_value.bldg_count_quality = _bcount.bldg_count_quality;
	return_value.bldg_fraction = _bcount.bldg_fraction;

	--RAISE NOTICE '!! Hello Paul: ged2.get_count_area_cost(%) DONE2 get_building_count', grid_id;

	
	--
	-- Obtain building area
	--
	_area = ged2.get_building_area(
		_bcount,pop_value,study_region_facts,dist_values);
	return_value.bldg_area = _area.bldg_area;
	return_value.bldg_area_quality = _area.bldg_area_quality;

	--RAISE NOTICE '!! Hello Paul: ged2.get_count_area_cost(%) DONE second select', grid_id;

	
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

	RAISE NOTICE '!! Hello Paul: ged2.get_count_area_cost(%) returning %', grid_id, return_value;

   	
	RETURN return_value; 
END;
$BODY$
  LANGUAGE plpgsql 
  IMMUTABLE  -- Does not read or change DB, output depends only on input
  COST 100;
ALTER FUNCTION ged2.get_count_area_cost(integer, double precision, 
	double precision, boolean, double precision, double precision, 
	double precision, ged2.pop_allocation, ged2.study_region_facts, 
	ged2.distribution_value)
  OWNER TO paul;
