#!/usr/bin/env python
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

from osgeo import gdal
from osgeo.gdalconst import GA_ReadOnly
import sys

#
# Raster file paths
#
# TODO convert to command line arguments
#
_URBAN_FILE = '/data/ged/rebuild-pop/urban-rural/prj.adf'
_POP_FILE = '/data/ged/rebuild-pop/pop-input/prj.adf'


class RasterFile(object):
    """
    Representation of a raster file
    """

    def _open_file(self, filepath):
        """
        Open the given file for reading, raise an IOError on failure.
        Note does not actually read the real data yes, see load_data
        """

        self._filepath = filepath
        #
        # Force use of float64 for population data
        # Note that this requires use of GDAL 1.9 (see env.sh)
        # See http://lists.osgeo.org/pipermail/gdal-dev/2006-July/009570.html
        #
        gdal.SetConfigOption('AAIGRID_DATATYPE', 'Float64')
        self._handle = gdal.Open(filepath, GA_ReadOnly)
        # Clear flag after open
        gdal.SetConfigOption('AAIGRID_DATATYPE', None)

        if self._handle is None:
            raise IOError("Failed to open file {0}\n".format(filepath))

    def _init_metadata(self):
        self.width = self._handle.RasterXSize
        self.height = self._handle.RasterYSize
        _transform = self._handle.GetGeoTransform()
        self.x_origin = _transform[0]
        self.y_origin = _transform[3]
        self.pixel_width = _transform[1]
        self.pixel_height = _transform[5]

    def __init__(self, filepath):
        self._open_file(filepath)
        self._init_metadata()

    def load_data(self):
        """
        Load raster files into a (huge) array.
        For smaller machines a different approach should be used, for example
        by iterating over blocks of cells
        """
        _band = self._handle.GetRasterBand(1)
        sys.stderr.write('Loading data from {0}...\n'.format(self._filepath))

        self.data = _band.ReadAsArray(0, 0, self.width, self.height)
        if self.data is None:
            raise IOError('Failed to load data from {0}'
                          .format(self._filepath))

        sys.stderr.write('DONE Loading data from {0}...\n'
                         .format(self._filepath))

    def lon(self, x):
        """
        The longitude corresponding to the given x (pixel) value
        """
        # Note + 0.5 to place point in centre of pixel
        return ((x + 0.5) * self.pixel_width) + self.x_origin

    def lat(self, y):
        """
        The latitude corresponding to the given y (pixel) value
        """
        # Note + 0.5 to place point in centre of pixel
        return ((y + 0.5) * self.pixel_height) + self.y_origin

    def x(self, lon):
        """
        The x (pixel) value for the given longitude
        """
        return int((lon - self.x_origin) / self.pixel_width)

    def y(self, lat):
        """
        The y (line) value for the given latitude
        """
        return int((lat - self.y_origin) / self.pixel_height)


class _CellCountValidator(object):
    """
    Helper class to check that cell counts are self-consistent
    """

    def __init__(self, raster):
        self.raster = raster

        #
        # Counters for different types of cell
        # Used for validation later

        self.water = 0
        self.land = 0
        self.skipped = 0

        self.urban = 0
        self.rural = 0
        self.null = 0

        self.total_read = 0

    def validate(self, startx=0, starty=0):
        """
        Validation checks - do our numbers add up?
        """

        total = (self.raster.width - startx) * self.raster.height
        expected = total - self.skipped
        water_and_Land = self.water + self.land
        urban_rural_num_sum = self.urban + self.rural + self.null

        sys.stderr.write('DONE total_read cells=' +
                         '{0}x{1} = {2} skipped={3} read={4} expected={5}\n'
                         .format(self.raster.width - startx,
                                 self.raster.height,
                                 total, self.skipped,
                                 self.total_read,
                                 expected))

        sys.stderr.write(' water={0}, land={1} sum={2}\n'
                         .format(self.water, self.land,
                                 water_and_Land))

        sys.stderr.write(' raster={0} rural={1} null={2} sum={3}\n'
                         .format(self.urban, self.rural,
                                 self.null,
                                 urban_rural_num_sum))

        if self.total_read != expected:
            sys.stderr.write('WARNING cells read=' +
                             '{0} != total_read-skipped={1}\n'
                             .format(self.total_read, expected))
        if total != water_and_Land + self.skipped:

            sys.stderr.write('WARNING total_read=' +
                             '{0} != land+water+skipped={1}\n'
                             .format(total,
                                     water_and_Land +
                                     self.skipped))

        if self.land != urban_rural_num_sum:
            sys.stderr.write('WARNING total_read land cells={0} != u+r+n={1}\n'
                             .format(self.land, urban_rural_num_sum))


def _extractData(urban, pop, validator, startx=0, starty=0):
    for x in range(startx, urban.width):

        lon = urban.lon(x)
        popX = pop.x(lon)

        #
        # The urban extent and population rasters are not the same size
        # avoid walking off the edge
        #
        if popX >= pop.width:
            sys.stderr.write('INFO no population values for ' +
                             'x={0} lon={1}, skipping\n'.format(x, lon))
            validator.skipped += urban.height
            continue

        for y in range(starty, urban.height):
            lat = urban.lat(y)
            pop_y = pop.y(lat)

            ur_value = urban.data[y, x]

            if pop_y >= pop.height:
                sys.stderr.write(
                    'INFO no population values for x=' +
                    '{0},y={1} ur_value={2}\n'.format(
                    x, y, ur_value))
                validator.skipped += urban.height - y
                continue

            pop_value = pop.data[pop_y, popX]
            validator.total_read += 1

            is_urban = None
            if ur_value == 1:
                is_urban = 'f'
                validator.rural += 1

            elif ur_value == 2:
                is_urban = 't'
                validator.urban += 1

            elif ur_value == 255:
                # no land mass
                if pop_value == 0:
                    validator.water += 1
                    continue  # do NOT write output or update land
                else:
                    #
                    # GRUMP 1995 Urban/Rural mapping has null values for
                    # the Maldives; we cannot simply assume null implies water
                    #
                    sys.stderr.write(
                        'WARNING NULL U/R values for ' +
                        'x={0},y={1}, lat={2},lon={3}, pop={4}\n'.format(
                        x, y, lat, lon, pop_value))
                    is_urban = '\\N'  # NULL SQL code
                    validator.null += 1
            else:
                sys.stderr.write(
                    'ERROR Unexpected U/R value ' +
                    '{4} found at x={0},y={1}, lat={2},lon={3}\n' +
                    ' Check file format and GDAL version\n'.format(
                    x, y, lat, lon, ur_value))
                sys.exit(1)

            sys.stdout.write('{0}\t{1}\t{2}\t{3}\n'.format(
                lat, lon, pop_value, is_urban))
            validator.land += 1


def main():
    """
    Read GRUMP population and urban-extent data into text file
    for import into DB
    """

    urban = RasterFile(_URBAN_FILE)
    pop = RasterFile(_POP_FILE)

    # Use for end-game testing
    #_startx=urban.width-2#width-10 #30322 #22360
    # TODO make this a command line argument
    _startx = 0

    validator = _CellCountValidator(urban)

    urban.load_data()
    pop.load_data()

    _extractData(urban, pop, validator, _startx)

    # After loading data, check the validate cell counts
    validator.validate(_startx)

#
# Main driver
#
if __name__ == "__main__":
    main()
