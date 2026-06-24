-- =========================================================
-- 01_schema.sql
-- Schema für die Echtzeit-Lagersimulation (v2)
--
-- Änderungen gegenüber v1:
--   - bestand-Tabelle entfernt: Menge + Artikel liegen jetzt direkt
--     auf lagerplatz (1 Artikel pro Platz, max. 100 Stück)
--   - lagerplatz neu strukturiert: 2 Lager (a/b) x 3 Schichten (A/B/C)
--     x 10 Plätze (1-10) = 60 Plätze, Bezeichnung wird automatisch
--     generiert (z.B. "aA6")
--   - artikel.bestand_gesamt wird per Trigger automatisch aus der
--     Summe aller lagerplatz-Einträge dieses Artikels berechnet
--   - auftrag hat jetzt genau 1 Artikel pro Auftrag: artikel_id, menge
--     (bestellt) und menge_erfuellt (tatsächlich erfüllt). Damit fällt
--     auftrag_position komplett weg - die Service-Level-KPI läuft jetzt
--     direkt über menge vs. menge_erfuellt auf AUFTRAG.
--   - roboter / roboter_position unverändert
--
-- KPIs:
--   - Aktueller Lagerbestand pro Artikel        -> ARTIKEL.bestand_gesamt / LAGERPLATZ
--   - Lagerumschlagshäufigkeit                   -> BEWEGUNG
--   - Lagerplatzauslastung (%)                   -> LAGERPLATZ (bestand / 100)
--   - Lieferbereitschaftsgrad / Service-Level     -> AUFTRAG (menge_erfuellt / menge)
--   - Durchschnittliche Durchlaufzeit             -> AUFTRAG
--   - Wareneingänge/-ausgänge pro Zeiteinheit     -> BEWEGUNG
--   - Schwund / Bestandsdifferenzen               -> BEWEGUNG (typ = 'inventur')
--   - Live-Position Kommissionierroboter          -> ROBOTER + ROBOTER_POSITION
-- =========================================================

-- ---------------------------------------------------------
-- ARTIKEL
-- Stammdaten aller im Lager geführten Artikel
-- bestand_gesamt wird automatisch per Trigger synchronisiert
-- (siehe fn_artikel_bestand_sync unten) - NICHT manuell befüllen!
-- ---------------------------------------------------------
CREATE TABLE artikel (
                         artikel_id      SERIAL PRIMARY KEY,
                         bezeichnung     VARCHAR(150) NOT NULL,
                         kategorie       VARCHAR(80),
                         min_bestand     INTEGER NOT NULL DEFAULT 0 CHECK (min_bestand >= 0),
                         max_bestand     INTEGER NOT NULL CHECK (max_bestand >= min_bestand),
                         ek_preis        NUMERIC(10,2) NOT NULL CHECK (ek_preis >= 0),
                         bestand_gesamt  INTEGER NOT NULL DEFAULT 0 CHECK (bestand_gesamt >= 0)
);

-- ---------------------------------------------------------
-- LAGERPLATZ
-- 2 Lager (a, b) x 3 Schichten (A=oben, B=mitte, C=unten) x 10 Plätze
-- = 60 physische Stellplätze. Jeder Platz enthält höchstens EINEN
-- Artikel, mit max. 100 Stück. bezeichnung wird automatisch generiert,
-- z.B. "aA6" = Lager a, Schicht A, Platz 6.
-- ---------------------------------------------------------
CREATE TABLE lagerplatz (
                            platz_id        SERIAL PRIMARY KEY,
                            lager           CHAR(1) NOT NULL CHECK (lager IN ('a', 'b')),
                            schicht         CHAR(1) NOT NULL CHECK (schicht IN ('A', 'B', 'C')), -- A=oben, B=mitte, C=unten
                            nummer          INTEGER NOT NULL CHECK (nummer BETWEEN 1 AND 10),
                            bezeichnung     VARCHAR(4) GENERATED ALWAYS AS (lager || schicht || nummer::text) STORED,
                            artikel_id      INTEGER REFERENCES artikel(artikel_id),
                            bestand         INTEGER NOT NULL DEFAULT 0 CHECK (bestand BETWEEN 0 AND 100),
                            status          VARCHAR(20) NOT NULL DEFAULT 'frei'
                                CHECK (status IN ('frei', 'belegt', 'gesperrt')),
                            UNIQUE (lager, schicht, nummer),
                            -- ein leerer Platz (kein Artikel) darf keinen Bestand haben
                            CHECK ( (artikel_id IS NULL AND bestand = 0) OR artikel_id IS NOT NULL )
);

