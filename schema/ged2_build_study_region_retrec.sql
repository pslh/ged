DROP FUNCTION IF EXISTS ged2.build_study_region_retrec(numeric);

-- Function: ged2.build_study_region(numeric)

CREATE OR REPLACE FUNCTION ged2.build_study_region_retrec(
	in_study_region_id numeric)
  RETURNS SETOF text AS
$BODY$
DECLARE  
	distribution_record RECORD;
	pop_summary RECORD;	
	geo_region_id	INTEGER;
	
BEGIN
	-- entry function to generate output CSV file for a given study region  
	-- version 0.2
	-- by ZhengHui Hu, modified by Paul Henshaw
	-- last updated: 2013-10-30
   
	FOR distribution_record IN
		SELECT r.id as study_region_id, g.id as distribution_group_id, 
			g.is_urban, g.occupancy_id,
			r.geographic_region_id, 
			geo.gadm_country_id as gadm_country_id, 
			geo.gadm_admin_1_id, geo.gadm_admin_2_id, 
			geo.gadm_admin_3_id, geo.custom_geography_id,
		    	tot_pop, tot_num_dwellings, tot_num_buildings, 
			avg_peop_dwelling, avg_floor_capita, avg_peop_building,
			avg_dwelling_area            
		  FROM ged2.study_region r 
		INNER JOIN ged2.distribution_group g ON r.id=g.study_region_id
		LEFT JOIN ged2.study_region_facts rf 
			on g.id = rf.distribution_group_id
		INNER JOIN ged2.geographic_region geo 
			on r.geographic_region_id=geo.id
		where r.id=in_study_region_id
	LOOP
		-- load all grid points
		drop table if exists tmp_grid_points;

		geo_region_id := distribution_record.geographic_region_id;

		if distribution_record.custom_geography_id is not null then
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point p inner join ged2.custom_geography g on contains(transform(g.the_geom, 4326), transform(p.the_geom, 4326));
		elsif distribution_record.gadm_admin_3_id is not null then
		    create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_admin_3_id = distribution_record.gadm_admin_3_id;
		elsif distribution_record.gadm_admin_2_id is not null then
			RAISE NOTICE '** region % is admin 2: ', distribution_record.geographic_region_id;
			SELECT ged2.get_parent_geo_region_id(distribution_record.geographic_region_id) INTO geo_region_id;
			RAISE NOTICE '** Using parent pop_allocation region % : ', geo_region_id;
			create temporary table tmp_grid_points as 
				select id as grid_point_id, is_urban, pop_value, st_x(the_geom) as lon, st_y(the_geom) as lat from ged2.grid_point where gadm_admin_2_id = distribution_record.gadm_admin_2_id;
		elsif distribution_record.gadm_admin_1_id is not null then
			RAISE NOTICE '** region % is admin 1: ', distribution_record.geographic_region_id;
			SELECT ged2.get_parent_geo_region_id(distribution_record.geographic_region_id) INTO geo_region_id;
			RAISE NOTICE '** Using parent pop_allocation region % : ', geo_region_id;

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
	

	
		-- return QUERY select ged2.make_exposure_pgsql(
		return QUERY select ged2.make_exposure_pgsql_retrec(
				g.grid_point_id, g.lat, g.lon, 
				g.is_urban, g.pop_value, 
				pop_summary.total_population,
				intermediate.ms_sum_fraction_over_dwellings,
				pa.*,	-- pop_allocation
				sf.*::ged2.study_region_facts, 	-- study_region_facts
				dv.*::ged2.distribution_value)	-- dist_values				
			from tmp_grid_points g 			
			inner join ged2.pop_allocation pa on g.is_urban=pa.is_urban and pa.geographic_region_id=geo_region_id and pa.is_urban=distribution_record.is_urban and pa.occupancy_id = distribution_record.occupancy_id
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ged2.build_study_region_retrec(numeric)
  OWNER TO paul;

