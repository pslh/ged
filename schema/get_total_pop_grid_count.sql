--
-- For all regions with a null total population
-- Calculate the total population and update the table
--
WITH gr AS (
  SELECT * FROM ged2.geographic_region WHERE tot_pop IS NULL
),
grid AS (
  SELECT gr.id AS gr_id, (ged2.get_region_grid(gr)).* FROM gr
),
totals AS (
SELECT gr_id, 
  SUM(pop_value) AS total_population, COUNT(*) AS total_grid_count 
  FROM grid GROUP BY gr_id
)
UPDATE ged2.geographic_region gr 
   SET tot_pop_source='GED/GRUMP', tot_pop_date=CURRENT_DATE, tot_pop=totals.total_population 
  FROM totals WHERE totals.gr_id=gr.id
