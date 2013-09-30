-- ----------------------------------------------------------
-- MDB Tools - A library for reading MS Access database files
-- Copyright (C) 2000-2011 Brian Bruns and others.
-- Files in libmdb are licensed under LGPL and the utilities under
-- the GPL, see COPYING.LIB and COPYING files respectively.
-- Check out http://mdbtools.sourceforge.net
-- ----------------------------------------------------------

SET client_encoding = 'UTF-8';

DROP TABLE IF EXISTS temp.gadm2names ;
CREATE TABLE temp.gadm2names
 (
	OBJECTID			SERIAL PRIMARY KEY NOT NULL, 
	ID_0			INTEGER, 
	ISO			VARCHAR (6), 
	NAME_0			VARCHAR (150), 
	ID_1			INTEGER, 
	NAME_1			VARCHAR (150), 
	VARNAME_1			VARCHAR (300), 
	NL_NAME_1			VARCHAR (100), 
	ID_2			INTEGER, 
	NAME_2			VARCHAR (150), 
	VARNAME_2			VARCHAR (300), 
	NL_NAME_2			VARCHAR (150), 
	ID_3			INTEGER, 
	NAME_3			VARCHAR (150), 
	VARNAME_3			VARCHAR (200), 
	NL_NAME_3			VARCHAR (150), 
	ID_4			INTEGER, 
	NAME_4			VARCHAR (200), 
	VARNAME_4			VARCHAR (200), 
	ID_5			INTEGER, 
	NAME_5			VARCHAR (150)
);

-- CREATE INDEXES ...
-- CREATE INDEX gadm2_FDO_OBJECTID_idx ON gadm2 (OBJECTID);


-- CREATE Relationships ...
