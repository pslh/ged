--
-- For all regions with a null total population
-- Calculate the total population and update the table
--
WITH gr AS (
  -- Find regions without a tot_pop set
  SELECT * FROM ged2.geographic_region
   WHERE tot_pop IS NULL
),
grid AS (
  -- Obtain the grid points for these regions
  SELECT gr.id AS gr_id, (ged2.get_region_grid(gr)).* FROM gr
),
totals AS (
  -- Obtain the total number of grid points, population and
  -- the georaphic extent of each region
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

--
-- Set 0/NULL values for any regions with 0
-- grid cells - for example Antartica
--
WITH gr AS (
  SELECT * FROM ged2.geographic_region
   WHERE tot_pop IS NULL
),
grid AS (
  SELECT gr.id AS gr_id, (ged2.get_region_grid(gr)).* FROM gr
),
totals AS (
  SELECT gr.id AS gr_id, COUNT(grid.*) AS num_cells
    FROM gr 
    LEFT JOIN grid ON grid.gr_id=gr.id 
    GROUP BY gr.id
)
UPDATE ged2.geographic_region gr
   SET tot_pop_source='GED/GRUMP', tot_pop_date=CURRENT_DATE,
       tot_pop=0,
       tot_grid_count=0,
       bounding_box=NULL
  FROM totals
 WHERE totals.gr_id=gr.id;
