#
# Generate TileMill project.mml and style.mss files for
# a directory of ShapeFiles
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

THIS=$(readlink -f "$0")
THIS_DIR=$(dirname "$THIS")
THIS_NAME=$(basename "$THIS" .sh)

#
# Template files
#
TEMPLATE_DIR="$(readlink -f $THIS_DIR/../templates)"
TEMPLATE="$TEMPLATE_DIR/project-template.mml"
STYLE_TEMPLATE="$TEMPLATE_DIR/style-template.mss"
PROJECT_HEADER="$TEMPLATE_DIR/project-header.mml"
PROJECT_FOOTER="$TEMPLATE_DIR/project-footer.mml"

#
# Output files
#
PROJECT_OUT=project.mml
STYLE_OUT=style.mss

#
# Check for presence of template files
#
if [ ! -f "$TEMPLATE" ]
then
	echo "$0: Unable to find template file $TEMPLATE"
	exit 1
fi
if [ ! -f "$STYLE_TEMPLATE" ]
then
	echo "$0: Unable to find template file $STYLE_TEMPLATE"
	exit 1
fi
if [ ! -f "$PROJECT_HEADER" ]
then
	echo "$0: Unable to find template file $PROJECT_HEADER"
	exit 1
fi
if [ ! -f "$PROJECT_FOOTER" ]
then
	echo "$0: Unable to find template file $PROJECT_FOOTER"
	exit 1
fi

#
# Do not overwrite output files
#
if [ -f $PROJECT_OUT ]
then
	echo "$0: $PROJECT_OUT exists, halting"
	exit 1
fi
if [ -f $STYLE_OUT ]
then
	echo "$0: $STYLE_OUT exists, halting"
	exit 1
fi

#
# Check input parameters
#
if [ $# = 0 ]
then
	echo "Usage: $0 <in dir> " >&2
	exit 1;
fi

#
#  
#
IN_DIR=$(readlink -f "$1")
if [ ! -d "$IN_DIR" ]
then
	echo "$0: $IN_DIR is not a directory" >&2
	echo "Usage: $0 <in dir> " >&2
	exit 1
fi

#
# Initialise output with header
#
cat "$PROJECT_HEADER" > $PROJECT_OUT

COUNT=0
SED_FILE=$(tempfile -p "$THIS_NAME")".sed"

#
# For each ShapeFile...
#  Generate a spatial index if not present
#  Generate a .sed file with template parameters
#  Use sed and templates to output project and style entries
#
for SHP_FILE in $(ls $IN_DIR/*.shp)
do
	echo "$THIS_NAME: considering $SHP_FILE" >&2

	# Emit comma separator in project if not first entry
	if [ $COUNT -gt 0 ]
	then
		echo '	,' >> $PROJECT_OUT
	fi
	COUNT=$(($COUNT+1))

	# Generate spatial index if not present
	SHP_BASE=$(basename "$SHP_FILE" .shp)
	SHP_INDEX="$IN_DIR/$SHP_BASE.index"
	if [ ! -f "$SHP_INDEX" ]
	then
		echo "$0: generating index on $SHP_FILE" >&2
		shapeindex $SHP_FILE 2>/dev/null
	fi
	SHP_PATH=$(readlink -f "$SHP_FILE")

	# Use ogrinfo to obtain shapefile Extent
	SHP_EXTENT=$(ogrinfo -al -so "$SHP_FILE" | grep Extent: | \
	  sed -e "s/^Extent: (\(.*\), \(.*\)) - (\(.*\), \(.*\))$/\1,\2,\3,\4/")

	# Generate .sed file
	cat > $SED_FILE << __END__
s%@SHP_FILE@%$SHP_BASE%g
s%@SHP_PATH@%$SHP_PATH%g
s/@SHP_EXTENT@/$SHP_EXTENT/g
__END__

	# Use template and sed to generate output entries
	sed -f $SED_FILE $TEMPLATE >> $PROJECT_OUT
	sed -f $SED_FILE $STYLE_TEMPLATE >> $STYLE_OUT
done

# Emit project footer
cat "$PROJECT_FOOTER" >> $PROJECT_OUT

# Cleanup
rm -f "$SED_FILE"
