--
-- Set ged2.distribution_value.avg_dwelling_per_build if not already set
-- based on building type - for GEM taxonomy (L1) only
--

-- If material type is earth (E99, EU, or ER), avg_dwelling_per_build = 1
WITH updated AS (
	UPDATE ged2.distribution_value 
	   SET avg_dwelling_per_build = 1 
	 WHERE avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND ( 
			building_type SIMILAR TO '%/E99(@+|/)%' ESCAPE '@'
		    OR 	building_type SIMILAR TO '%/EU(@+|/)%' ESCAPE '@'
		    OR 	building_type SIMILAR TO '%/ER(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
 )
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is concrete (C99, CR or SRC), and number of storeys 
-- unknown (H99), and urban, avg_dwelling_per_build = 3
-- NOTE all heights appear to be unknown at present
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 3
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/C99(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/CR(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/SRC(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

-- 
-- If material type is concrete (C99, CR or SRC), and number of storeys 
-- unknown (H99), and rural, avg_dwelling_per_build = 1
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 1
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND NOT dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/C99(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/CR(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/SRC(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
--  If material type is unreinforced concrete (CU), avg_dwelling_per_build = 1
--
WITH updated AS (
	UPDATE ged2.distribution_value 
	   SET avg_dwelling_per_build = 1 
	 WHERE avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND ( 
			building_type SIMILAR TO '%/CU(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is masonry (M99, MUR, MCF), and number of storeys unknown 
-- (H99), and urban, avg_dwelling_per_build = 3
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 3
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/M99(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/MUR(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/MCF(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is masonry (M99, MUR, MCF), and number of storeys 
-- unknown (H99), and rural, avg_dwelling_per_build = 1
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 1
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND NOT dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/M99(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/MUR(@+|/)%' ESCAPE '@'
		    OR  building_type SIMILAR TO '%/MCF(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is reinforced masonry (MR), and number of storeys 
-- unknown (H99), and urban, avg_dwelling_per_build = 3
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 3
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/MR(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is reinforced masonry (MR), and number of storeys 
-- unknown (H99), and rural, avg_dwelling_per_build = 1
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 1
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND NOT dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/MR(@+|/)%' ESCAPE '@'
		)
	RETURNING dv.distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

-- If material type is wood (W), avg_dwelling_per_build = 1
WITH updated AS (
	UPDATE ged2.distribution_value 
	   SET avg_dwelling_per_build = 1 
	 WHERE avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND ( 
			building_type SIMILAR TO '%/W(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;


--
-- If material type is steel (S), and number of storeys unknown (H99), 
-- and urban, avg_dwelling_per_build = 3
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 3
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/S(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- If material type is steel (S), and number of storeys unknown (H99), 
-- and rural, avg_dwelling_per_build = 1
--
WITH updated AS (
	UPDATE ged2.distribution_value AS dv
	   SET avg_dwelling_per_build = 1
	  FROM ged2.distribution_group AS dg
	 WHERE dg.id=dv.distribution_group_id
	   AND avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND NOT dg.is_urban
	   AND  (
			building_type SIMILAR TO '%/S(@+|/)%' ESCAPE '@'
		)
        RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;


-- If material type is metal (ME), avg_dwelling_per_build = 1
WITH updated AS (
	UPDATE ged2.distribution_value 
	   SET avg_dwelling_per_build = 1 
	 WHERE avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND ( 
			building_type SIMILAR TO '%/ME(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

--
-- avg_dwelling_per_build = 1 for MAT99 (Unknown material) and 
-- MATO (Other Material)
--
WITH updated AS (
	UPDATE ged2.distribution_value 
	   SET avg_dwelling_per_build = 1 
	 WHERE avg_dwelling_per_build IS NULL  
	   AND dwelling_fraction IS NOT NULL
	   AND ( 
			building_type SIMILAR TO '%/MAT99(@+|/)%' ESCAPE '@'
		OR	building_type SIMILAR TO '%/MATO(@+|/)%' ESCAPE '@'
		)
	RETURNING distribution_group_id
)
UPDATE ged2.distribution_group
   SET avg_dwelling_per_build_source='Helen Crowley, GEM', avg_dwelling_per_build_date='2013-08-29'
 WHERE id IN (SELECT DISTINCT(distribution_group_id) FROM updated)
;

