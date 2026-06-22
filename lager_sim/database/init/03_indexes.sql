-- =========================================================
-- 03_indexes.sql
-- Indizes für Performance bei den typischen Abfragemustern (v2)
--   - Live-Dashboards (Grafana) fragen häufig nach Zeiträumen
--   - Joins über Foreign Keys (artikel_id, platz_id, roboter_id)
--   - Statusfilter (offen/abgeschlossen, aktiv/idle, etc.)
--   - Lookup von Lagerplätzen nach Lager/Schicht bzw. Artikel
-- =========================================================

-- ---------------------------------------------------------
-- LAGERPLATZ
-- (ersetzt die früheren idx_bestand_artikel / idx_bestand_platz,
-- da die bestand-Tabelle entfernt wurde und jetzt direkt auf
-- lagerplatz liegt)
-- ---------------------------------------------------------
CREATE INDEX idx_lagerplatz_artikel       ON lagerplatz (artikel_id);
CREATE INDEX idx_lagerplatz_lager_schicht ON lagerplatz (lager, schicht);
CREATE INDEX idx_lagerplatz_bezeichnung   ON lagerplatz (bezeichnung);
-- (lager, schicht, nummer) ist bereits über den UNIQUE-Constraint indiziert

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
-- Filter nach Status (offene Aufträge), Durchlaufzeit-Berechnung
-- und Service-Level-Berechnung (menge_erfuellt / menge) pro Artikel
-- ---------------------------------------------------------
CREATE INDEX idx_auftrag_status      ON auftrag (status);
CREATE INDEX idx_auftrag_erstellt_am ON auftrag (erstellt_am);
CREATE INDEX idx_auftrag_artikel     ON auftrag (artikel_id);

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
