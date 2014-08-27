

--
-- Check facts
--
WITH 
  srids AS (SELECT id FROM ged2.study_region WHERE study_id = 450), 
  dgids AS (
    SELECT id FROM ged2.distribution_group 
     WHERE study_region_id IN (SELECT id FROM srids)
  )
SELECT f.id,sr.study_id FROM ged2.study_region_facts f 
  JOIN ged2.distribution_group dg ON dg.id=f.distribution_group_id
  JOIN ged2.study_region sr ON sr.id=dg.study_region_id
 WHERE f.distribution_group_id IN (SELECT id FROM dgids); 

--
-- Check values
--
WITH 
  srids AS (SELECT id FROM ged2.study_region WHERE study_id = 450), 
  dgids AS (
    SELECT id FROM ged2.distribution_group 
     WHERE study_region_id IN (SELECT id FROM srids)
  )
SELECT dv.id,sr.study_id FROM ged2.distribution_value dv
  JOIN ged2.distribution_group dg ON dg.id=dv.distribution_group_id
  JOIN ged2.study_region sr ON sr.id=dg.study_region_id
 WHERE dv.distribution_group_id IN (SELECT id FROM dgids) 


