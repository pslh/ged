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
    costs_sheet = my_workbook.sheet_by_name(sheets[1])
    # print len(sheets)

    query = """CREATE TEMP VIEW nera_sr AS SELECT study_region.id AS sr_id, geographic_region_gadm.g1name AS g1name FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id WHERE study_region.study_id = %s AND geographic_region_gadm.g0name LIKE '%s' AND geographic_region_gadm.g1name IS NOT NULL AND geographic_region_gadm.g2name IS NULL;""" % (l1_study_id, l1_country)
    mark.execute(query)

    #print get_replace_cost(costs_sheet, """DX+D99/S+S99+SC99/LFM+DU99/DY+D99/S+S99+SC99/LFM+DU99/HBET:1,3+HF99/YBET:1980,2000/OC99/BP99/PLF99/IR99/EW99/RSH99+RMT99+R99+RWC99/F99+FWC99/FOS100""")

    #######################################################################

    ###########
    print "\nGoing to update 'study_region_facts' table..."
    ###########

    for is_urban in [True, False]:
    #is_urban = False; #remeber to change cur sheet num

        if is_urban:
            cur_sheet = 4
        else:
            cur_sheet = 5

        s = my_workbook.sheet_by_name(sheets[cur_sheet])
        cur_indent = int(math.floor((cur_sheet-2) / 2))

        query = """SELECT distribution_group.id AS dg_id, g1name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = %s ORDER BY dg_id""" % (is_urban)
        mark.execute(query) ## dg_id di interesse

        progress = 1
        for y in range(1, s.nrows):
            found = 0
            l1_g1 = (s.cell(y,cur_indent).value)
            if (l1_g1):
                if mark.rowcount > 0:
                    mark.scroll(0, mode='absolute')
                    for x in mark:
                        dg_id = x[0]
                        if (l1_g1 == x[1]):
                            found = 1
                            break
                                            
                if (not found):
                    print "ERROR: missing 'distribution group' for: %s" % (l1_g1)
                else:
                    print "Updating facts for %s" % (l1_g1)
                    tot_num_dwellings = (int)(round(s.cell(y,cur_indent + 1).value))
                    tot_num_buildings = (int)(round(s.cell(y,cur_indent + 2).value))
                    avg_dwelling_area = (float)(s.cell(y,cur_indent + 6).value)
                    q = """UPDATE ged2.study_region_facts SET (tot_num_dwellings, tot_num_buildings, avg_dwelling_area) = (%s, %s, %s) WHERE distribution_group_id = %s;""" % (tot_num_dwellings, tot_num_buildings, avg_dwelling_area, dg_id)
###
#                    mark2.execute(q)
###
            progress = progress + 1
            print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
            sys.stdout.flush()

    #################################
    ###########
    print "\nGoing to insert/update 'distribution_values' table..."
    ###########

    for is_urban in [True, False]:
    #is_urban = False; #remeber to change cur sheet num

        if is_urban:
            cur_sheet = 4
        else:
            cur_sheet = 5

        s = my_workbook.sheet_by_name(sheets[cur_sheet])
        cur_indent = int(math.floor((cur_sheet-2) / 2))

        query = """SELECT distribution_group.id AS dg_id, g1name FROM ged2.distribution_group JOIN nera_sr ON study_region_id = sr_id WHERE is_urban = %s ORDER BY dg_id""" % (is_urban)
        mark.execute(query) ## dg_id di interesse

        progress = 1
        for y in range(1, s.nrows):
            found = 0
            l1_g1 = (s.cell(y,cur_indent).value)
            if (l1_g1):
                if mark.rowcount > 0:
                    mark.scroll(0, mode='absolute')
                    for x in mark:
                        dg_id = x[0]
                        if (l1_g1 == x[1]):
                            found = 1
                            break
                                            
                if (not found):
                    print "ERROR: missing 'distribution group' for: %s" % (l1_g1)
                else:
                    print "Updating distribution values for %s" % (l1_g1)
                    for k in range(cur_indent + 8, s.ncols):
                        bt = str(s.cell(0,k).value)
                        bf = (float)(s.cell(y,k).value)
                        if (bt is not None and bf > 0):
                            rc = get_replace_cost(costs_sheet, bt)
                            if rc is None:
                                rc = 0;
                            #print dg_id, bt[:10], bf, get_replace_cost(costs_sheet, bt)

                            querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, bt)
                            mark2.execute(querydv)
                            if mark2.rowcount < 1:
                                q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, building_fraction, replace_cost_per_area) VALUES (%s, '%s', %s, %s);""" % (dg_id, bt, bf, rc)
                            else:
                                    q = """UPDATE ged2.distribution_value SET (building_fraction, replace_cost_per_area) = (%s, %s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (bf, rc, dg_id, bt)
###
                            mark2.execute(q)
###


            progress = progress + 1
            print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
            sys.stdout.flush()

    ##########
    print "\nClosing connection and exiting..."
    mark.close()
    connection.commit()
    connection.close()
    exit(0)
    ##########


except Exception, err:
    sys.stderr.write('ERROR: %s\n' % str(err))
    connection.close()
    exit(1)
