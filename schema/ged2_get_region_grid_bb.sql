DROP FUNCTION IF EXISTS ged2.get_region_grid_bb(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, integer, integer);

DROP FUNCTION IF EXISTS ged2.get_region_grid_bb(
	DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,
	ged2.geographic_region);

--
-- RETURN a SQL Query to obtain the grid for the given region
--
CREATE OR REPLACE FUNCTION ged2.get_region_grid_bb(
        in_min_x DOUBLE PRECISION,
        in_min_y DOUBLE PRECISION,
        in_max_x DOUBLE PRECISION,
        in_max_y DOUBLE PRECISION,
	in_study_region_id INTEGER, in_occupancy_id INTEGER DEFAULT 0
)
  RETURNS TABLE(
  	grid_point_id INTEGER, 
  	is_urban	BOOLEAN, 
  	pop_value	DOUBLE PRECISION,
  	lon			DOUBLE PRECISION,
  	lat			DOUBLE PRECISION
  ) AS
$BODY$
DECLARE  
	distribution_record ged2.geographic_region;
BEGIN
	SELECT gr.* INTO distribution_record
		FROM ged2.study_region sr
		JOIN ged2.geographic_region gr
		  ON sr.geographic_region_id=gr.id
		WHERE sr.id = in_study_region_id;
	
	IF distribution_record IS NULL
	THEN
		RAISE EXCEPTION 
			'ged2.get_region_grid: No geographic_region found for study region %', 
			 in_study_region_id;
		RETURN;
	END IF;
	
	RETURN QUERY SELECT * FROM ged2.get_region_grid_bb( 
			in_min_x,in_min_y, in_max_x, in_max_y, 
			distribution_record);
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
;
ALTER FUNCTION ged2.get_region_grid_bb(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, integer, integer)
  OWNER TO paul;

--
--
--
CREATE OR REPLACE FUNCTION ged2.get_region_grid_bb(
        in_min_x DOUBLE PRECISION,
        in_min_y DOUBLE PRECISION,
        in_max_x DOUBLE PRECISION,
        in_max_y DOUBLE PRECISION,
	distribution_record ged2.geographic_region
)
  RETURNS TABLE(
  	grid_point_id INTEGER, 
  	is_urban	BOOLEAN, 
  	pop_value	DOUBLE PRECISION,
  	lon			DOUBLE PRECISION,
  	lat			DOUBLE PRECISION
  ) AS
$BODY$
DECLARE  
	_prefix VARCHAR;
	_filter VARCHAR;
BEGIN

	_prefix = 
		'SELECT id AS grid_point_id, is_urban, pop_value, ' ||
		' ST_X(the_geom) AS lon, ST_Y(the_geom) AS lat ' || 
		' FROM ged2.grid_point ';

	_filter = format(' AND the_geom && ST_MakeEnvelope(%s,%s,%s,%s,4526)',
			in_min_x,in_min_y,in_max_x,in_max_y);
	
	IF distribution_record.custom_geography_id IS NOT NULL 
	THEN
		RETURN QUERY EXECUTE _prefix ||
				'AS grid INNER JOIN ged2.custom_geography custom ' || 
				' ON contains(transform(custom.the_geom, 4326), ' || 
				'	  			transform(grid.the_geom, 4326))' ||
				' WHERE custom.id = $1' ||
				_filter
		 USING distribution_record.custom_geography_id;
		
	ELSIF distribution_record.gadm_admin_3_id IS NOT NULL 
	THEN
		RETURN QUERY EXECUTE _prefix ||
			'WHERE gadm_admin_3_id = $1 ' 
			|| _filter 
		 USING distribution_record.gadm_admin_3_id;
	ELSIF distribution_record.gadm_admin_2_id IS NOT NULL
	THEN
		RETURN QUERY EXECUTE _prefix || 
			'WHERE gadm_admin_2_id = $1' ||
			_filter
		 USING
			distribution_record.gadm_admin_2_id;
			
	ELSIF distribution_record.gadm_admin_1_id IS NOT NULL
	THEN
		RETURN QUERY EXECUTE _prefix || 
			'WHERE gadm_admin_1_id = $1'  ||
			_filter
		USING distribution_record.gadm_admin_1_id;
	ELSE 
		RETURN QUERY EXECUTE _prefix || 
			'WHERE gadm_country_id = $1' ||
			_filter
		 USING distribution_record.gadm_country_id;
	END IF;				  			
	
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
;
ALTER FUNCTION ged2.get_region_grid_bb(
	DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,DOUBLE PRECISION,
	ged2.geographic_region)
  OWNER TO paul;
