-- Function: ged2.make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value)

DROP FUNCTION IF EXISTS paul.make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);
DROP FUNCTION IF EXISTS ged2.make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);

CREATE OR REPLACE FUNCTION ged2.make_exposure_pgsql(grid_id bigint, lat double precision, lon double precision, is_urban boolean, pop_value double precision, tot_pop double precision, ms_sum_fraction_over_dwellings double precision, pop_alloc ged2.pop_allocation, study_region_facts ged2.study_region_facts, dist_values ged2.distribution_value)
  RETURNS text AS
$BODY$
DECLARE
  bldg_type character varying(100);
  occ_type  integer;
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

--	RAISE NOTICE '##### Method 5, tot buildings=% bf=% count=%', 
--		study_region_facts.tot_num_buildings,dist_values.building_fraction, bldg_count;

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
   --return grid_id || ',' || lon || ',' || lat || ',"' || bldg_type || '","' || occ_type || '",' || is_urban || ',' || dwelling_fraction || ',' || bldg_fraction || ',' 
    --    || type_pop || ',' || day_pop || ',' || night_pop || ',' || transit_pop || ',' 
     --   || bldg_count || ',' || bldg_count_quality || ',' || bldg_area || ',' || bldg_area_quality || ',' || bldg_cost  || ',' || bldg_cost_quality;


    --
    -- Use CONCAT rather than || since some of the values may
    -- be NULL and 
    --   x || NULL == NULL  for any x
    --
    RETURN CONCAT(
	grid_id , ',' , lon , ',' , lat , ',"' , 
	bldg_type , '",' , occ_type , ',' , is_urban , ',' , 
	dwelling_fraction , ',' , bldg_fraction , ',' , 
	type_pop , ',' , day_pop , ',' , night_pop , ',' , transit_pop , ',' , 
	bldg_count , ',' , bldg_count_quality , ',' , 
	bldg_area , ',' , bldg_area_quality , ',' , 
	bldg_cost  , ',' , bldg_cost_quality
    );

--   outstring = grid_id || ',' || lon || ',' || lat || ',"' || bldg_type || '","' || occ_type || '",' || is_urban || ',' || dwelling_fraction || ',' || bldg_fraction || ',' 
 --       || type_pop || ',' || day_pop || ',' || night_pop || ',' || transit_pop || ',' 
  --      || bldg_count || ',' || bldg_count_quality || ',' || bldg_area || ',' || bldg_area_quality || ',' || bldg_cost  || ',' || bldg_cost_quality;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ged2.make_exposure_pgsql(bigint, double precision, double precision, boolean, double precision, double precision, double precision, ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value)
  OWNER TO paul;

