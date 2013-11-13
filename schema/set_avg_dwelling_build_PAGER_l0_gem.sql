--
-- Procedure to update PAGER dwelling fractions with default
-- values provided by Helen 
-- 
-- NOTE that this is for a second run, when most studies
-- already have non-NULL values for avg_dwelling_per_build
-- we only want to update those studies which do not already
-- have a non-NULL value.
--


--
-- TABLE to hold default average dwelling per building values 
-- provided by Helen
--
DROP TABLE IF EXISTS paul.ave_dwelling_build_PAGER;
CREATE TABLE paul.ave_dwelling_build_PAGER (
 	building_type VARCHAR NOT NULL PRIMARY KEY, 
 	urban INTEGER NOT NULL, 
 	rural INTEGER NOT NULL
);

--
-- COPY CSV data provided by Helen into table
--
COPY paul.ave_dwelling_build_PAGER FROM 
   '/data/ged/ged2/ave_dwelling_build_PAGER.csv' 
   WITH (FORMAT CSV, HEADER );

--
-- Create temporary table with urban values for all dwelling 
-- fractions using PAGER 
--
DROP TABLE IF EXISTS paul.default_urban;
SELECT 
  dv.id AS dv_id, dv.building_type, def.urban AS urban
  INTO paul.default_urban
  FROM ged2.distribution_value AS dv 
  JOIN ged2.distribution_group AS dg 
    ON dv.distribution_group_id=dg.id 
  JOIN paul.ave_dwelling_build_PAGER AS def 
    ON dv.building_type=def.building_type 
  JOIN ged2.study_region AS sr 
    ON dg.study_region_id=sr.id 
 WHERE dv.avg_dwelling_per_build IS NULL 
   AND dg.is_urban AND dg.occupancy_id=0 
   AND sr.taxonomy_name LIKE 'PAGER%' 
;

--
-- Create temporary table with rural values for all dwelling 
-- fractions using PAGER 
--
DROP TABLE IF EXISTS paul.default_rural;
SELECT 
  dv.id AS dv_id, dv.building_type, def.rural AS rural 
  INTO paul.default_rural
  FROM ged2.distribution_value AS dv 
 JOIN ged2.distribution_group AS dg 
    ON dv.distribution_group_id=dg.id 
  JOIN paul.ave_dwelling_build_PAGER AS def 
    ON dv.building_type=def.building_type 
  JOIN ged2.study_region AS sr 
    ON dg.study_region_id=sr.id 
 WHERE dv.avg_dwelling_per_build IS NULL 
   AND (NOT dg.is_urban) AND dg.occupancy_id=0 
   AND sr.taxonomy_name LIKE 'PAGER%' 
;


--
-- UPDATE all urban dwelling fractions 
--
UPDATE ged2.distribution_value AS dv 
   SET avg_dwelling_per_build=tr.urban
  FROM paul.default_urban AS tr
 WHERE tr.dv_id=dv.id AND dv.avg_dwelling_per_build IS NULL;

--
-- UPDATE all rural dwelling fractions 
--
UPDATE ged2.distribution_value AS dv 
   SET avg_dwelling_per_build=tr.rural
  FROM paul.default_rural AS tr
 WHERE tr.dv_id=dv.id AND dv.avg_dwelling_per_build IS NULL;

UPDATE ged2.distribution_group 
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-07-07'
 WHERE id IN (
	SELECT DISTINCT(dg.id) 
	  FROM ged2.distribution_group dg 
	  JOIN ged2.distribution_value dv 
	    ON dv.distribution_group_id=dg.id 
	 WHERE dv.avg_dwelling_per_build IS NOT NULL 
	   AND dg.avg_dwelling_per_build_source IS NULL
 );
---
--- Set source and date
---
--UPDATE ged2.distribution_group 
--   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-07-07'
-- WHERE id IN 
-- (
-- SELECT DISTINCT(distribution_group_id) 
--   FROM ged2.distribution_value 
--  WHERE avg_dwelling_per_build IS NOT NULL 
--    AND distribution_group_id <> 972 -- avoid Z's test study...
--   )
