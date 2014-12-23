SELECT bc.* 
  FROM ged2.build_study_region_retrec(185) AS bc
  JOIN ged2.grid_point AS grid ON grid.id=bc.grid_id

  -- WHERE ST_Intersects(grid.the_geom,  ST_MakeEnvelope(9, 45, 9.1, 45.1, 4326)) -- 146s
  WHERE grid.the_geom && ST_MakeEnvelope(
	37.60, 55.74, 37.62, 55.76,
	4326)
  ORDER BY grid_id, bldg_type, occ_type