-- ---------------------------------------------------------
-- BEWEGUNG
-- Jede Lagerbewegung (Ein-/Ausgang, Umlagerung, Kommissionierung,
-- Inventurkorrektur). Historie = Basis für Umschlag, Schwund, etc.
-- Unverändert gegenüber v1.
-- ---------------------------------------------------------
CREATE TABLE bewegung (
                          bewegung_id     SERIAL PRIMARY KEY,
                          artikel_id      INTEGER NOT NULL REFERENCES artikel(artikel_id),
                          typ             VARCHAR(20) NOT NULL
                              CHECK (typ IN ('wareneingang', 'warenausgang', 'umlagerung', 'kommissionierung', 'inventur')),
                          menge           INTEGER NOT NULL,
                          quelle_platz_id INTEGER REFERENCES lagerplatz(platz_id),
                          ziel_platz_id   INTEGER REFERENCES lagerplatz(platz_id),
                          zeitstempel     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Menge darf nur bei Inventurkorrekturen negativ sein (Schwund),
    -- bei allen anderen Bewegungstypen muss sie positiv sein
                          CHECK (typ = 'inventur' OR menge > 0)
);

-- ---------------------------------------------------------
-- AUFTRAG
-- Wareneingangs- oder Versandaufträge (für Durchlaufzeit & Service-Level)
-- Genau 1 Artikel pro Auftrag (auftrag_position entfällt dadurch):
--   - artikel_id / menge        = welcher Artikel, bestellte Menge
--   - menge_erfuellt            = tatsächlich erfüllte/versendete Menge
--     (NULL solange offen/in_bearbeitung; bei storniert i.d.R. 0)
-- Lieferbereitschaftsgrad/Service-Level = SUM(menge_erfuellt)/SUM(menge)
-- ---------------------------------------------------------
CREATE TABLE auftrag (
                         auftrag_id      SERIAL PRIMARY KEY,
                         typ             VARCHAR(20) NOT NULL CHECK (typ IN ('eingang', 'ausgang')),
                         status      VARCHAR(20) NOT NULL DEFAULT 'offen'
                             CHECK (status IN ('offen', 'in_bearbeitung', 'abgeschlossen', 'storniert', 'nicht_erfuellbar')),
                         artikel_id      INTEGER NOT NULL REFERENCES artikel(artikel_id),
                         menge           INTEGER NOT NULL CHECK (menge > 0),
                         menge_erfuellt  INTEGER CHECK (menge_erfuellt IS NULL OR menge_erfuellt BETWEEN 0 AND menge),
                         erstellt_am     TIMESTAMPTZ NOT NULL DEFAULT now(),
                         abgeschlossen_am TIMESTAMPTZ,
                         CHECK (abgeschlossen_am IS NULL OR abgeschlossen_am >= erstellt_am)
);

-- ---------------------------------------------------------
-- ROBOTER
-- Stammdaten der Kommissionierroboter. Unverändert (für später).
-- ---------------------------------------------------------
CREATE TABLE roboter (
                         roboter_id      SERIAL PRIMARY KEY,
                         name            VARCHAR(80) NOT NULL,
                         status          VARCHAR(20) NOT NULL DEFAULT 'idle'
                             CHECK (status IN ('aktiv', 'idle', 'wartung', 'offline'))
);

