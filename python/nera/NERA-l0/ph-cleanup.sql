--
-- Remove study_region_facts for study 450 (unified NERA)
--
WITH 
  srids AS (SELECT id FROM ged2.study_region WHERE study_id = 450), 
  dgids AS (
    SELECT id FROM ged2.distribution_group 
     WHERE study_region_id IN (SELECT id FROM srids)
  )
DELETE FROM ged2.study_region_facts 
 WHERE distribution_group_id IN (SELECT id FROM dgids) ;

--
-- Remove distribution_value for study 450 (unified NERA)
--
WITH 
  srids AS (SELECT id FROM ged2.study_region WHERE study_id = 450), 
  dgids AS (
    SELECT id FROM ged2.distribution_group 
     WHERE study_region_id IN (SELECT id FROM srids)
  )
DELETE FROM ged2.distribution_value 
 WHERE distribution_group_id IN (SELECT id FROM dgids) ;

--
-- Remove distribution_group for study 450
--
WITH 
  srids AS (SELECT id FROM ged2.study_region WHERE study_id = 450) 
DELETE FROM ged2.distribution_group
 WHERE study_region_id IN (SELECT id FROM srids);

--
-- Finally remove study_regions for study;
--
DELETE FROM ged2.study_region WHERE study_id = 450;

