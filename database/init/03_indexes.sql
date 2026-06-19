-- =========================================================
-- 03_indexes.sql
-- Indizes für Performance bei den typischen Abfragemustern:
--   - Live-Dashboards (Grafana) fragen häufig nach Zeiträumen
--   - Joins über Foreign Keys (artikel_id, platz_id, roboter_id)
--   - Statusfilter (offen/abgeschlossen, aktiv/idle, etc.)
-- =========================================================

-- ---------------------------------------------------------
-- BESTAND
-- Schnelle Lookups "Bestand für Artikel X" / "Bestand auf Platz Y"
-- (FKs werden in Postgres NICHT automatisch indiziert!)
-- ---------------------------------------------------------
CREATE INDEX idx_bestand_artikel ON bestand (artikel_id);
CREATE INDEX idx_bestand_platz   ON bestand (platz_id);

-- ---------------------------------------------------------
-- BEWEGUNG
-- Zeitraum-Abfragen (Umschlag, Ein-/Ausgänge pro Zeiteinheit)
-- und Filter nach Artikel bzw. Bewegungstyp
-- ---------------------------------------------------------
CREATE INDEX idx_bewegung_zeitstempel ON bewegung (zeitstempel);
CREATE INDEX idx_bewegung_artikel     ON bewegung (artikel_id);
CREATE INDEX idx_bewegung_typ         ON bewegung (typ);
-- Kombi-Index für "Bewegungen eines Artikels über die Zeit" (Umschlagshäufigkeit)
CREATE INDEX idx_bewegung_artikel_zeit ON bewegung (artikel_id, zeitstempel);

-- ---------------------------------------------------------
-- AUFTRAG
-- Filter nach Status (offene Aufträge) und Durchlaufzeit-Berechnung
-- ---------------------------------------------------------
CREATE INDEX idx_auftrag_status      ON auftrag (status);
CREATE INDEX idx_auftrag_erstellt_am ON auftrag (erstellt_am);

-- ---------------------------------------------------------
-- AUFTRAG_POSITION
-- Lookup aller Positionen eines Auftrags bzw. eines Artikels
-- (für Service-Level-/Lieferbereitschaftsgrad-Berechnung)
-- ---------------------------------------------------------
CREATE INDEX idx_auftrag_position_auftrag ON auftrag_position (auftrag_id);
CREATE INDEX idx_auftrag_position_artikel ON auftrag_position (artikel_id);
CREATE INDEX idx_auftrag_position_status  ON auftrag_position (status);

-- ---------------------------------------------------------
-- ROBOTER_POSITION
-- Live-Tracking: "letzte Positionen von Roboter X über die Zeit"
-- -> wichtigster Index für die Echtzeit-Karte in Grafana
-- ---------------------------------------------------------
CREATE INDEX idx_roboter_position_roboter_zeit ON roboter_position (roboter_id, zeitstempel DESC);

-- ---------------------------------------------------------
-- EVENT_LOG
-- Audit-Trail wird meist nach Zeit oder betroffener Tabelle gefiltert
-- ---------------------------------------------------------
CREATE INDEX idx_event_log_zeitstempel ON event_log (zeitstempel);
CREATE INDEX idx_event_log_tabelle     ON event_log (tabelle);