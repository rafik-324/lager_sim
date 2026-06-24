package repositories;

import java.sql.*;
import java.time.Instant;
import database.DatabaseConnection;
import update.UpdateService;
import java.util.Random;

public class AuftragRepository {

    private int auftragIdCounter;

    public AuftragRepository(){
        auftragIdCounter = 100;
    }

    public void newOrder(int id, String typ, String status, int artikelId, int menge) {

        String sql = "INSERT INTO auftrag (auftrag_id, typ, status, artikel_id, menge, menge_erfuellt, erstellt_am, abgeschlossen_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, id);
            stmt.setString(2, typ);
            stmt.setString(3, status);
            stmt.setInt(4, artikelId);
            stmt.setInt(5, menge);
            stmt.setNull(6, Types.INTEGER);   // menge_erfuellt: bei Erstellung noch unbekannt
            stmt.setTimestamp(7, Timestamp.from(Instant.now()));
            stmt.setNull(8, Types.TIMESTAMP); // abgeschlossen_am: noch nicht abgeschlossen

            int rowsInserted = stmt.executeUpdate();
            auftragIdCounter++;
            System.out.println(rowsInserted + " Auftrag hinzugefügt!");

        } catch (SQLException e) {
            System.out.println("Fehler beim Hinzufügen des Auftrags:");
            e.printStackTrace();
        }
    }

    public void finishOrder(int auftragId) {
        String sql = "UPDATE auftrag SET status = ?, abgeschlossen_am = ? WHERE auftrag_id = ?";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, "abgeschlossen");
            stmt.setTimestamp(2, Timestamp.from(Instant.now()));
            stmt.setInt(3, auftragId);

            int rowsUpdated = stmt.executeUpdate();

            if (rowsUpdated > 0) {
                System.out.println("Auftrag " + auftragId + " als abgeschlossen markiert!");
            } else {
                System.out.println("Kein Auftrag mit ID " + auftragId + " gefunden.");
            }

        } catch (SQLException e) {
            System.out.println("Fehler beim Abschließen des Auftrags:");
            e.printStackTrace();
        }
    }

    public void finishOrderPrepConnection(Connection conn, int auftragId) throws SQLException {
        String sql = "UPDATE auftrag SET status = ?, abgeschlossen_am = ? WHERE auftrag_id = ?";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, "abgeschlossen");
            stmt.setTimestamp(2, Timestamp.from(Instant.now()));
            stmt.setInt(3, auftragId);
            stmt.executeUpdate();
        }
    }

    public void randOrder(){
        Random rand = new Random();

        int randId = findHoechsteAuftragId() + 1;

        String randType = "ausgang";
        boolean randB = rand.nextBoolean();
        if (randB){
            randType = "eingang";
        }

        String randStatus = "offen";


        int randAid = rand.nextInt(10) + 1;

        int randMenge = rand.nextInt(40,60) + 1;

        newOrder(randId, randType, randStatus, randAid, randMenge);
        System.out.println("Oder hinzugefügt " + findHoechsteAuftragId());

    }

    public void randRestock(){
        Random rand = new Random();

        int randId = findHoechsteAuftragId() + 1;

        String randType = "eingang";

        String randStatus = "offen";

        int randAid = rand.nextInt(10) + 1;

        int randMenge = rand.nextInt(40,60) + 1;

        newOrder(randId, randType, randStatus, randAid, randMenge);
        System.out.println("Oder hinzugefügt " + findHoechsteAuftragId());

    }

    public void randDestock(){
        Random rand = new Random();

        int randId = findHoechsteAuftragId() + 1;

        String randType = "ausgang";

        String randStatus = "offen";

        int randAid = rand.nextInt(10) + 1;

        int randMenge = rand.nextInt(40,60) + 1;

        newOrder(randId, randType, randStatus, randAid, randMenge);
        System.out.println("Oder hinzugefügt " + findHoechsteAuftragId());

    }

    public void printCurrId (){
        System.out.println(auftragIdCounter);
    }

    public int findHoechsteAuftragId() {
        String sql = "SELECT COALESCE(MAX(auftrag_id), 0) AS max_id FROM auftrag";

        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            if (rs.next()) {

                return rs.getInt("max_id");
            }
            return 0;

        } catch (SQLException e) {
            throw new RuntimeException("Fehler beim Ermitteln der höchsten Auftrag-ID", e);
        }
    }

    public static void main(String[] args) {
        System.out.println("Working Directory: " + System.getProperty("user.dir"));
        UpdateService service = new UpdateService();
        AuftragRepository newRep = new AuftragRepository();
        //newRep.newOrder(5, "ausgang", "offen", 3, 25);
        //newRep.finishOrder(4);

        newRep.randOrder();
        //System.out.print(newRep.findHoechsteAuftragId());
        //newRep.findHoechsteAuftragId();

    }

}
