package org.globalquakemodel.ged;

import java.io.FileInputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Properties;

public class Main {

	private static long lastTS = 0;

	private static final int MAX_POP_ID = 211764269;
	/*
	 * private static final String QUERY = "SELECT MAX(pop.pop_value) " +
	 * "FROM eqged.population pop " + "JOIN eqged.grid_point_attribute att " +
	 * "ON att.grid_point_id=pop.grid_point_id  " +
	 * "WHERE att.is_urban = FALSE  " + "AND att.grid_point_id > ? " +
	 * "AND att.grid_point_id < ?";
	 */

	private static final String QUERY = "SELECT pop.pop_value "
			+ "FROM eqged.population pop "
			+ "JOIN eqged.grid_point_attribute att "
			+ "ON att.grid_point_id=pop.grid_point_id  "
			+ "WHERE att.is_urban = FALSE  " + "AND att.grid_point_id > ? "
			+ "AND att.grid_point_id <= ?";

	private static final long THRESHOLD = 10000;

	/**
	 * @param args
	 */
	public static void main(final String[] args) {
		try {
			final int step = 1;

			final Properties props = new Properties();
			props.load(new FileInputStream(System.getProperty("user.home")
					+ "/shared/GEM/keys/ged.props"));

			final Connection con = DriverManager.getConnection(
					"jdbc:postgresql://ged.ciesin.columbia.edu/ged", props);

			initDebugLog("Connected...");

			con.createStatement().execute("SET temp_tablespaces = temp_ts");

			initDebugLog("SET temp_tablespaces...");

			con.createStatement()
					.execute("SET default_tablespace = default_ts");

			initDebugLog("SET default_tablespace...");

			final PreparedStatement statement = con.prepareStatement(QUERY);

			int startIndex = 0;
			int endIndex = step;
			double maxPop = 0.0;
			double thisPop = 0.0;
			while (endIndex < MAX_POP_ID) {

				debugLog("Loop: start=" + startIndex + " end=" + endIndex);

				statement.setInt(1, startIndex);
				statement.setInt(2, endIndex);
//				debugLog("Loop: executing query...");
//				final long startMS = System.currentTimeMillis();
				final ResultSet results = statement.executeQuery();
//				final long endMS = System.currentTimeMillis();
//				debugLog("Loop: executed query in " + (endMS - startMS) + "ms");

				while (results.next()) {
//					debugLog("Loop: looping on  query...");

					thisPop = results.getDouble(1);
					debugLog("Loop: thisPop=" + thisPop + " maxPop=" + maxPop);

					if (thisPop > maxPop) {
						maxPop = thisPop;
						initDebugLog("Loop: new max " + maxPop);
					}
				}
//				debugLog("Loop: done looping on  query...");

				results.close();
				startIndex = endIndex;
				endIndex += step;
			}
			System.out.println("Max=" + maxPop);
			con.close();
		} catch (final Exception exception) {
			exception.printStackTrace();
		}
	}

	/**
	 * @param message
	 */
	private static void debugLog(final String message) {
		final long ts = System.currentTimeMillis();
//		if (ts- lastTS > THRESHOLD) {
			lastTS=ts;
			System.err.println(ts+" "+message);
//		}
	}

	private static void initDebugLog(final String message) {
		System.err.println(message);
	}
}
