package repositories;

import database.DatabaseConnection;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;

public class LagerplatzRepository {

    private final AuftragRepository auftragRepository;

    public LagerplatzRepository(AuftragRepository auftragRepository) {
        this.auftragRepository = auftragRepository;
    }

    public void bearbeiteAeltestenOffenenAuftrag() {
        String sqlAuftrag = "SELECT auftrag_id, artikel_id, menge FROM auftrag " +
                "WHERE status = ? ORDER BY erstellt_am ASC LIMIT 1";

        try (Connection conn = DatabaseConnection.getConnection()) {
            conn.setAutoCommit(false);

            try (PreparedStatement stmt = conn.prepareStatement(sqlAuftrag)) {
                stmt.setString(1, "offen");

                try (ResultSet rs = stmt.executeQuery()) {
                    if (!rs.next()) {
                        System.out.println("Kein offener Auftrag vorhanden.");
                        conn.rollback();
                        return;
                    }

                    int auftragId = rs.getInt("auftrag_id");
                    int artikelId = rs.getInt("artikel_id");
                    int menge = rs.getInt("menge");

                    Integer lagerplatzId = findeLagerplatzMitBestand(conn, artikelId, menge);

                    if (lagerplatzId == null) {
                        System.out.println("Nicht genug Bestand für Auftrag " + auftragId + ".");
                        conn.rollback();
                        return;
                    }

                    reduziereBestand(conn, artikelId, lagerplatzId, menge);
                    buchePosition(conn, artikelId, lagerplatzId, menge);
                    auftragRepository.finishOrderPrepConnection(conn, auftragId);

                    conn.commit();
                    System.out.println("Auftrag " + auftragId + " vollständig abgearbeitet.");
                }
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }

        } catch (SQLException e) {
            System.out.println("Fehler beim Bearbeiten des Auftrags:");
            e.printStackTrace();
        }
    }

    private Integer findeLagerplatzMitBestand(Connection conn, int artikelId, int benoetigteMenge) throws SQLException {
        String sql = "SELECT platz_id FROM lagerplatz " +
                "WHERE artikel_id = ? AND menge >= ? " +
                "ORDER BY menge DESC LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, artikelId);
            stmt.setInt(2, benoetigteMenge);

            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt("platz_id") : null;
            }
        }
    }

    private void reduziereBestand(Connection conn, int artikelId, int lagerplatzId, int menge) throws SQLException {
        String sql = "UPDATE lagerplatz SET menge = menge - ? WHERE artikel_id = ? AND platz_id = ?";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, menge);
            stmt.setInt(2, artikelId);
            stmt.setInt(3, lagerplatzId);
            stmt.executeUpdate();
        }
    }

    private void buchePosition(Connection conn, int artikelId, int lagerplatzId, int menge) throws SQLException {
        String sql = "INSERT INTO bewegung (artikel_id, quelle_platz_id, ziel_platz_id, menge, zeitpunkt) " +
                "VALUES (?, ?, NULL, ?, ?)";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, artikelId);
            stmt.setInt(2, lagerplatzId);
            stmt.setInt(3, menge);
            stmt.setTimestamp(4, Timestamp.from(Instant.now()));
            stmt.executeUpdate();
        }
    }

    public static void main(String[] args) {
        AuftragRepository auftragRepository = new AuftragRepository();
        LagerplatzRepository lagerplatzRepository = new LagerplatzRepository(auftragRepository);

        System.out.println("--- Starte Verarbeitung des ältesten offenen Auftrags ---");
        lagerplatzRepository.bearbeiteAeltestenOffenenAuftrag();
        System.out.println("--- Verarbeitung abgeschlossen ---");
    }
}