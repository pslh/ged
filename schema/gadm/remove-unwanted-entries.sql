--
-- Remove all water bodies and especially the Caspian Sea
--
DELETE FROM ged2.gadm2 
 WHERE ENGTYPE_1 = 'Water body' 
    OR ENGTYPE_1 = 'Lake'  

    OR ENGTYPE_2 = 'Water body' 
    OR ENGTYPE_2 = 'Water Body' 
    OR ENGTYPE_2 = 'Waterbody'
    OR ENGTYPE_2 = 'Lake' 

    OR ENGTYPE_3 = 'Lake' 
    OR ENGTYPE_3 = 'Water body' 
    OR ENGTYPE_3 = 'Water Body' 
    OR ENGTYPE_3 = 'Waterbody' 

    OR ENGTYPE_4 = 'Water body' 
    OR ENGTYPE_4 = 'Water Body' 

    OR ENGTYPE_5 = 'Water body' 

    OR iso='CA-';
