INSERT INTO ged2.study(
            name, date_created)
    VALUES ('Turkey, L1, NERA', '2013-10-08');

INSERT INTO ged2.ged_user(
            first_name, last_name, organization, date_created)
    VALUES ('Sevgi', 'Ozcebe', 'GEM', '2013-11-01');


###
CLEANUP...

CREATE TEMP VIEW nera_sr AS SELECT study_region.id AS sr_id, geographic_region_gadm.g1name AS g1name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = 448 AND geographic_region_gadm.g0name LIKE 'Turkey' AND geographic_region_gadm.g1name IS NOT NULL AND geographic_region_gadm.g2name IS NULL;

DELETE FROM ged2.distribution_value WHERE distribution_group_id IN (SELECT distribution_group.id AS dg_id FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id ORDER BY dg_id)
