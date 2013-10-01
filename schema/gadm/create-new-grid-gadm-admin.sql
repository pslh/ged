--
-- Create new grid table from temporary grid
-- Replacing GADM id_0, id_1, id_2, id_3 with 
-- ids of gadm_* link tables
--

--
-- Create new grid table, populate with those points which
-- have ids at all admin levels from 0 to 3
--
CREATE TABLE ged2.grid_point AS (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	a2.id AS gadm_admin_id_2, 
	a3.id AS gadm_admin_id_3 
  FROM temp.grump_pop grid 
  JOIN temp.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  JOIN ged2.gadm_admin_2 a2 ON (a2.gadm_admin_1_id=a1.id AND a2.gadm_id_2=gcr.gadm_id_2) 
  JOIN ged2.gadm_admin_3 a3 ON (a3.gadm_admin_2_id=a2.id AND a3.gadm_id_3=gcr.gadm_id_3) 
);  

--
-- Add points which have ids at all admin levels from 0 to 2
-- but not 3
--
INSERT INTO ged2.grid_point (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	a2.id AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM temp.grump_pop grid 
  JOIN temp.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  JOIN ged2.gadm_admin_2 a2 ON (a2.gadm_admin_1_id=a1.id AND a2.gadm_id_2=gcr.gadm_id_2) 
  WHERE gcr.gadm_id_3 IS NULL 
);

--
-- Add points which have ids at all admin level 1 but not 2 or 3
--
INSERT INTO ged2.grid_point (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	NULL AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM temp.grump_pop grid 
  JOIN temp.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  WHERE gcr.gadm_id_2 IS NULL 
);

--
-- Add points which have ids only at national level
--
INSERT INTO ged2.grid_point (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	NULL AS gadm_admin_1_id, 
	NULL AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM temp.grump_pop grid 
  JOIN temp.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  WHERE gcr.gadm_id_1 IS NULL 
);
