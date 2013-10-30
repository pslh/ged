--
-- geographic_region_id of parent country given the
-- geographic_region_id of a GADM 2 region
--
DROP FUNCTION IF EXISTS paul.get_parent_geo_region_id_g2(geo_region_id integer);
DROP FUNCTION IF EXISTS ged2.get_parent_geo_region_id_g2(geo_region_id integer);
CREATE OR REPLACE FUNCTION ged2.get_parent_geo_region_id_g2(
	geo_region_id integer)
  RETURNS integer AS
$BODY$
DECLARE
  parent_gr_id integer;
BEGIN
	--
	-- Note that at the time of writing, there were no geographic_region
	-- entries parent GADM admin 1 regions of GADM admin 2 regions.  So
	-- we skip directly from the admin 2 to the country id.
	--
	SELECT parent.id INTO parent_gr_id
	  FROM ged2.geographic_region AS gr 
	  JOIN ged2.gadm_admin_2 g2 
	    ON g2.id=gr.gadm_admin_2_id 
	  JOIN ged2.gadm_admin_1 g1
	    ON g2.gadm_admin_1_id=g1.id
	  JOIN ged2.geographic_region AS parent 
	    ON parent.gadm_country_id=g1.gadm_country_id 
	 WHERE gr.id = geo_region_id;
	RETURN parent_gr_id;
END
$BODY$
  LANGUAGE plpgsql STABLE COST 100;
