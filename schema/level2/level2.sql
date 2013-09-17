--
-- The GED Level 2 schema is intentionally very similar to that of 
-- the OpenQuake DB exposure_model and related tables.
--
-- See 
-- https://github.com/gem/oq-engine/blob/master/openquake/engine/db/schema/openquake.sql
--

--
-- Exposure model
-- A collection of assets each of which has zero or more costs 
-- Each type of cost referenced by assets must be described in
-- model_cost_type
--
CREATE TABLE level2.exposure_model (
    id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    description VARCHAR,
    -- the taxonomy system used to classify the assets
    taxonomy_source VARCHAR,
    -- e.g. "buildings", "bridges" etc.
    category VARCHAR NOT NULL,

    -- area type
    area_type VARCHAR CONSTRAINT area_type_value
        CHECK(area_type IS NULL OR area_type = 'per_asset'
              OR area_type = 'aggregated'),

    -- area unit 
    area_unit VARCHAR
) TABLESPACE level2_ts;


--
-- Cost types present in a given model: replacement, contents, ecc.
-- Is called cost_type in OQ DB
--
CREATE TABLE level2.model_cost_type (
    id SERIAL PRIMARY KEY,
    exposure_model_id INTEGER NOT NULL REFERENCES level2.exposure_model(id),
    cost_type_name VARCHAR NOT NULL,

    -- Called conversion in OQ DB
    aggregation_type VARCHAR NOT NULL CONSTRAINT aggregation_type_value
        CHECK(aggregation_type = 'per_asset'
              OR aggregation_type = 'per_area'
              OR aggregation_type = 'aggregated'),
    unit VARCHAR
) TABLESPACE level2_ts;


--
-- Per-asset exposure data
-- In OQ DB is called exposure_data 
--
CREATE TABLE level2.asset (
    id SERIAL PRIMARY KEY,
    exposure_model_id INTEGER NOT NULL,
    -- the asset reference is unique within an exposure model.
    asset_ref VARCHAR NOT NULL,

    -- Building typology using taxonomy_source described in model
    taxonomy VARCHAR NOT NULL,

    -- number of assets, people etc.
    number_of_units float CONSTRAINT units_value CHECK(number_of_units >= 0.0),
    area float CONSTRAINT area_value CHECK(area >= 0.0),

    -- Corrsponds to site GEOGRAPHY in OQ DB
    -- in GED level 2 must be a reference to a grid point
    grid_point_id	INTEGER NOT NULL REFERENCES ged2.grid_point(id), 

    UNIQUE (exposure_model_id, asset_ref)
) TABLESPACE level2_ts;


--
-- Each asset has 0 or more costs (replacement, contents, ecc.)
--
CREATE TABLE level2.cost (
    id SERIAL PRIMARY KEY,
    asset_id INTEGER NOT NULL REFERENCES level2.asset(id),
    cost_type_id INTEGER NOT NULL REFERENCES level2.model_cost_type(id),
    -- Called converted_cost in OQ DB
    value float NOT NULL CONSTRAINT converted_cost_value
         CHECK(value >= 0.0),
    UNIQUE (asset_id, cost_type_id)
) TABLESPACE level2_ts;


--
-- Occupants of the buildings described in assets
--
CREATE TABLE level2.occupancy (
    id SERIAL PRIMARY KEY,
    asset_id INTEGER NOT NULL REFERENCES level2.asset(id),
    period VARCHAR NOT NULL, -- e.g. day,night ecc.
    occupants float NOT NULL -- number of people present 
) TABLESPACE level2_ts;

--
-- Additional meta-data for model - source, date, notes
--
CREATE TABLE level2.contribution (
	id SERIAL PRIMARY KEY,
	exposure_model_id INTEGER NOT NULL REFERENCES level2.exposure_model(id),
	model_source	  VARCHAR NOT NULL,
	model_date	  VARCHAR NOT NULL,
	notes	TEXT
) TABLESPACE level2_ts;
