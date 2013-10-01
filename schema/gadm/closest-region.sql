COPY (SELECT grid.id, ged2.closest_gadm_region(grid.the_geom) FROM ged2.grid_point grid) TO STDOUT (FORMAT CSV);
