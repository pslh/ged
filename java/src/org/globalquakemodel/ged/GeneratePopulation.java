package org.globalquakemodel.ged;

import java.io.FileInputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;

// 
/**
 * Query population data from GED DB, and output data suitable 
 * for inporting into an OpenQuake oqmif.exposure_data table
 * using a SQL statement of the form:
 * 
 * COPY oqmif.exposure_data (exposure_model_id, asset_ref,taxonomy, number_of_units, site) 
 * FROM 'path to file' WITH DELIMITER '|';
 * 
 * 
 * @author Paul Henshaw
 * 
 */
public class GeneratePopulation {

	private static final int MAX_FETCH_SIZE = 10;
	private static final int MAX_INSERTS = 20;

	/**
	 * @param args
	 */
	public static void main(final String[] args) {
		try {
			final int modelID = 1;

			final Properties props = new Properties();
			props.load(new FileInputStream(System.getProperty("user.home")
					+ "/shared/GEM/keys/ged.props"));

			final Connection con = DriverManager.getConnection(
					"jdbc:postgresql://ged.ciesin.columbia.edu/ged", props);
			con.setAutoCommit(false);

			final PreparedStatement countryInfoStm = con
					.prepareStatement("SELECT iso, name FROM eqged.gadm_country WHERE id=?");

			final PreparedStatement pointStm = con.prepareStatement(
					"SELECT grid_point_id FROM eqged.grid_point_country country "
							+ " WHERE country.gadm_country_id=?",
					ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY);// ,
			// ResultSet.HOLD_CURSORS_OVER_COMMIT);

			final PreparedStatement popStm = con
					.prepareStatement("SELECT point.the_geom, pop.pop_value "
							+ "FROM eqged.grid_point point "
							+ "JOIN eqged.population pop ON pop.grid_point_id=point.id  "
							+ "WHERE point.id=? AND pop.population_src_id=5");

			final PreparedStatement insertStm = con
					.prepareStatement("INSERT INTO oqmif.exposure_data (id,"
							+ "exposure_model_id, asset_ref,taxonomy,"
							+ "number_of_units, site) "
							+ "VALUES (DEFAULT,?,?,?,?,?)");

			final int countryId = args.length > 0 ? Integer.parseInt(args[0])
					: 40; // CAN

			countryInfoStm.setInt(1, countryId);
			final ResultSet countryInfoRS = countryInfoStm.executeQuery();

			if (!countryInfoRS.next()) {
				// No country info
				con.close();
				throw new IllegalArgumentException("No info for country id "
						+ countryId);
			}
			final String countryIso = countryInfoRS.getString(1);
			final String countryName = countryInfoRS.getString(2);
			countryInfoRS.close();

			System.err
					.println("Populating oqmif.exposure_data with default population for "
							+ countryName + " " + countryIso + " " + countryId);

			pointStm.setInt(1, countryId);
			pointStm.setFetchSize(MAX_FETCH_SIZE);
			pointStm.setFetchDirection(ResultSet.FETCH_FORWARD);

			System.err.println("  obtaining points");

			final ResultSet pointRS = pointStm.executeQuery();

			System.err.println("  DONE obtaining points");

			int numInserts = 0;
			while (pointRS.next()) {
				final long pointId = pointRS.getLong(1);

				numInserts = handlePoint(modelID, con, popStm, insertStm,
						countryIso, numInserts, pointId);
				// else no population for this point e.g. sea or Antarctica
			}
			pointRS.close();

			if (numInserts % MAX_INSERTS != 0) {
				System.err.println("  Comitting (end) " + numInserts);
				con.commit();
			}
			con.close();
		} catch (final Exception exception) {
			exception.printStackTrace();

		}
	}

	private static int handlePoint(final int modelID, final Connection con,
			final PreparedStatement popStm, final PreparedStatement insertStm,
			final String countryIso, int numInserts, final long pointId)
			throws SQLException {
		System.err.println("  pointId= " + pointId);

		popStm.setLong(1, pointId);
		final ResultSet popRS = popStm.executeQuery();

		if (popRS.next()) {
			final String assetRef = countryIso + ":" + numInserts++;

			System.err.println("  assetRef " + assetRef);

			final long popValue = popRS.getLong(2);
			final Object geometry = popRS.getObject(1);

			handlePopVal(modelID, con, insertStm, countryIso, numInserts,
					assetRef, popValue, geometry);
			popRS.close();
		}
		return numInserts;
	}

	private static void OLDhandlePopVal(final int modelID,
			final Connection con, final PreparedStatement insertStm,
			final String countryIso, int numInserts, final String assetRef,
			final long popValue, final Object geometry) throws SQLException {
		insertStm.setInt(1, modelID);
		insertStm.setString(2, assetRef);
		insertStm.setString(3, countryIso);
		insertStm.setLong(4, popValue);
		insertStm.setObject(5, geometry);
		insertStm.execute();

		if (numInserts % MAX_INSERTS == 0) {
			System.err.println("  Comitting " + numInserts);
			con.commit();
		}
	}

	private static void handlePopVal_INSERT(final int modelID, final Connection con,
			final PreparedStatement insertStm, final String countryIso,
			int numInserts, final String assetRef, final long popValue,
			final Object geometry) throws SQLException {
		System.out.print("INSERT INTO oqmif.exposure_data (id,"
				+ "exposure_model_id, asset_ref,taxonomy,"
				+ "number_of_units, site) " + "VALUES (DEFAULT,");
		System.out.print(modelID);
		System.out.print(",'");
		System.out.print(assetRef);
		System.out.print("','");
		System.out.print(countryIso);
		System.out.print("',");
		System.out.print(popValue);
		System.out.print(",'");
		System.out.print(geometry);
		System.out.println("');");
	}

	/**
	 * @param modelID
	 * @param con
	 * @param insertStm
	 * @param countryIso
	 * @param numInserts
	 * @param assetRef
	 * @param popValue
	 * @param geometry
	 * @throws SQLException
	 */
	private static void handlePopVal(final int modelID, final Connection con,
			final PreparedStatement insertStm, final String countryIso,
			int numInserts, final String assetRef, final long popValue,
			final Object geometry) throws SQLException {
		System.out.print(modelID);
		System.out.print('|');
		System.out.print(assetRef);
		System.out.print('|');
		System.out.print(countryIso);
		System.out.print('|');
		System.out.print(popValue);
		System.out.print('|');
		System.out.println(geometry);
	}
}
