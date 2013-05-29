#
# Script to ingest all Level 0 and 1 .data files into the GED 
#
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (c) 2010-2012, GEM Foundation.
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
THIS_NAME=$(basename $0)

#
# Name of temporary file use PID to avoid problems with concurrent execution
#
TMP_FILE="/tmp/$THIS_NAME-$$.tmp"
DATA_DIR="unDatasets/NewData"
INGESTER="python ingest2ph.py"

#
# Ingest data from all level 0 data files
#
L0_ARGS="0 PAGER-STR v2.0 2013-01-01"
L0_FILES="*._lev0_.data"

L1_ARGS="1 GEM v2.0 2013-02-01"
L1_FILES="*..data"

#
# Function to perform actual ingestion.  
# Finds files, calls ingest scripts
#
function ingest_files() {
	DATA_DIR=$1
	DATA_FILES=$2
	INGEST_ARGS=$3

	find "$DATA_DIR" -name "$DATA_FILES" | while read DAT_FILE
	do
		echo "$THIS_NAME: ingesting $DAT_FILE"
		BN=$(basename "$DAT_FILE" .data)
		LOG_FILE="logs/$BN.log"
	
		#
		# Check for known material string with semi-colon
		#
		RV=$(grep "Mixed material: part wood;" "$DAT_FILE")
		if [ "$RV" = "" ]
		then
			# No bad material
			$INGESTER "$DAT_FILE" $INGEST_ARGS > "$LOG_FILE"
		else
			# Use sed to fix bad material
			echo "$THIS_NAME: replacing bad material field in $DAT_FILE"
			sed -e 's/Mixed material: part wood;/Mixed material: part wood,/' \
				"$DAT_FILE" > "$TMP_FILE"
			$INGESTER "$TMP_FILE" $INGEST_ARGS > "$LOG_FILE"
			rm $TMP_FILE
		fi
	done
}

#
# Create log if not already present
#
mkdir -p logs

#
# Ingest all Level 0 files, then all Level 1 files
#
ingest_files $DATA_DIR "$L0_FILES" "$L0_ARGS"
ingest_files $DATA_DIR "$L1_FILES" "$L1_ARGS"