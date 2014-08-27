#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
import sys, os, psycopg2, psycopg2.extensions 
import psycopg2.extensions 
import shutil
import unittest
import datetime

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

    xls_filename = raw_input("Enter the Excel filename [fips_census_GADM.xls]: ")
    if xls_filename == "":
        xls_filename = "Level_0_Names.xls"
    if os.path.exists(xls_filename):
        my_workbook = open_workbook(xls_filename)
    else:
        print "ERROR: file '%s' not found!" % xls_filename
        exit(2)

    sheets = my_workbook.sheet_names()
    my_sheet = my_workbook.sheet_by_name(sheets[0])
    s = my_sheet



    ###########
    print "\nGoing to insert missing regions into 'geographic_region' table..."
    ###########
    mark.execute("""SELECT region_id AS gr_id, g0name FROM ged2.geographic_region_gadm WHERE g0name IS NOT NULL AND g1name IS NULL AND g2name IS NULL;""")
    progress = 1

    for y in range(1, s.nrows):
        break
        found = 0
        nera_g0 = (s.cell(y,2).value)

        if (nera_g0):
            mark.scroll(0,mode='absolute')
            for x in mark:
                ged_gr_id = x[0]
                ged_g0 = x[1]
                if (nera_g0 == ged_g0):
                    found = 1
                                        
            if (not found):
                q = """SELECT g0.id FROM ged2.gadm_country AS g0 WHERE g0.name LIKE '%s';""" % (psycopg2.extensions.adapt(nera_g0).getquoted())
                mark2.execute(q)  # quoting needed for names like "O'Brien"
                g0id = mark2.fetchone()
                if g0id is not None:
                    mark2.execute("""INSERT INTO ged2.geographic_region (gadm_country_id) VALUES ('%s')""" % (g0id[0]))
                    print "Creating geographic_region for %s" % (nera_g0)
                else:
                    print "Country %s not a valid GADM name" % (nera_g0)

    #######################################################################

    ###########
    print "\nGoing to create study regions into 'study_region' table..."
    ###########

    query = """SELECT study_region.id AS sr_id, geographic_region_gadm.g0name AS g0name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = %s AND g1name IS NULL AND g2name IS NULL;""" % (nera_study_id)
    mark.execute(query)
    progress = 1

    for y in range(1, s.nrows):
        break
        found = 0
        nera_g0 = (s.cell(y,2).value)

        if (nera_g0):

            if mark.rowcount > 0:
                mark.scroll(0,mode='absolute')
                for x in mark:
                    ged_sr_id = x[0]
                    ged_g0 = x[1]
                    if (nera_g0 == ged_g0):
                        found = 1
                                        
            if (not found):
                q = """SELECT gr.region_id AS gr_id FROM ged2.geographic_region_gadm AS gr WHERE gr.g0name LIKE %s AND gr.g1name IS NULL AND gr.g2name IS NULL;""" % (psycopg2.extensions.adapt(nera_g0).getquoted())
                mark2.execute(q)  # quoting needed for names like "O'Brien"
                ret = mark2.fetchone()
                if ret is not None:
                    gr_id = ret[0]
                    qqq = """INSERT INTO ged2.study_region (study_id, geographic_region_id, taxonomy_name, taxonomy_version, taxonomy_date) VALUES (%s, %s, '%s', '%s', '%s')""" % (nera_study_id, gr_id, nera_tax_name, nera_tax_version, nera_tax_date)
                    mark2.execute(qqq)
                    print "Creating study_region for %s" % (nera_g0)
                else:
                    print "Country %s not a valid GADM name" % (nera_g0)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    #######################################################################

    ###########
    print "\nGoing to create stub distribution groups into 'distribution_group' table..."
    ###########


    query = """CREATE TEMP VIEW nera_sr AS SELECT study_region.id AS sr_id, geographic_region_gadm.g0name AS g0name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = %s AND geographic_region_gadm.g1name IS NULL AND geographic_region_gadm.g2name IS NULL;""" % (nera_study_id)
    mark.execute(query)

    query = """SELECT distribution_group.id AS dg_id, g0name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = true"""
    mark.execute(query)

    progress = 1
    for y in range(1, s.nrows):
        break
        found = 0
        nera_g0 = (s.cell(y,2).value)

        if (nera_g0):

            if mark.rowcount > 0:
                mark.scroll(0,mode='absolute')
                for x in mark:
                    ged_dg_id = x[0]
                    ged_g0 = x[1]
                    if (nera_g0 == ged_g0):
                        found = 1
                                        
            if (not found):
                q = """SELECT sr_id FROM nera_sr WHERE g0name LIKE %s;""" % (psycopg2.extensions.adapt(nera_g0).getquoted())
                mark2.execute(q)  # quoting needed for names like "O'Brien"
                ret = mark2.fetchone()
                if ret is not None:
                    sr_id = ret[0]
                    qqq = """INSERT INTO ged2.distribution_group (study_region_id, is_urban, occupancy_id, compiled_by) VALUES (%s, %s, %s, %s)""" % (sr_id, 'true', nera_occupancy, nera_compiled_by)
                    mark2.execute(qqq)
                    print "Creating urban distribution_group for %s" % (nera_g0)
                else:
                    print "Country %s not a valid GADM name" % (nera_g0)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    query = """SELECT distribution_group.id AS dg_id, g0name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = false"""
    mark.execute(query)

    progress = 1
    for y in range(1, s.nrows):
        break
        found = 0
        nera_g0 = (s.cell(y,2).value)

        if (nera_g0):

            if mark.rowcount > 0:
                mark.scroll(0,mode='absolute')
                for x in mark:
                    ged_dg_id = x[0]
                    ged_g0 = x[1]
                    if (nera_g0 == ged_g0):
                        found = 1
                                        
            if (not found):
                q = """SELECT sr_id FROM nera_sr WHERE g0name LIKE %s;""" % (psycopg2.extensions.adapt(nera_g0).getquoted())
                mark2.execute(q)  # quoting needed for names like "O'Brien"
                ret = mark2.fetchone()
                if ret is not None:
                    sr_id = ret[0]
                    qqq = """INSERT INTO ged2.distribution_group (study_region_id, is_urban, occupancy_id, compiled_by) VALUES (%s, %s, %s, %s)""" % (sr_id, 'false', nera_occupancy, nera_compiled_by)
                    mark2.execute(qqq)
                    print "Creating rural distribution_group for %s" % (nera_g0)
                else:
                    print "Country %s not a valid GADM name" % (nera_g0)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ######SELECT distribution_group.id AS dg_id, g0name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id

    query = """SELECT distribution_group.id AS dg_id, g0name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id;"""
    mark.execute(query)

    progress = 1
    if mark.rowcount < 1:
        print "Doh..."
        exit(0)
    
    for x in mark:
        dg_id = x[0]
        nera_g0 = x[1]
        q = """SELECT id FROM ged2.study_region_facts WHERE distribution_group_id = %s;""" % (dg_id)
        mark2.execute(q)
        if mark2.rowcount < 1:
            q = """INSERT INTO ged2.study_region_facts (distribution_group_id) VALUES (%s)""" % (dg_id)
            mark2.execute(q)
            print "Creating stub facts entry in study_region_facts for %s" % (nera_g0)
  
        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/mark.rowcount)),   
        sys.stdout.flush()

    print "\nClosing connection and exiting..."
    mark.close()
    connection.commit()
    connection.close()
    exit(0)


except Exception, err:
    sys.stderr.write('ERROR: %s\n' % str(err))
    connection.close()
    exit(1)
