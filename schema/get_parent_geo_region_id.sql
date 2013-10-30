--
-- geographic_region_id of parent country given the
-- geographic_region_id of a GADM 2 region
--
DROP FUNCTION IF EXISTS paul.get_parent_geo_region_id(geo_region_id integer);
DROP FUNCTION IF EXISTS ged2.get_parent_geo_region_id(geo_region_id integer);
CREATE OR REPLACE FUNCTION ged2.get_parent_geo_region_id(
	geo_region_id integer)
  RETURNS integer AS
$BODY$
DECLARE
  parent_gr_id integer;
  rec record;
BEGIN
	-- find out which admin level region is
	-- if g1 use g1 function otherwise use g2

	SELECT * INTO rec
	  FROM ged2.geographic_region AS gr 
	 WHERE gr.id = geo_region_id;

	if rec IS NULL
	THEN
		RAISE EXCEPTION
			'ged2.get_parent_geo_region_id(%): region not found', 
			geo_region_id;
	END IF;

	CASE 
	  WHEN rec.gadm_admin_2_id IS NOT NULL
	  THEN
		SELECT INTO parent_gr_id 
			ged2.get_parent_geo_region_id_g2(geo_region_id);
		RETURN parent_gr_id;

	  WHEN rec.gadm_admin_1_id IS NOT NULL
	  THEN
		SELECT INTO parent_gr_id 
			ged2.get_parent_geo_region_id_g1(geo_region_id);
		RETURN parent_gr_id;

	  WHEN rec.gadm_country_id IS NOT NULL
	  THEN
		-- already a country, no parent 
		-- raise EXCEPTION? return geo_region_id?
		RETURN geo_region_id;

	  WHEN rec.gadm_admin_3_id IS NOT NULL
	  THEN
		-- There is no admin 3 data available, so I could write
		-- but not test a suitable function
		RAISE EXCEPTION 
			'ged2.get_parent_geo_region_id(%): %',
			geo_region_id,
			'no support for finding parents of admin 3 regions.';
	  
	  WHEN rec.custom_geography_id IS NOT NULL
	  THEN
		-- It is not at all clear what the parent of a custom region
		-- might be
		RAISE EXCEPTION 
			'ged2.get_parent_geo_region_id(%): %',
			geo_region_id,
			'no support for finding parents of custom regions.';

	  ELSE 
		-- This should not happen and may indicate that the schema
		-- has changed or the DB is corrupt
		RAISE EXCEPTION 
			'ged2.get_parent_geo_region_id(%): %',
			geo_region_id,
			'SERIOUS ERROR - no region id found';
		
	END CASE;
END
$BODY$
  LANGUAGE plpgsql STABLE COST 100;
