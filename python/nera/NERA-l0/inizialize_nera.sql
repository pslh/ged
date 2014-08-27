INSERT INTO ged2.study(
            name, date_created, notes)
    VALUES ('NERA Unified', current_timestamp, 'Combined or unified NERA/IMPRO study - update name and notes');

--INSERT INTO ged2.ged_user(
--          first_name, last_name, organization, date_created)
-- VALUES ('NERA', 'NERA', 'Nera Project', '2013-01-01');



# CLEANUP WITH
CREATE NERA VIEW
then...
DELETE FROM ged2.distribution_value WHERE distribution_group_id IN (SELECT dg_id FROM nera)
