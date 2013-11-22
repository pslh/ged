--
-- Produce a JSON formatted map of building type, fraction for each study
-- region in HAZUS.  Also output a sensible name, group and study_region ids
-- and a geometry of the region.
--
-- Paul Henshaw, GEM, 2013-11-21 
--
SELECT
 	bf_map.dg_id,
 	sr.id AS sr_id,
 	dg.is_urban,
 	CONCAT_WS(', ', gadm.name_0, gadm.name_1, gadm.name_2) AS name,
 	bf_map.bf_json,
 	gadm.the_geom
FROM (
	SELECT 
		bf.dg_id,
		('{' ||
	  		string_agg(
	  			CONCAT('"',bf.building_type,'":',bf.building_fraction),
	  			', ') ||
	  	  '}') AS bf_json  -- JSON string of (type, fraction) pairs
  	FROM (
  		SELECT 
			dg.id AS dg_id, dv.building_type, dv.building_fraction 
		FROM ged2.distribution_value dv
	  	JOIN ged2.distribution_group dg
	      ON dv.distribution_group_id=dg.id
	  	JOIN ged2.study_region sr
	      ON dg.study_region_id=sr.id
	  	JOIN ged2.study s
	      ON s.id=sr.study_id
	 	WHERE s.name='HAZUS'   
	      AND dg.is_urban
	 	ORDER BY dg.id ASC, dv.building_fraction DESC
	) AS bf -- building fractions ordered by group id, descending fraction value 
	GROUP BY bf.dg_id
	ORDER BY bf.dg_id
) AS bf_map -- building fractions as a map for each group id
JOIN ged2.distribution_group dg
  ON dg.id=bf_map.dg_id
JOIN ged2.study_region sr
  ON dg.study_region_id=sr.id
JOIN ged2.geographic_region gr
  ON gr.id = sr.geographic_region_id
JOIN ged2.geographic_region_gadm	grg
  ON grg.region_id=gr.id
JOIN ged2.gadm2 gadm
  ON gadm.objectid=(
    CASE
    	WHEN gr.gadm_admin_3_id IS NOT NULL 
        THEN gr.gadm_admin_3_id
    	WHEN gr.gadm_admin_2_id IS NOT NULL 
        THEN gr.gadm_admin_2_id
        WHEN gr.gadm_admin_1_id IS NOT NULL 
        THEN gr.gadm_admin_1_id
        WHEN gr.gadm_country_id IS NOT NULL 
        THEN gr.gadm_country_id
        ELSE NULL
    END
	)
ORDER BY sr.id  
