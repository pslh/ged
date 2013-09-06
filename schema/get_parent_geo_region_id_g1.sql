--
-- geographic_region_id of parent country given the
-- geographic_region_id of a GADM 1 region
--
DROP FUNCTION IF EXISTS paul.get_parent_geo_region_id_g1(geo_region_id integer);
CREATE OR REPLACE FUNCTION paul.get_parent_geo_region_id_g1(
	geo_region_id integer)
  RETURNS integer AS
$BODY$
DECLARE
  parent_gr_id integer;
BEGIN
	SELECT parent.id INTO parent_gr_id
	  FROM ged2.geographic_region AS gr
	  JOIN ged2.gadm_admin_1 g1
	    ON g1.id=gr.gadm_admin_1_id
	  JOIN ged2.geographic_region AS parent
	    ON parent.gadm_country_id=g1.gadm_country_id
	 WHERE gr.id=geo_region_id;
	RETURN parent_gr_id;
END
$BODY$
  LANGUAGE plpgsql STABLE COST 100;
