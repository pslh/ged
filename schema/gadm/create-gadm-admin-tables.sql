--
-- Create ged2.gadm_* tables from ged2.gadm2
--

--
-- Remove existing tables
--
DROP TABLE IF EXISTS ged2.gadm_admin_3;
DROP TABLE IF EXISTS ged2.gadm_admin_2;
DROP TABLE IF EXISTS ged2.gadm_admin_1;
DROP TABLE IF EXISTS ged2.gadm_country;

--
-- Create ged2.gadm_country table from distinct nations in gadm2
-- Add primary key and set tablespace
--
SELECT DISTINCT ON (iso, id_0) id_0 AS id, iso, name_0 AS name INTO ged2.gadm_country FROM ged2.gadm2 ORDER BY id_0;
ALTER TABLE ged2.gadm_country ADD PRIMARY KEY (id);
ALTER TABLE ged2.gadm_country set tablespace ged2_ts;

--
-- Create gadm_admin_1 from distinct regions in gadm2
--
CREATE TABLE ged2.gadm_admin_1 
TABLESPACE ged2_ts
AS 
SELECT DISTINCT ON (gg.id_0,gg.id_1) 
	gg.objectid AS id,
	gg.name_1 AS name, 
	gg.varname_1 AS varname, 
	gg.nl_name_1 AS nl_name, 
	pg.type_1 AS type, 
	gg.engtype_1 AS engtype, 
	gg.id_1 AS gadm_id_1, 
	gg.id_0 AS gadm_country_id 
 FROM ged2.gadm2 gg 
 JOIN paul.gadm2 pg ON pg.objectid=gg.objectid 
WHERE gg.id_1 IS NOT NULL
ORDER BY gg.id_0,gg.id_1;

ALTER TABLE ged2.gadm_admin_1 ADD PRIMARY KEY (id);
ALTER TABLE ged2.gadm_admin_1 ADD CONSTRAINT gadm_country_id_fk FOREIGN KEY (gadm_country_id) REFERENCES ged2.gadm_country(id);
ALTER TABLE ged2.gadm_admin_1 ALTER COLUMN gadm_country_id SET NOT NULL;
ALTER TABLE ged2.gadm_admin_1 ALTER COLUMN name SET NOT NULL;

--
-- Create gadm_admin_2 in same way
--
CREATE TABLE ged2.gadm_admin_2 
TABLESPACE ged2_ts
AS 
SELECT DISTINCT ON (gg.id_0,gg.id_1,gg.id_2) 
	gg.objectid AS id,
	gg.name_2 AS name, 
	gg.varname_2 AS varname, 
	gg.nl_name_2 AS nl_name, 
	pg.type_2 AS type, 
	gg.engtype_2 AS engtype, 
	gg.id_1 AS gadm_id_1, 
	gg.id_2 AS gadm_id_2, 
	gg.id_0 AS gadm_country_id,
	g1.id AS gadm_admin_1_id
 FROM ged2.gadm2 gg 
 JOIN paul.gadm2 pg ON pg.objectid=gg.objectid 
 JOIN ged2.gadm_admin_1 g1 ON gg.id_1=g1.gadm_id_1 AND gg.id_0=g1.gadm_country_id
WHERE gg.id_2 IS NOT NULL
ORDER BY gg.id_0,gg.id_1,gg.id_2;

ALTER TABLE ged2.gadm_admin_2 ADD PRIMARY KEY (id);
ALTER TABLE ged2.gadm_admin_2 ADD CONSTRAINT gadm_country_id_fk FOREIGN KEY (gadm_country_id) REFERENCES ged2.gadm_country(id);
ALTER TABLE ged2.gadm_admin_2 ADD CONSTRAINT gadm_admin_1_id_fk FOREIGN KEY (gadm_admin_1_id) REFERENCES ged2.gadm_admin_1(id);
ALTER TABLE ged2.gadm_admin_2 ALTER COLUMN gadm_admin_1_id SET NOT NULL;
ALTER TABLE ged2.gadm_admin_2 ALTER COLUMN gadm_country_id SET NOT NULL;
ALTER TABLE ged2.gadm_admin_2 ALTER COLUMN gadm_id_1 SET NOT NULL;
ALTER TABLE ged2.gadm_admin_2 ALTER COLUMN gadm_id_2 SET NOT NULL;
ALTER TABLE ged2.gadm_admin_2 ALTER COLUMN name SET NOT NULL;

--
-- Create gadm_admin_3 in same way
--
CREATE TABLE ged2.gadm_admin_3 
TABLESPACE ged2_ts
AS 
SELECT DISTINCT ON (gg.id_0,gg.id_1,gg.id_2,gg.id_3) 
	gg.objectid AS id,
	gg.name_3 AS name, 
	gg.varname_3 AS varname, 
	gg.nl_name_3 AS nl_name, 
	pg.type_3 AS type, 
	gg.engtype_3 AS engtype, 
	gg.id_1 AS gadm_id_1, 
	gg.id_2 AS gadm_id_2, 
	gg.id_3 AS gadm_id_3, 
	gg.id_0 AS gadm_country_id,
	g2.id AS gadm_admin_2_id
 FROM ged2.gadm2 gg 
 JOIN paul.gadm2 pg ON pg.objectid=gg.objectid 
 JOIN ged2.gadm_admin_2 g2 ON gg.id_1=g2.gadm_id_1 AND gg.id_2=g2.gadm_id_2 AND gg.id_0=g2.gadm_country_id
WHERE gg.id_3 IS NOT NULL
ORDER BY gg.id_0,gg.id_1,gg.id_2;

ALTER TABLE ged2.gadm_admin_3 ADD PRIMARY KEY (id);
ALTER TABLE ged2.gadm_admin_3 ADD CONSTRAINT gadm_country_id_fk FOREIGN KEY (gadm_country_id) REFERENCES ged2.gadm_country(id);
ALTER TABLE ged2.gadm_admin_3 ADD CONSTRAINT gadm_admin_2_id_fk FOREIGN KEY (gadm_admin_2_id) REFERENCES ged2.gadm_admin_2(id);
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN gadm_admin_2_id SET NOT NULL;
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN gadm_country_id SET NOT NULL;
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN gadm_id_1 SET NOT NULL;
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN gadm_id_2 SET NOT NULL;
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN gadm_id_3 SET NOT NULL;
ALTER TABLE ged2.gadm_admin_3 ALTER COLUMN name SET NOT NULL;
