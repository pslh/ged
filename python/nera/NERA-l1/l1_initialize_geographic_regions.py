#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
import sys, os, psycopg2, psycopg2.extensions 
import psycopg2.extensions 
import shutil
import unittest
import datetime
import math

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

sys.path.append('libs/errorhandler')
sys.path.append('libs/xlrd')
sys.path.append('libs/xlutils')
sys.path.append('libs/xlwt')
from xlrd import open_workbook

# see http://bit.ly/1daJ8iq #or execfile('config.py')
from variables import *
from myfuncs import *


# open db connection info
if os.path.exists(local_param_file):
    param_file = open(local_param_file, "r")
    dbaddr = param_file.readline().rstrip('\n')
    port = param_file.readline().rstrip('\n')
    usr = param_file.readline().rstrip('\n')
    passwd = param_file.readline().rstrip('\n')
    dbname = param_file.readline().rstrip('\n')
    con_string = "dbname=" + dbname + " user=" + usr + " password=" + passwd + " host=" + \
        dbaddr + " port=" + port
    print "Connecting to db %s@%s:%s as %s..." % (dbname, dbaddr, port, usr)
else:
    print "ERROR: file with DB Connection Parameters not found!"
    print "Please check if './.db_con_param.dat' is present..."  
    exit(1)

connection = psycopg2.connect(con_string)
mark = connection.cursor()
mark2 = connection.cursor()
print "Connected to db!\n"

utc_datetime = datetime.datetime.utcnow()
datenow = utc_datetime.strftime("%Y-%m-%d %H:%M:%S")

