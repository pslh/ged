--
-- For all regions with a null total population
-- Calculate the total population and update the table
--
WITH gr AS (
  SELECT * FROM ged2.geographic_region
-- WHERE id=244
-- WHERE id IN (111,244)
 --WHERE id=111
 WHERE tot_pop IS NULL
),
grid AS (
  SELECT gr.id AS gr_id, (ged2.get_region_grid(gr)).* FROM gr
),
totals AS (
SELECT gr_id,
  SUM(grid.pop_value) AS total_population, COUNT(*) AS total_grid_count ,
  CASE 
  WHEN COUNT(*) = 1 THEN
    -- Handle case where region is only a single cell: 
    -- add a buffer with a half-cell radius and recalculate extent
    ST_SetSRID(ST_Extent(ST_Buffer(gp.the_geom,0.0042)),4326) 
  WHEN COUNT(*) = 0 THEN
    NULL
  ELSE
    ST_SetSRID(ST_Extent(gp.the_geom),4326) 
  END AS bounding_box
  FROM grid
  JOIN ged2.grid_point gp ON gp.id=grid.grid_point_id
  GROUP BY gr_id
) 
--SELECT gr_id, total_population, total_grid_count, bounding_box
  -- ST_XMin(bounding_box) AS xmin, ST_YMin(bounding_box) AS ymin, 
  -- ST_XMax(bounding_box) AS xmax, ST_YMax(bounding_box) AS ymax 
--  FROM totals;

-- RAISE NOTICE 'gr_id=% geometrytype=%, text=%', gr_id, geometrytype(bounding_box), ST_AsText(bounding_box);
--
-- Update ged2.geographic_region to add values from totals
--

UPDATE ged2.geographic_region gr 
   SET tot_pop_source='GED/GRUMP', tot_pop_date=CURRENT_DATE, 
       tot_pop=totals.total_population,
       tot_grid_count=totals.total_grid_count,
       bounding_box=totals.bounding_box
  FROM totals 
 WHERE totals.gr_id=gr.id;

-- SELECT 
-- 	totals.gr_id AS gr_id,
-- 	totals.total_population AS tot_pop, 
-- 	totals.total_grid_count AS tot_grid_count,
-- 	totals.bounding_box AS bounding_box
--  INTO paul.tot_pop_grid_count
--  FROM totals 
