package repositories;

import database.DatabaseConnection;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;

public class LagerplatzRepository {

    private final AuftragRepository auftragRepository;

    public LagerplatzRepository(AuftragRepository auftragRepository) {
        this.auftragRepository = auftragRepository;
    }

    public void bearbeiteAeltestenOffenenAuftrag() {
        String sqlAuftrag = "SELECT auftrag_id, typ, artikel_id, menge FROM auftrag " +
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
                    String typ = rs.getString("typ");
                    int artikelId = rs.getInt("artikel_id");
                    int menge = rs.getInt("menge");

                    if ("eingang".equals(typ)) {
                        bearbeiteEingang(conn, auftragId, artikelId, menge);
                    } else {
                        bearbeiteAusgang(conn, auftragId, artikelId, menge);

                    }
                }

                conn.commit();

            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }

        } catch (SQLException e) {
            System.out.println("Fehler beim Bearbeiten des Auftrags:");
            e.printStackTrace();
        }
    }

    private void bearbeiteAusgang(Connection conn, int auftragId, int artikelId, int menge) throws SQLException {
        Integer lagerplatzId = findeLagerplatzMitBestand(conn, artikelId, menge);

        if (lagerplatzId == null) {
            System.out.println("Nicht genug Bestand für Auftrag " + auftragId + " – markiere als nicht erfüllbar.");
            markiereAlsNichtErfuellbar(conn, auftragId);
            return;
        }

        reduziereBestand(conn, artikelId, lagerplatzId, menge);
        buchePosition(conn, artikelId, lagerplatzId, null, menge, "warenausgang");
        auftragRepository.finishOrderPrepConnection(conn, auftragId);

        System.out.println("Auftrag " + auftragId + " (Ausgang) vollständig abgearbeitet.");
    }

    private void bearbeiteEingang(Connection conn, int auftragId, int artikelId, int menge) throws SQLException {
        Integer lagerplatzId = findeLagerplatzFuerEinlagerung(conn, artikelId, menge);

        if (lagerplatzId == null) {
            System.out.println("Kein passender Lagerplatz für Auftrag " + auftragId + " – markiere als nicht erfüllbar.");
            markiereAlsNichtErfuellbar(conn, auftragId);
            return;
        }

        erhoeheBestand(conn, artikelId, lagerplatzId, menge);
        buchePosition(conn, artikelId, null, lagerplatzId, menge, "wareneingang");
        auftragRepository.finishOrderPrepConnection(conn, auftragId);

        System.out.println("Auftrag " + auftragId + " (Eingang) vollständig abgearbeitet.");
    }

    private void markiereAlsNichtErfuellbar(Connection conn, int auftragId) throws SQLException {
        String sql = "UPDATE auftrag SET status = 'nicht_erfuellbar' WHERE auftrag_id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, auftragId);
            stmt.executeUpdate();
        }
    }

    private Integer findeLagerplatzMitBestand(Connection conn, int artikelId, int benoetigteMenge) throws SQLException {
        String sql = "SELECT platz_id FROM lagerplatz " +
                "WHERE artikel_id = ? AND bestand >= ? " +
                "ORDER BY bestand DESC LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, artikelId);
            stmt.setInt(2, benoetigteMenge);

            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt("platz_id") : null;
            }
        }
    }

    private Integer findeLagerplatzFuerEinlagerung(Connection conn, int artikelId) throws SQLException {
        // 1. Bevorzugt: Platz, auf dem der Artikel bereits liegt (Bestand auffüllen)
        String sqlVorhanden = "SELECT platz_id FROM lagerplatz WHERE artikel_id = ? LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sqlVorhanden)) {
            stmt.setInt(1, artikelId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("platz_id");
                }
            }
        }

        // 2. Sonst: ein leerer Platz (kein Artikel zugewiesen)
        String sqlLeer = "SELECT platz_id FROM lagerplatz WHERE artikel_id IS NULL LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sqlLeer)) {
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt("platz_id") : null;
            }
        }
    }

    private void reduziereBestand(Connection conn, int artikelId, int lagerplatzId, int menge) throws SQLException {
        String sql = "UPDATE lagerplatz SET bestand = bestand - ? WHERE artikel_id = ? AND platz_id = ?";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, menge);
            stmt.setInt(2, artikelId);
            stmt.setInt(3, lagerplatzId);
            stmt.executeUpdate();
        }
    }

    private void erhoeheBestand(Connection conn, int artikelId, int lagerplatzId, int menge) throws SQLException {
        String sql = "UPDATE lagerplatz SET bestand = bestand + ?, artikel_id = ? WHERE platz_id = ?";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, menge);
            stmt.setInt(2, artikelId);
            stmt.setInt(3, lagerplatzId);
            stmt.executeUpdate();
        }
    }

    private void buchePosition(Connection conn, int artikelId, Integer quellePlatzId, Integer zielPlatzId, int menge, String typ) throws SQLException {
        String sql = "INSERT INTO bewegung (artikel_id, quelle_platz_id, ziel_platz_id, menge, zeitstempel, typ) " +
                "VALUES (?, ?, ?, ?, ?, ?)";

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, artikelId);

            if (quellePlatzId != null) {
                stmt.setInt(2, quellePlatzId);
            } else {
                stmt.setNull(2, Types.INTEGER);
            }

            if (zielPlatzId != null) {
                stmt.setInt(3, zielPlatzId);
            } else {
                stmt.setNull(3, Types.INTEGER);
            }

            stmt.setInt(4, menge);
            stmt.setTimestamp(5, Timestamp.from(Instant.now()));
            stmt.setString(6, typ);
            stmt.executeUpdate();
        }
    }

    private Integer findeLagerplatzFuerEinlagerung(Connection conn, int artikelId, int menge) throws SQLException {
        // 1. Bevorzugt: Platz mit demselben Artikel, der die zusätzliche Menge noch aufnehmen kann
        String sqlVorhanden = "SELECT platz_id FROM lagerplatz " +
                "WHERE artikel_id = ? AND status != 'gesperrt' AND bestand + ? <= 100 " +
                "LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sqlVorhanden)) {
            stmt.setInt(1, artikelId);
            stmt.setInt(2, menge);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("platz_id");
                }
            }
        }

        // 2. Sonst: ein leerer, freier Platz (artikel_id IS NULL impliziert bestand = 0)
        String sqlLeer = "SELECT platz_id FROM lagerplatz " +
                "WHERE artikel_id IS NULL AND status = 'frei' AND ? <= 100 " +
                "LIMIT 1";

        try (PreparedStatement stmt = conn.prepareStatement(sqlLeer)) {
            stmt.setInt(1, menge);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt("platz_id") : null;
            }
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