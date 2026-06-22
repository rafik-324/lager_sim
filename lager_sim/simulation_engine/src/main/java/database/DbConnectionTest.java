package database;

import io.github.cdimascio.dotenv.Dotenv;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DbConnectionTest {
    public static void main(String[] args) {
        System.out.println("Working Directory: " + System.getProperty("user.dir"));

        Dotenv dotenv = Dotenv.configure().directory("./").load();

        String url = "jdbc:postgresql://localhost:5432/" + dotenv.get("POSTGRES_DB");
        String user = dotenv.get("POSTGRES_USER");
        String password = dotenv.get("POSTGRES_PASSWORD");

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            System.out.println("Verbindung erfolgreich!");
            System.out.println("Verbunden mit: " + conn.getCatalog());
        } catch (SQLException e) {
            System.out.println("Verbindung fehlgeschlagen:");
            e.printStackTrace();
        }
    }
}