package update;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;
import database.DatabaseConnection;

public class UpdateService {

    public void newOrder(int id, String typ, String status) {

        String sql = "INSERT INTO auftrag (auftrag_id, typ, status, erstellt_am, abgeschlossen_am) VALUES (?, ?, ?, ?, ?)";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);
            stmt.setString(2, typ);
            stmt.setString(3, status);
            stmt.setTimestamp(4, Timestamp.from(Instant.now()));
            stmt.setNull(5, Types.TIMESTAMP);

            int rowsInserted = stmt.executeUpdate();
            System.out.println(rowsInserted + " Auftrag hinzugefügt!");

        } catch (SQLException e) {
            System.out.println("Fehler beim Hinzufügen des Auftrags:");
            e.printStackTrace();
        }
    }

    public static void main(String[] args) {
        System.out.println("Working Directory: " + System.getProperty("user.dir"));
        UpdateService service = new UpdateService();
        service.newOrder(5, "ausgang", "in_bearbeitung");
    }
}
