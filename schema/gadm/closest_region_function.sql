-- Function: ged2.closest_gadm_region(geometry)

DROP TYPE IF EXISTS ged2.closest_region_t;
CREATE TYPE ged2.closest_region_t AS (
        gadm_oid integer, 
        gadm_id_0 integer, 
        gadm_id_1 integer, 
        gadm_id_2 integer, 
        gadm_id_3 integer, 
        distance float
);

CREATE OR REPLACE FUNCTION
  ged2.closest_gadm_region(grid_point_geom geometry)
RETURNS ged2.closest_region_t AS $$
DECLARE
  sql     TEXT;
  ret     ged2.closest_region;
BEGIN
  sql := ' SELECT gadm.objectid, gadm.id_0, gadm.id_1, gadm.id_2, gadm.id_3, ST_Distance(gadm.the_geom, $1) AS dist '
      || ' FROM ged2.gadm2 gadm'
      || ' WHERE ST_DWithin($1, the_geom, $2 * ($3 ^ $4))'
      || ' ORDER BY dist'
      || ' LIMIT 1';
  FOR i IN 0..10 LOOP
    EXECUTE sql INTO ret USING grid_point_geom , 0.0043 , 2 , i;
    IF ret.gadm_oid IS NOT NULL
    THEN
        RETURN ret;
    END IF;
  END LOOP;
  RETURN NULL;
END
$$ LANGUAGE 'plpgsql' STABLE;
