DROP FUNCTION IF EXISTS ged2.get_building_count(
	 double precision, 
	 double precision, 
	 double precision, 
	 ged2.study_region_facts, 
	 ged2.distribution_value);


--
-- Calculate building count, and bldg_count_quality  
-- Depending on method used may also set dwellings_count
--
CREATE OR REPLACE FUNCTION ged2.get_building_count(
	pop_value double precision, 
	tot_pop double precision, 
	ms_sum_fraction_over_dwellings double precision, 
	study_region_facts ged2.study_region_facts, 
	dist_values ged2.distribution_value)
  RETURNS ged2.bcount_t AS
$BODY$
DECLARE
	return_value	ged2.bcount_t%ROWTYPE;
	
	_total_bldgs  float;
BEGIN	
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
		return_value.dwellings_count = NULL;

   	-- method 4 
	ELSIF (	study_region_facts.tot_num_buildings IS NOT NULL AND 	
      		dist_values.dwelling_fraction IS NOT NULL AND
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
		return_value.dwellings_count = NULL;

   	-- method 3
	ELSIF (study_region_facts.tot_num_dwellings IS NOT NULL AND
	       dist_values.avg_dwelling_per_build is not null) 
	THEN
      	return_value.dwellings_count = (pop_value / tot_pop) * 
      		study_region_facts.tot_num_dwellings * 
      			dist_values.dwelling_fraction;      
      	return_value.bldg_count = return_value.dwellings_count / 
      		dist_values.avg_dwelling_per_build;      
      	return_value.bldg_count_quality = 3;
      	
   	-- method 2 
	ELSIF (	study_region_facts.avg_peop_dwelling IS NOT NULL AND		
       		dist_values.avg_dwelling_per_build IS NOT NULL) 
    THEN
      	return_value.dwellings_count = (pop_value * 
      		dist_values.dwelling_fraction) / 
      		study_region_facts.avg_peop_dwelling;
      	return_value.bldg_count = return_value.dwellings_count / 
      		dist_values.avg_dwelling_per_build;
      	return_value.bldg_count_quality = 2;

   	-- method 1
   	ELSIF (	study_region_facts.avg_peop_building IS NOT NULL AND		
       		dist_values.dwelling_fraction IS NOT NULL AND
       		ms_sum_fraction_over_dwellings <> 0 ) 
	THEN
      	_total_bldgs = pop_value / study_region_facts.avg_peop_building;
      	IF (dist_values.building_fraction IS NOT NULL) 
      	THEN
         	return_value.bldg_fraction = dist_values.building_fraction;
      	ELSE
			return_value.bldg_fraction = (dist_values.dwelling_fraction / 
				dist_values.avg_dwelling_per_build ) / 
					ms_sum_fraction_over_dwellings; 
      	END IF;
      	return_value.bldg_count = _total_bldgs * bldg_fraction;
      	return_value.bldg_count_quality = 1;
      	return_value.dwellings_count = NULL;
   	ELSE
   		RAISE WARNING 'No suitable building count method found, returning NULL';
		RETURN NULL;
   	END IF;
   
   	--RAISE NOTICE '!! Hello Paul: ged2.get_building_count: RETURNING %',
	--	return_value;
   	
   	RETURN return_value; 
END;
$BODY$
  LANGUAGE plpgsql 
  IMMUTABLE  -- Does not read or change DB, output depends only on input
  COST 100;
ALTER FUNCTION ged2.get_building_count(
	 double precision, 
	 double precision, 
	 double precision, 
	 ged2.study_region_facts, 
	 ged2.distribution_value)
  OWNER TO paul;
