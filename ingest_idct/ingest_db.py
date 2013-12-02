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


class InputError(RuntimeError):
    """Exception raised for errors in the input.

    Attributes:
        msg  -- explanation of the error
    """

    def __init__(self, msg):
        self.msg = msg


def _ensure_idct_db(cur, input_db):
    """
    Raise an InputError if input_db is not a valid IDCT SQLite file
    """

    cur.execute("""
            SELECT count(name) AS num_tables
            FROM sqlite_master
            WHERE name IN ('GEM_PROJECT', 'GEM_OBJECT', 'GED', 'MEDIA_DETAIL');
            """)
    row = cur.fetchone()

    if(row):
        num_tables = row[0]

    if(num_tables != 4):
        # ERROR - DB does not contain all required tables.
        raise InputError(
            "DB schema {0} does not contain the expected tables.\n".format(
            input_db))

    sys.stderr.write("Found {0} tables".format(num_tables))


def _quote_sql(text):
    """
    If text is None return 'NULL', otherwise return text enclosed in quotes.
    Used to construct query strings from parameters that might be None
    """
    if(text is None):
        return 'NULL'
    else:
        return u"'{0}'".format(text)


def _insert_project(project):
    """
    Emit INSERT statements for the given project
    """

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
            SELECT proj_uid FROM level3.project
            WHERE proj_uid={0}
        );
    """.format(*map(_quote_sql, project))

    sys.stdout.write(_stm)
    sys.stdout.write('\n\n')


def _insert_all_projects(cur, input_db):
    """
    Emit INSERT statements for all projects in DB
    """
    for project in cur.execute('SELECT * FROM GEM_PROJECT'):
        _insert_project(project)


def ingest_db(input_db, input_source, notes):
    """
    Interrogate IDCT SQLite DB file and produce SQL for GED
    """
    con = None

    try:
        con = sqlite3.connect(input_db)
        cur = con.cursor()
        _ensure_idct_db(cur, input_db)
        _insert_all_projects(cur, input_db)

    finally:
        if con:
            con.close()


def main():
    """
    Parse command line arguments, call ingest_db
    """
    if (len(sys.argv) < 3):
        sys.exit("Usage: {0} <inputdb> <source> [notes]\n".format(sys.argv[0]))

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
