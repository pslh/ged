package org.globalquakemodel.ged;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Query population data from GED DB, and output data suitable for inporting
 * into an OpenQuake oqmif.exposure_data table using a SQL statement of the
 * form:
 * 
 * COPY oqmif.exposure_data (exposure_model_id, asset_ref,taxonomy,
 * number_of_units, site) FROM 'path to file' WITH DELIMITER '|';
 * 
 * @created 2012-08-08
 * @author Paul Henshaw
 */
public class GeneratePopulation {

	private static final int MAX_FETCH_SIZE = 10;
	private static final char DELIMITER = '|';

	public static class Country {
		private final int countryID;
		private final String countryIso;
		private final String countryName;

		/**
		 * @param countryID
		 * @param countryIso
		 * @param countryName
		 */
		private Country(final int countryID, final String countryIso,
				final String countryName) {
			super();
			this.countryID = countryID;
			this.countryIso = countryIso;
			this.countryName = countryName;
		}

		/**
		 * @return
		 */
		public int getCountryID() {
			return countryID;
		}

		/**
		 * @return
		 */
		public String getCountryIso() {
			return countryIso;
		}

		/**
		 * @return
		 */
		public String getCountryName() {
			return countryName;
		}

		@Override
		public String toString() {
			return countryName + " " + countryIso + " " + countryID;
		}

	}

	private final Connection con;
	private final int modelID;

	private final PreparedStatement countryInfoStm;
	private final PreparedStatement pointStm;
	private final PreparedStatement popStm;
	private int numRecords;

	/**
	 * @param modelID
	 * @throws FileNotFoundException
	 * @throws IOException
	 * @throws SQLException
	 */
	public GeneratePopulation(final int modelID) throws FileNotFoundException,
			IOException, SQLException {
		this.modelID = modelID;
		final Properties props = new Properties();
		props.load(new FileInputStream(System.getProperty("user.home")
				+ "/shared/GEM/keys/ged.props"));

		con = DriverManager.getConnection(
				"jdbc:postgresql://ged.ciesin.columbia.edu/ged", props);
		con.setAutoCommit(false);

		countryInfoStm = con
				.prepareStatement("SELECT iso, name FROM eqged.gadm_country WHERE id=?");

		// NOTE - it would have been interesting to add
		// ResultSet.HOLD_CURSORS_OVER_COMMIT
		// and insert the data directly, but this appears to cause the
		// points to be returned
		// all at once rather than using a cursor.
		pointStm = con.prepareStatement(
				"SELECT grid_point_id FROM eqged.grid_point_country country "
						+ " WHERE country.gadm_country_id=?",
				ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY);

		popStm = con.prepareStatement("SELECT point.the_geom, pop.pop_value "
				+ "FROM eqged.grid_point point "
				+ "JOIN eqged.population pop ON pop.grid_point_id=point.id  "
				+ "WHERE point.id=? AND pop.population_src_id=5");

	}

	/**
	 * @throws SQLException
	 */
	public void shutdown() throws SQLException {
		con.close();
	}

	/**
	 * @param country
	 * @throws SQLException
	 */
	public void handleCountry(final Country country, final PrintStream stream)
			throws SQLException {
		System.err
				.println("Populating oqmif.exposure_data with default population for "
						+ country);

		pointStm.setInt(1, country.getCountryID());
		pointStm.setFetchSize(MAX_FETCH_SIZE);
		pointStm.setFetchDirection(ResultSet.FETCH_FORWARD);

		final ResultSet pointRS = pointStm.executeQuery();

		long lastTS = System.currentTimeMillis();

		while (pointRS.next()) {
			final long pointId = pointRS.getLong(1);

			handlePoint(country.getCountryIso(), pointId, stream);
			// else no population for this point e.g. sea or Antarctica

			long now = System.currentTimeMillis();
			if (now > lastTS + 5000) {
				lastTS = now;
				System.err.println(" Still working... row " + numRecords);
			}
		}
		pointRS.close();
	}

	/**
	 * @param countryId
	 * @return Country
	 * @throws SQLException
	 */
	private Country getCountry(final int countryId) throws SQLException {
		countryInfoStm.setInt(1, countryId);
		final ResultSet countryInfoRS = countryInfoStm.executeQuery();

		if (!countryInfoRS.next()) {
			// No country info
			con.close();
			throw new IllegalArgumentException("No info for country id "
					+ countryId);

		}

		final Country country = new Country(countryId,
				countryInfoRS.getString(1), countryInfoRS.getString(2));
		countryInfoRS.close();
		return country;
	}

	/**
	 * @param countryIso
	 * @param numRecords
	 * @param pointId
	 * @param stream
	 * @throws SQLException
	 */
	private void handlePoint(final String countryIso, final long pointId,
			final PrintStream stream) throws SQLException {
		popStm.setLong(1, pointId);
		final ResultSet popRS = popStm.executeQuery();

		if (popRS.next()) {
			final String assetRef = countryIso + ":" + numRecords++;
			handlePopVal(countryIso, assetRef, popRS.getLong(2),
					popRS.getObject(1), stream);
			popRS.close();
		}
	}

	/**
	 * @param countryIso
	 * @param assetRef
	 * @param popValue
	 * @param geometry
	 * @param stream
	 * @throws SQLException
	 */
	private void handlePopVal(final String countryIso, final String assetRef,
			final long popValue, final Object geometry, PrintStream stream)
			throws SQLException {

		stream.print(modelID);
		stream.print(DELIMITER);
		stream.print(assetRef);
		stream.print(DELIMITER);
		stream.print(countryIso);
		stream.print(DELIMITER);
		stream.print(popValue);
		stream.print(DELIMITER);
		stream.println(geometry);
	}

	/**
	 * @param args
	 */
	public static void main(final String[] args) {
		try {

			final int countryId = args.length > 0 ? Integer.parseInt(args[0])
					: 40; // CAN

			// TODO obtain model ID from somewhere, command line? Properties?
			final GeneratePopulation generator = new GeneratePopulation(1);

			final Country country = generator.getCountry(countryId);

			System.err.println("Handling country " + country);

			generator.handleCountry(country, System.out);

			generator.shutdown();

		} catch (final Exception exception) {
			exception.printStackTrace();
		}
	}
}
