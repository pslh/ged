DROP FUNCTION IF EXISTS ged2.build_study_region_retrec(numeric);
DROP FUNCTION IF EXISTS ged2.build_study_region_retrec(INTEGER, INTEGER);


-- Function: ged2.build_study_region(numeric)

CREATE OR REPLACE FUNCTION ged2.build_study_region_retrec(
	in_study_region_id INTEGER, in_occupancy_id INTEGER DEFAULT 0)
  RETURNS SETOF ged2.exposure_t AS
$BODY$
DECLARE  
	distribution_record RECORD;
	pop_summary RECORD;	
	geo_region_id	INTEGER;
	
	return_value ged2.exposure_t;
	ret_rec RECORD;
BEGIN
	-- entry function to generate output CSV file for a given study region  
	-- version 0.2
	-- by ZhengHui Hu, modified by Paul Henshaw
	-- last updated: 2013-10-30
   
	FOR distribution_record IN
		SELECT r.id AS study_region_id, g.id AS distribution_group_id, 
			g.is_urban, g.occupancy_id,
			r.geographic_region_id, 
			geo.gadm_country_id AS gadm_country_id, 
			geo.gadm_admin_1_id, geo.gadm_admin_2_id, 
			geo.gadm_admin_3_id, geo.custom_geography_id,
		    	tot_pop, tot_num_dwellings, tot_num_buildings, 
			avg_peop_dwelling, avg_floor_capita, avg_peop_building,
			avg_dwelling_area            
		  FROM ged2.study_region r 
		INNER JOIN ged2.distribution_group g ON r.id=g.study_region_id
		LEFT JOIN ged2.study_region_facts rf 
			ON g.id = rf.distribution_group_id
		INNER JOIN ged2.geographic_region geo 
			ON r.geographic_region_id=geo.id
		WHERE r.id=in_study_region_id AND g.occupancy_id=in_occupancy_id
	LOOP
		-- load all grid points
		drop table if exists tmp_grid_points;

		geo_region_id := distribution_record.geographic_region_id;

		IF distribution_record.custom_geography_id IS NOT NULL 
		THEN
			CREATE TEMPORARY TABLE tmp_grid_points AS 
				SELECT id AS grid_point_id, is_urban, pop_value, 
						ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat 
				  FROM ged2.grid_point p 
				  INNER JOIN ged2.custom_geography g 
				  ON contains(transform(g.the_geom, 4326), 
				  			transform(p.the_geom, 4326));
		ELSIF distribution_record.gadm_admin_3_id IS NOT NULL 
		THEN
		    CREATE TEMPORARY TABLE tmp_grid_points AS 
				SELECT id AS grid_point_id, is_urban, pop_value, 
					ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat 
				  FROM ged2.grid_point 
				 WHERE gadm_admin_3_id = distribution_record.gadm_admin_3_id;
		ELSIF distribution_record.gadm_admin_2_id IS NOT NULL 
		THEN
			RAISE NOTICE '** region % is admin 2: ', 
				distribution_record.geographic_region_id;
			SELECT ged2.get_parent_geo_region_id(
					distribution_record.geographic_region_id) 
			  INTO geo_region_id;
			RAISE NOTICE '** Using parent pop_allocation region % : ', 
				geo_region_id;
			CREATE TEMPORARY TABLE tmp_grid_points AS 
				SELECT id AS grid_point_id, is_urban, pop_value, 
						ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat 
				  FROM ged2.grid_point 
				 WHERE gadm_admin_2_id = distribution_record.gadm_admin_2_id;
		ELSIF distribution_record.gadm_admin_1_id IS NOT NULL THEN
			RAISE NOTICE '** region % is admin 1: ', 
					distribution_record.geographic_region_id;
			SELECT ged2.get_parent_geo_region_id(
						distribution_record.geographic_region_id) 
			  INTO geo_region_id;
			RAISE NOTICE '** Using parent pop_allocation region % : ', 
				geo_region_id;

			CREATE TEMPORARY TABLE tmp_grid_points AS 
				SELECT id AS grid_point_id, is_urban, pop_value, 
						ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat 
				  FROM ged2.grid_point 
				 WHERE gadm_admin_1_id = distribution_record.gadm_admin_1_id;
		ELSE
			CREATE TEMPORARY TABLE tmp_grid_points AS 
				SELECT id AS grid_point_id, is_urban, pop_value, 
					ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat 
			 FROM ged2.grid_point 
			WHERE gadm_country_id = distribution_record.gadm_country_id;
		END IF;

		-- get total population count
		SELECT SUM(pop_value) AS total_population, COUNT(*) AS total_grid_count 
		  FROM tmp_grid_points t 
		  INTO pop_summary;
		RAISE NOTICE 'grid_summary %', pop_summary;
		
		--
		-- 
		--
		FOR ret_rec IN 
		 SELECT --ged2.get_count_area_cost(
				g.grid_point_id, g.lat, g.lon, 
				g.is_urban, g.pop_value, 
				pop_summary.total_population,
				intermediate.ms_sum_fraction_over_dwellings,
				(pa) AS rpa,	-- pop_allocation
				(sf) AS rsf, 	-- study_region_facts
				(dv) AS rdv		-- dist_values
				--)				
			FROM tmp_grid_points g 			
			INNER JOIN ged2.pop_allocation pa 
			  ON g.is_urban=pa.is_urban AND 
			  	 pa.geographic_region_id=geo_region_id AND 
			  	 pa.is_urban=distribution_record.is_urban AND 
			  	 pa.occupancy_id = distribution_record.occupancy_id
			LEFT JOIN ged2.study_region_facts sf ON 
				 sf.distribution_group_id=
				 	distribution_record.distribution_group_id
			LEFT JOIN ged2.distribution_value dv ON 
				  dv.distribution_group_id=
				  	distribution_record.distribution_group_id
			INNER JOIN 
				(SELECT distribution_group_id, sum( 
					case when avg_dwelling_per_build > 0 
						THEN dwelling_fraction / avg_dwelling_per_build 
						else 0 
					 end ) ms_sum_fraction_over_dwellings
				   FROM ged2.distribution_value 
				  WHERE distribution_group_id = 
				  	distribution_record.distribution_group_id
				group by distribution_group_id) intermediate 
			ON intermediate.distribution_group_id = 
				distribution_record.distribution_group_id
		LOOP
			-- RAISE NOTICE '@@@ Hello Paul: ged2.build_study_region_retrec: rec= %', ret_rec;
			return_value=ged2.get_count_area_cost(
				ret_rec.grid_point_id, ret_rec.lat, ret_rec.lon, 
				ret_rec.is_urban, ret_rec.pop_value, 
				ret_rec.total_population,
				ret_rec.ms_sum_fraction_over_dwellings,
				ret_rec.rpa,	-- pop_allocation
				ret_rec.rsf::ged2.study_region_facts, 	-- study_region_facts
				ret_rec.rdv::ged2.distribution_value

			);
			-- RAISE NOTICE '@@@ Hello Paul: ged2.build_study_region_retrec: returning %', return_value;
			RETURN NEXT return_value;
		END LOOP;
		--RAISE NOTICE 'ged2.build_study_region_retrec: returning %', return_value;
		--return NEXT return_value;
	END LOOP;
	-- running the script
	-- copy (SELECT ged2.build_study_region(252)) to '/home/zhu/population_scripts/output.csv';
	-- SELECT ged2.build_study_region(15) limit 10;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION ged2.build_study_region_retrec(INTEGER, INTEGER)
  OWNER TO paul;

