WITH gr AS (
  SELECT * FROM ged2.geographic_region 
-- WHERE id IN (111, 131) 
-- LIMIT 3
),
grid AS (
  SELECT gr.id AS gr_id, (ged2.get_region_grid(gr)).* FROM gr
)
SELECT gr_id, 
  SUM(pop_value) AS total_population, COUNT(*) AS total_grid_count 
  INTO paul.tot_pop_grid_count
  FROM grid GROUP BY gr_id

