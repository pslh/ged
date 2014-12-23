SELECT * 
  FROM ged2.build_study_region_retrec_bb(
	37.60, 55.74, 37.62, 55.76,
	185) 
  ORDER BY grid_id, bldg_type, occ_type
