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

    xls_filename = raw_input("Enter the Excel filename [default]: ")
    if xls_filename == "":
        xls_filename = "Level_0_Europe_NERA.xls"
    if os.path.exists(xls_filename):
        my_workbook = open_workbook(xls_filename)
    else:
        print "ERROR: file '%s' not found!" % xls_filename
        exit(2)

    sheets = my_workbook.sheet_names()

    query = """CREATE TEMP VIEW nera AS SELECT geographic_region_gadm.g0name AS g0name, study_region.id AS sr_id, distribution_group.id AS dg_id FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id JOIN ged2.distribution_group ON distribution_group.study_region_id = study_region.id WHERE study_region.study_id = %s""" % (nera_study_id)
    mark.execute(query)
    # nera: g0name / sr_id / dg_id / srf_id

    ###########
    print "\nGoing to insert building_fractions into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[5])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                dg_id = -1
                for c in range(3, s.ncols):
                    building_type = s.cell(0,c).value
                    building_fraction = s.cell(y,c).value

                    if (g0 and building_type and building_fraction):
                        #print g0, building_type, building_fraction
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, building_fraction) VALUES (%s, '%s', %s);""" % (dg_id, building_type, building_fraction)
                        else:
                            q = """UPDATE ged2.distribution_value SET (building_fraction) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (building_fraction, dg_id, building_type)
                        mark2.execute(q)

                if int(dg_id) > 0:
                    q = """UPDATE ged2.distribution_group SET (building_fraction_source, building_fraction_date) = ('JRC-IMPRO Building Project', '2013-01-01') WHERE id = %s;""" % (dg_id)
                    mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
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
