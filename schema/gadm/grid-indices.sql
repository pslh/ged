--
-- Register geometry column 
--
SELECT Populate_Geometry_Columns('ged2.grid_point'::regclass);

--
-- Create GIST index for geometry
--
CREATE INDEX ON ged2.grid_point USING gist(the_geom);

--
-- CREATE indices for ids to region tables
--
CREATE INDEX ON ged2.grid_point(gadm_country_id);
CREATE INDEX ON ged2.grid_point(gadm_admin_1_id);
CREATE INDEX ON ged2.grid_point(gadm_admin_2_id);
CREATE INDEX ON ged2.grid_point(gadm_admin_3_id);
