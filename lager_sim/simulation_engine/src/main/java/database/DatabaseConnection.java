package database;

import io.github.cdimascio.dotenv.Dotenv;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DatabaseConnection {
    private static Connection connection;

    public static Connection getConnection() throws SQLException {
        if (connection == null || connection.isClosed()) {
            Dotenv dotenv = Dotenv.configure().directory("./").load();

            String url = "jdbc:postgresql://localhost:5432/" + dotenv.get("POSTGRES_DB");
            connection = DriverManager.getConnection(url, dotenv.get("POSTGRES_USER"), dotenv.get("POSTGRES_PASSWORD"));
        }
        return connection;
    }
}
