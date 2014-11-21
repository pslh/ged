DROP FUNCTION IF EXISTS ged2.build_study_region_retrec_bb(
DOUBLE PRECISION,
DOUBLE PRECISION,
DOUBLE PRECISION,
DOUBLE PRECISION,
INTEGER, INTEGER);

-- Function: ged2.build_study_region(numeric)

CREATE OR REPLACE FUNCTION 
ged2.build_study_region_retrec_bb(
	in_min_x DOUBLE PRECISION,
	in_min_y DOUBLE PRECISION,
	in_max_x DOUBLE PRECISION,
	in_max_y DOUBLE PRECISION,
	in_study_region_id INTEGER, 
	in_occupancy_id INTEGER DEFAULT 0)
  RETURNS SETOF ged2.exposure_t AS
$BODY$
DECLARE  
	distribution_record RECORD;
	_geo_region_id	INTEGER;
	
	return_value ged2.exposure_t;
	ret_rec RECORD;
BEGIN
	-- entry function to generate output CSV file for a given study region  
	-- version 0.2
	-- by ZhengHui Hu, modified by Paul Henshaw
	-- last updated: 2013-10-30

	FOR distribution_record IN
		--
		-- Obtain all distribution_groups, facts and geographic_region info
		-- for the given study_region 
		-- - this query is fast and returns 0-4 rows: 0 means not present,
		-- 4 means that we have urban, rural, res and non-res studies
		--
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

	-- For each distribution group...
	LOOP
		-- Obtain the ID of the "parent" region which contains the specified region
		_geo_region_id := ged2.get_parent_geo_region_id(
					distribution_record.geographic_region_id);
		
		-- For each (grid point, material-type) combination in the region...
	  	FOR ret_rec IN 	
	  		--
	  		-- Use WITH statement rather than temporary table since this
	  		-- permits use with read-only connections and STABLE type
	  		--
			WITH tmp_grid_points AS (
				-- Obtain grid for specified region 
				SELECT * FROM ged2.get_region_grid_bb(
					in_min_x,in_min_y,in_max_x,in_max_y,
					distribution_record.study_region_id)
			),
			pop_summary AS (
				-- Obtain total population count for WHOLE region
				SELECT SUM(pop_value) AS total_population, COUNT(*) AS total_grid_count
					FROM ged2.get_region_grid(distribution_record.study_region_id)
			)
		 	SELECT 
				g.grid_point_id, g.lat, g.lon, 
				g.is_urban, g.pop_value, 
				pop_summary.total_population,
				intermediate.ms_sum_fraction_over_dwellings,
				(pa) AS rpa,	-- pop_allocation
				(sf) AS rsf, 	-- study_region_facts
				(dv) AS rdv	-- dist_values
			FROM tmp_grid_points g
			LEFT OUTER JOIN pop_summary ON TRUE
			INNER JOIN ged2.pop_allocation pa 
			  ON g.is_urban=pa.is_urban AND 
			  	 pa.geographic_region_id=_geo_region_id AND 
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
			--
			-- Return values in an exposure record
			--		
			return_value=ged2.get_count_area_cost(
				ret_rec.grid_point_id, ret_rec.lat, ret_rec.lon, 
				ret_rec.is_urban, ret_rec.pop_value, 
				ret_rec.total_population,
				ret_rec.ms_sum_fraction_over_dwellings,
				ret_rec.rpa,				-- pop_allocation
				ret_rec.rsf::ged2.study_region_facts, 	-- study_region_facts
				ret_rec.rdv::ged2.distribution_value
			);
			RETURN NEXT return_value;
		END LOOP;
	END LOOP;
END;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100
  ROWS 1000;
ALTER FUNCTION ged2.build_study_region_retrec_bb(
DOUBLE PRECISION,
DOUBLE PRECISION,
DOUBLE PRECISION,
DOUBLE PRECISION,
INTEGER, INTEGER)
  OWNER TO paul;