-- ---------------------------------------------------------
-- ROBOTER_POSITION
-- Zeitreihe der Roboter-Positionen (Live-Tracking). Unverändert.
-- ---------------------------------------------------------
CREATE TABLE roboter_position (
                                  position_id     SERIAL PRIMARY KEY,
                                  roboter_id      INTEGER NOT NULL REFERENCES roboter(roboter_id) ON DELETE CASCADE,
                                  x               DOUBLE PRECISION NOT NULL,
                                  y               DOUBLE PRECISION NOT NULL,
                                  platz_id        INTEGER REFERENCES lagerplatz(platz_id),
                                  zeitstempel     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- EVENT_LOG
-- Audit-Trail für alle relevanten Änderungen in den Tabellen oben
-- Unverändert.
-- ---------------------------------------------------------
CREATE TABLE event_log (
                           event_id        SERIAL PRIMARY KEY,
                           tabelle         VARCHAR(50) NOT NULL,
                           aktion          VARCHAR(20) NOT NULL CHECK (aktion IN ('INSERT', 'UPDATE', 'DELETE')),
                           zeitstempel     TIMESTAMPTZ NOT NULL DEFAULT now(),
                           details         JSONB
);

-- =========================================================
-- TRIGGER 1: lagerplatz.status automatisch setzen
-- 'frei' wenn kein Artikel zugewiesen, 'belegt' wenn doch.
-- 'gesperrt' wird NIE automatisch überschrieben (manuell gesetzt,
-- z.B. für Wartung/Sperrung eines Platzes).
-- =========================================================
CREATE OR REPLACE FUNCTION fn_lagerplatz_status_sync()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status <> 'gesperrt' THEN
        NEW.status := CASE WHEN NEW.artikel_id IS NULL THEN 'frei' ELSE 'belegt' END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lagerplatz_status_sync
    BEFORE INSERT OR UPDATE ON lagerplatz
    FOR EACH ROW EXECUTE FUNCTION fn_lagerplatz_status_sync();

-- =========================================================
-- TRIGGER 2: artikel.bestand_gesamt automatisch synchronisieren
-- Wird bei jeder Änderung an lagerplatz (Insert/Update/Delete)
-- neu aus der Summe aller zugehörigen lagerplatz-Einträge berechnet.
-- =========================================================
CREATE OR REPLACE FUNCTION fn_artikel_bestand_sync()
RETURNS TRIGGER AS $$
BEGIN
    -- betroffenen "alten" Artikel aktualisieren (bei UPDATE/DELETE)
    IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND OLD.artikel_id IS NOT NULL THEN
        UPDATE artikel
        SET bestand_gesamt = COALESCE((SELECT SUM(bestand) FROM lagerplatz WHERE artikel_id = OLD.artikel_id), 0)
        WHERE artikel_id = OLD.artikel_id;
    END IF;

    -- betroffenen "neuen" Artikel aktualisieren (bei INSERT/UPDATE)
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.artikel_id IS NOT NULL THEN
        UPDATE artikel
        SET bestand_gesamt = COALESCE((SELECT SUM(bestand) FROM lagerplatz WHERE artikel_id = NEW.artikel_id), 0)
        WHERE artikel_id = NEW.artikel_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_artikel_bestand_sync
    AFTER INSERT OR UPDATE OR DELETE ON lagerplatz
    FOR EACH ROW EXECUTE FUNCTION fn_artikel_bestand_sync();

-- =========================================================
-- VIEW: wo liegt welcher Artikel
-- (ein Artikel kann an mehreren Lagerplätzen liegen -> Array statt
-- einzelner Spalte auf der Artikel-Tabelle)
-- =========================================================
CREATE VIEW v_artikel_lagerorte AS
SELECT
    a.artikel_id,
    a.bezeichnung,
    a.bestand_gesamt,
    COALESCE(
        array_agg(l.bezeichnung ORDER BY l.bezeichnung) FILTER (WHERE l.platz_id IS NOT NULL),
        ARRAY[]::varchar[]
    ) AS lagerorte
FROM artikel a
LEFT JOIN lagerplatz l ON l.artikel_id = a.artikel_id
GROUP BY a.artikel_id, a.bezeichnung, a.bestand_gesamt;
