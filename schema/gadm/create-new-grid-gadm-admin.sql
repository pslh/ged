CREATE TABLE paul.new_grid AS (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	a2.id AS gadm_admin_id_2, 
	a3.id AS gadm_admin_id_3 
  FROM ged2.grid_point grid 
  JOIN paul.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  JOIN ged2.gadm_admin_2 a2 ON (a2.gadm_admin_1_id=a1.id AND a2.gadm_id_2=gcr.gadm_id_2) 
  JOIN ged2.gadm_admin_3 a3 ON (a3.gadm_admin_2_id=a2.id AND a3.gadm_id_3=gcr.gadm_id_3) 
);  

INSERT INTO paul.new_grid (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	a2.id AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM ged2.grid_point grid 
  JOIN paul.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  JOIN ged2.gadm_admin_2 a2 ON (a2.gadm_admin_1_id=a1.id AND a2.gadm_id_2=gcr.gadm_id_2) 
  WHERE gcr.gadm_id_3 IS NULL 
);

INSERT INTO paul.new_grid (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	a1.id AS gadm_admin_1_id, 
	NULL AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM ged2.grid_point grid 
  JOIN paul.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  JOIN ged2.gadm_admin_1 a1 ON ( a1.gadm_country_id=gcr.gadm_id_0 AND a1.gadm_id_1=gcr.gadm_id_1 ) 
  WHERE gcr.gadm_id_2 IS NULL 
);

INSERT INTO paul.new_grid (
SELECT grid.id, grid.is_urban, grid.pop_value, grid.land_area, grid.the_geom, gcr.distance, 
	gcr.gadm_id_0 AS gadm_country_id, 
	NULL AS gadm_admin_1_id, 
	NULL AS gadm_admin_id_2,
 	NULL AS gadm_admin_id_3
  FROM ged2.grid_point grid 
  JOIN paul.grid_closest_region gcr ON grid.id=gcr.grid_point_id 
  WHERE gcr.gadm_id_1 IS NULL 
);
