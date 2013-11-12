DROP FUNCTION IF EXISTS ged2.get_building_area(	
	 ged2.bcount_t, 
	 double precision, 
	 ged2.study_region_facts, 
	 ged2.distribution_value);

DROP FUNCTION IF EXISTS ged2.get_building_count(
	 double precision, 
	 double precision, 
	 double precision, 
	 ged2.study_region_facts, 
	 ged2.distribution_value);
	 
DROP FUNCTION IF EXISTS ged2.get_count_area_cost(
	integer, double precision, double precision, boolean, 
	double precision, double precision, double precision, 
	ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);

DROP FUNCTION IF EXISTS ged2.make_exposure_pgsql_retrec(
	integer, double precision, double precision, boolean, 
	double precision, double precision, double precision, 
	ged2.pop_allocation, ged2.study_region_facts, ged2.distribution_value);

DROP FUNCTION IF EXISTS ged2.build_study_region_retrec(numeric);
DROP FUNCTION IF EXISTS ged2.build_study_region_retrec(INTEGER, INTEGER);


--DROP TYPE IF EXISTS ged2.barea_t;
--DROP TYPE IF EXISTS ged2.bcount_t;
--DROP TYPE IF EXISTS ged2.exposure_t;