try:

    xls_filename = raw_input("Enter the Excel filename [GED4GEM_NERA-Turkey-Level0-1.xls]: ")
    if xls_filename == "":
        xls_filename = "GED4GEM_NERA-Turkey-Level0-1.xls"
    if os.path.exists(xls_filename):
        my_workbook = open_workbook(xls_filename)
    else:
        print "ERROR: file '%s' not found!" % xls_filename
        exit(2)

    sheets = my_workbook.sheet_names()

    # print len(sheets)
    cur_sheet = 4; 

    my_sheet = my_workbook.sheet_by_name(sheets[cur_sheet])
    s = my_sheet
    cur_indent = int(math.floor((cur_sheet-2) / 2))


    ###########
    print "\nGoing to insert missing regions into 'geographic_region' table..."
    ###########

    q = """SELECT region_id AS gr_id, g1name FROM ged2.geographic_region_gadm WHERE g1name IS NOT NULL AND g2name IS NULL AND g0name LIKE '%s';""" % (l1_country)
    mark.execute(q)
    progress = 1

    for y in range(1, s.nrows):
        found = 0
        l1_g1 = (s.cell(y,cur_indent).value)

        if (l1_g1):
            if mark.rowcount > 0:
                mark.scroll(0, mode='absolute')
                for x in mark:
                    ged_gr_id = x[0]
                    ged_g1 = x[1]
                    if (ged_g1 == l1_g1):
                        found = 1
                                        
            if (not found):
                q = """SELECT g1.id FROM ged2.gadm_admin_1 AS g1 WHERE g1.name LIKE %s AND g1.gadm_country_id = %s;""" % (sql_quote(l1_g1), l1_country_id)
                mark2.execute(q)  # quoting needed for names like "O'Brien"
                g1id = mark2.fetchone()
                if g1id is not None:
                    mark2.execute("""INSERT INTO ged2.geographic_region (gadm_admin_1_id) VALUES ('%s')""" % (g1id[0]))
                    print "Creating geographic_region for %s" % (l1_g1)
                else:
                    print "Country %s not a valid GADM name" % (l1_g1)

    #######################################################################

    ###########
    print "\nGoing to create study regions into 'study_region' table..."
    ###########

    query = """SELECT study_region.id AS sr_id, geographic_region_gadm.g1name AS g1name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = %s AND g0name LIKE '%s' AND g1name IS NOT NULL AND g2name IS NULL;""" % (l1_study_id, l1_country)
    mark.execute(query)
    progress = 1

    for y in range(1, s.nrows):
        found = 0
        l1_g1 = (s.cell(y,cur_indent).value)

        if (l1_g1):
            if mark.rowcount > 0:
                mark.scroll(0, mode='absolute')
                for x in mark:
                    ged_gr_id = x[0]
                    ged_g1 = x[1]
                    if (ged_g1 == l1_g1):
                        found = 1
            
            if (not found):
                q = """SELECT gr.region_id AS gr_id FROM ged2.geographic_region_gadm AS gr WHERE gr.g0name LIKE '%s' AND gr.g1name LIKE %s AND gr.g2name IS NULL;""" % (l1_country, sql_quote(l1_g1))
                mark2.execute(q)
                ret = mark2.fetchone()
                if ret is not None:
                    gr_id = ret[0]
                    qqq = """INSERT INTO ged2.study_region (study_id, geographic_region_id, taxonomy_name, taxonomy_version, taxonomy_date) VALUES (%s, %s, '%s', '%s', '%s')""" % (l1_study_id, gr_id, l1_tax_name, l1_tax_version, l1_tax_date)
                    mark2.execute(qqq)
                    print "Creating study_region for %s" % (l1_g1)
                else:
                    print "Country %s not a valid GADM name" % (l1_g1)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    #######################################################################

    ###########
    print "\nGoing to create stub distribution groups into 'distribution_group' table..."
    ###########


    query = """CREATE TEMP VIEW nera_sr AS SELECT study_region.id AS sr_id, geographic_region_gadm.g1name AS g1name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = %s AND geographic_region_gadm.g0name LIKE '%s' AND geographic_region_gadm.g1name IS NOT NULL AND geographic_region_gadm.g2name IS NULL;""" % (l1_study_id, l1_country)
    mark.execute(query)

    query = """SELECT distribution_group.id AS dg_id, g1name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = true"""
    mark.execute(query)

    progress = 1
    for y in range(1, s.nrows):
        found = 0
        l1_g1 = (s.cell(y,cur_indent).value)

        if (l1_g1):

            if mark.rowcount > 0:
                mark.scroll(0,mode='absolute')
                for x in mark:
                    ged_gr_id = x[0]
                    ged_g1 = x[1]
                    if (ged_g1 == l1_g1):
                        found = 1
                                        
            if (not found):
                q = """SELECT sr_id FROM nera_sr WHERE g1name LIKE %s;""" % (sql_quote(l1_g1))
                mark2.execute(q)
                ret = mark2.fetchone()
                if ret is not None:
                    sr_id = ret[0]
                    qqq = """INSERT INTO ged2.distribution_group (study_region_id, is_urban, occupancy_id, compiled_by, building_fraction_source, building_fraction_date, replace_cost_per_area_source, replace_cost_per_area_date, replace_cost_per_area_currency, avg_dwelling_per_build_source, avg_dwelling_per_build_date, avg_floor_area_source, avg_floor_area_date, area_unit_id) VALUES (%s, %s, %s, %s, '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %s)""" % (sr_id, 'true', l1_occupancy, l1_compiled_by, l1_building_fraction_source, l1_building_fraction_date, l1_replace_cost_per_area_source, l1_replace_cost_per_area_date, l1_replace_cost_per_area_currency, l1_avg_dwelling_per_build_source, l1_avg_dwelling_per_build_date, l1_avg_floor_area_source, l1_avg_floor_area_date, l1_area_unit_id)
                    mark2.execute(qqq)
                    print "Creating urban distribution_group for %s" % (l1_g1)
                else:
                    print "Country %s not a valid GADM name" % (l1_g1)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    query = """SELECT distribution_group.id AS dg_id, g1name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = false"""
    mark.execute(query)

    progress = 1
    for y in range(1, s.nrows):
        found = 0
        l1_g1 = (s.cell(y,cur_indent).value)

        if (l1_g1):

            if mark.rowcount > 0:
                mark.scroll(0,mode='absolute')
                for x in mark:
                    ged_gr_id = x[0]
                    ged_g1 = x[1]
                    if (ged_g1 == l1_g1):
                        found = 1
                                        
            if (not found):
                q = """SELECT sr_id FROM nera_sr WHERE g1name LIKE %s;""" % (sql_quote(l1_g1))
                mark2.execute(q)
                ret = mark2.fetchone()
                if ret is not None:
                    sr_id = ret[0]
                    qqq = """INSERT INTO ged2.distribution_group (study_region_id, is_urban, occupancy_id, compiled_by, building_fraction_source, building_fraction_date, replace_cost_per_area_source, replace_cost_per_area_date, replace_cost_per_area_currency, avg_dwelling_per_build_source, avg_dwelling_per_build_date, avg_floor_area_source, avg_floor_area_date, area_unit_id) VALUES (%s, %s, %s, %s, '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %s)""" % (sr_id, 'false', l1_occupancy, l1_compiled_by, l1_building_fraction_source, l1_building_fraction_date, l1_replace_cost_per_area_source, l1_replace_cost_per_area_date, l1_replace_cost_per_area_currency, l1_avg_dwelling_per_build_source, l1_avg_dwelling_per_build_date, l1_avg_floor_area_source, l1_avg_floor_area_date, l1_area_unit_id)
                    mark2.execute(qqq)
                    print "Creating rural distribution_group for %s" % (l1_g1)
                else:
                    print "Country %s not a valid GADM name" % (l1_g1)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ###################################################

    ######SELECT distribution_group.id AS dg_id, g0name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id

    query = """SELECT distribution_group.id AS dg_id, g1name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id;"""
    mark.execute(query)

    progress = 1
    if mark.rowcount < 1:
        print "Doh..."
        exit(0)
    
    for x in mark:
        dg_id = x[0]
        l1_g1 = x[1]
        q = """SELECT id FROM ged2.study_region_facts WHERE distribution_group_id = %s;""" % (dg_id)
        mark2.execute(q)
        if mark2.rowcount < 1:
            q = """INSERT INTO ged2.study_region_facts (distribution_group_id, tot_num_dwellings_source, tot_num_dwellings_date) VALUES (%s, '%s', '%s')""" % (dg_id, l1_tot_num_dwellings_source, l1_tot_num_dwellings_date)
            mark2.execute(q)
            print "Creating stub facts entry in study_region_facts for %s" % (l1_g1)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/mark.rowcount)),   
        sys.stdout.flush()

    # data = []
    # data.append()
    # data = list(set(data)) #get unique value
    # len(data)


    print "\nClosing connection and exiting..."
    mark.close()
    connection.commit()
    connection.close()
    exit(0)


except Exception, err:
    sys.stderr.write('ERROR: %s\n' % str(err))
    connection.close()
    exit(1)
