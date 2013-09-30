CREATE TABLE temp.gadm2unified AS 
  SELECT names.*, gadm.the_geom 
    FROM temp.gadm2names names 
    JOIN temp.gadm2 gadm 
      ON gadm.objectid=names.objectid;

SELECT Populate_Geometry_Columns('temp.gadm2unified'::regclass);

ALTER TABLE temp.gadm2unified ADD PRIMARY KEY (objectid);
CREATE INDEX ON temp.gadm2unified (the_geom) USING GIST;
CREATE INDEX ON temp.gadm2unified USING GIST (the_geom);

