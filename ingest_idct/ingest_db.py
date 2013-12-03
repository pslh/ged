#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (c) 2013, GEM Foundation.
#
# OpenQuake is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenQuake is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with OpenQuake.  If not, see <http://www.gnu.org/licenses/>.
#

#
# Input parameters
#  input file - String path to SQLite 3 DB file
#  source - String description of source of data
#  notes - [Optional] string description

#
# Either need to connect to GED DB or to write out SQL that can be
# exectuted with psql

#
# INSERT INTO level3.project (
#    proj_uid, project_name, project_date, hazard_type...
#  )
#  SELECT
#   '@PROJ_UID@', '@PROJ_NAME@', '@PROJ_DATE@',...
#  WHERE NOT EXISTS (
#    SELECT proj_uid FROM level3.project
#    WHERE proj_uid='@PROJ_UID@'
#  );
#

#
#
# Open DB file
# If object and project tables not present, exit with error
#
# For each project in SQLite DB
#  if project does not exist in GED, create project entry in GED
#
#
#
import sqlite3
import sys
import os.path


class InputError(RuntimeError):
    """Exception raised for errors in the input.

    Attributes:
        msg  -- explanation of the error
    """

    def __init__(self, msg):
        self.msg = msg


def _ensure_idct_db(cursor, input_db):
    """
    Raise an InputError if input_db is not a valid IDCT SQLite file
    """

    cursor.execute("""
            SELECT count(name) AS num_tables
            FROM sqlite_master
            WHERE name IN ('GEM_PROJECT', 'GEM_OBJECT', 'GED', 'MEDIA_DETAIL');
            """)
    row = cursor.fetchone()

    if(row):
        _num_tables = row[0]

    if(_num_tables != 4):
        # ERROR - DB does not contain all required tables.
        raise InputError(
            u"DB schema {0} does not contain the expected tables.\n".format(
            input_db))


def _quote_sql(text):
    """
    If text is None return 'NULL', otherwise return text enclosed in quotes.
    Used to construct query strings from parameters that might be None
    """
    if(text is None):
        return u'NULL'
    else:
        #try:
        return u"'{0}'".format(text)
        #except Exception, e:
            #print "ERROR: " + e
            #print "%%%"
            #print text
            #print "%%%"
        #    return u"!!! BAD TEXT HERE !!! {0}".format(e)
#            sys.stderr.write('Considering non-None text.\n')
#            sys.stderr.write('text={0}\n'.format(text))
#            sys.stderr.write('Problem with text {0}: {1}\n'.format(text), e)


def _insert_project(project):
    """
    Emit INSERT statements for the given project
    """
    print project
    # Note must use UTF-8
    _stm = u"""
        INSERT INTO level3.project (
            proj_uid, proj_name, proj_date, hazrd_type, proj_locle,
            hazrd_name, proj_sumry,comment,
            epsg_code, date_made, user_made, date_chng, user_chng)
        SELECT
            {0}, {1}, {2}, {3}, {4}, {5},
            {6},
            {7}, {8},
            {9}, {10}, {11}, {12}
        WHERE NOT EXISTS (
            SELECT proj_uid FROM level3.project WHERE proj_uid={0}
        );
    """.format(*map(_quote_sql, project))

    sys.stdout.write(_stm)
    sys.stdout.write('\n\n')


def _insert_all_projects(cursor, input_db):
    """
    Emit INSERT statements for all projects in DB
    """
    for _project in cursor.execute('SELECT * FROM GEM_PROJECT'):
        _insert_project(_project)


_OBJ_FLOAT_NAMES = ('X', 'Y')
_OBJ_INT_NAMES = (
    'STORY_AG_1', 'STORY_AG_2', 'STORY_BG_1', 'STORY_BG_2',
    'HT_GR_GF_1', 'HT_GR_GF_2', 'SLOPE',
    'YR_BUILT_1', 'YR_BUILT_2', 'YR_RETRO',
    'DIRECT_1', 'DIRECT_2'
)


def _insert_object(obj, names):
    """
    Emit INSERT statements for the given object
    """

    _params = u""
    for i in range(0, len(obj)):
        _name = names[i]
        #sys.stderr.write('!! Considering name {0}'.format(_name))
        _val = obj[i]
        if(i > 0):
            _params += ', '

        if(_name in _OBJ_FLOAT_NAMES or _name in _OBJ_INT_NAMES):
            _params += u"{0}".format(_val)
        else:
            _params += u"{0}".format(_quote_sql(_val))

    # Note must use UTF-8
    _stm = u"""
        INSERT INTO level3.object
        SELECT
            {0}
        WHERE NOT EXISTS (
            SELECT obj_uid FROM level3.object WHERE obj_uid={1}
        );
    """.format(_params, obj[0])
    sys.stdout.write(_stm)
    sys.stdout.write('\n\n')


def _insert_all_objects(cursor, input_db):
    for _object in cursor.execute('SELECT * FROM GEM_OBJECT'):
        _names = list(map(lambda x: x[0], cursor.description))
        _insert_object(_object, _names)


def ingest_db(input_db, input_source, notes):
    """
    Interrogate IDCT SQLite DB file and produce SQL for GED
    """
    con = None

    try:
        if(not os.path.isfile(input_db)):
            raise InputError(u"DB file '{0}' does not exist".format(input_db))
        _con = sqlite3.connect(input_db)
        _cursor = _con.cursor()
        _ensure_idct_db(_cursor, input_db)
        _insert_all_projects(_cursor, input_db)
        #_insert_all_objects(_cursor, input_db)
    except InputError as err:
        sys.stderr.write(u"Failed to ingest {0}: {1}\n".format(
            input_db, err.msg))
    except Exception as err:
        sys.stderr.write(u"Failed to ingest {0}: {1}\n".format(input_db, err))

    finally:
        if con:
            con.close()


def main():
    """
    Parse command line arguments, call ingest_db
    """
    if (len(sys.argv) < 3):
        sys.exit(u"Usage: {0} <inputdb> <source> [notes]\n".format(
            sys.argv[0]))

    input_db = sys.argv[1]
    input_source = sys.argv[2]

    if (len(sys.argv) > 3):
        notes = sys.argv[3]
    else:
        notes = None

    ingest_db(input_db, input_source, notes)


#
# Main driver
#
if __name__ == "__main__":
    main()