-- =========================================================
-- 01_schema.sql
-- Schema für die Echtzeit-Lagersimulation
-- Deckt folgende KPIs ab:
--   - Aktueller Lagerbestand pro Artikel        -> BESTAND
--   - Lagerumschlagshäufigkeit                   -> BEWEGUNG
--   - Lagerplatzauslastung (%)                   -> LAGERPLATZ + BESTAND
--   - Lieferbereitschaftsgrad / Service-Level     -> AUFTRAG_POSITION
--   - Durchschnittliche Durchlaufzeit             -> AUFTRAG
--   - Wareneingänge/-ausgänge pro Zeiteinheit     -> BEWEGUNG
--   - Schwund / Bestandsdifferenzen               -> BEWEGUNG (typ = 'inventur')
--   - Live-Position Kommissionierroboter          -> ROBOTER + ROBOTER_POSITION
-- =========================================================

-- ---------------------------------------------------------
-- ARTIKEL
-- Stammdaten aller im Lager geführten Artikel
-- ---------------------------------------------------------
CREATE TABLE artikel (
                         artikel_id      SERIAL PRIMARY KEY,
                         bezeichnung     VARCHAR(150) NOT NULL,
                         kategorie       VARCHAR(80),
                         min_bestand     INTEGER NOT NULL DEFAULT 0 CHECK (min_bestand >= 0),
                         max_bestand     INTEGER NOT NULL CHECK (max_bestand >= min_bestand),
                         ek_preis        NUMERIC(10,2) NOT NULL CHECK (ek_preis >= 0)
);

-- ---------------------------------------------------------
-- LAGERPLATZ
-- Physische Stellplätze im Lager (für Auslastungsberechnung)
-- ---------------------------------------------------------
CREATE TABLE lagerplatz (
                            platz_id        SERIAL PRIMARY KEY,
                            zone            VARCHAR(50) NOT NULL,
                            kapazitaet      INTEGER NOT NULL CHECK (kapazitaet > 0),
                            status          VARCHAR(20) NOT NULL DEFAULT 'frei'
                                CHECK (status IN ('frei', 'belegt', 'gesperrt'))
);

-- ---------------------------------------------------------
-- BESTAND
-- Aktueller Bestand je Artikel/Lagerplatz-Kombination
-- ---------------------------------------------------------
CREATE TABLE bestand (
                         bestand_id      SERIAL PRIMARY KEY,
                         artikel_id      INTEGER NOT NULL REFERENCES artikel(artikel_id) ON DELETE CASCADE,
                         platz_id        INTEGER NOT NULL REFERENCES lagerplatz(platz_id) ON DELETE CASCADE,
                         menge           INTEGER NOT NULL DEFAULT 0 CHECK (menge >= 0),
                         letzte_aenderung TIMESTAMPTZ NOT NULL DEFAULT now(),
                         UNIQUE (artikel_id, platz_id)
);

-- ---------------------------------------------------------
-- BEWEGUNG
-- Jede Lagerbewegung (Ein-/Ausgang, Umlagerung, Kommissionierung,
-- Inventurkorrektur). Historie = Basis für Umschlag, Schwund, etc.
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
-- ---------------------------------------------------------
CREATE TABLE auftrag (
                         auftrag_id      SERIAL PRIMARY KEY,
                         typ             VARCHAR(20) NOT NULL CHECK (typ IN ('eingang', 'ausgang')),
                         status          VARCHAR(20) NOT NULL DEFAULT 'offen'
                             CHECK (status IN ('offen', 'in_bearbeitung', 'abgeschlossen', 'storniert')),
                         erstellt_am     TIMESTAMPTZ NOT NULL DEFAULT now(),
                         abgeschlossen_am TIMESTAMPTZ,
                         CHECK (abgeschlossen_am IS NULL OR abgeschlossen_am >= erstellt_am)
);

-- ---------------------------------------------------------
-- AUFTRAG_POSITION
-- Einzelne Artikelpositionen je Auftrag
-- (bestellte vs. tatsächlich erfüllte Menge -> Lieferbereitschaftsgrad)
-- ---------------------------------------------------------
CREATE TABLE auftrag_position (
                                  position_id     SERIAL PRIMARY KEY,
                                  auftrag_id      INTEGER NOT NULL REFERENCES auftrag(auftrag_id) ON DELETE CASCADE,
                                  artikel_id      INTEGER NOT NULL REFERENCES artikel(artikel_id),
                                  menge           INTEGER NOT NULL CHECK (menge > 0),
                                  status          VARCHAR(20) NOT NULL DEFAULT 'offen'
                                      CHECK (status IN ('offen', 'kommissioniert', 'versendet', 'fehlend'))
);

-- ---------------------------------------------------------
-- ROBOTER
-- Stammdaten der Kommissionierroboter
-- ---------------------------------------------------------
CREATE TABLE roboter (
                         roboter_id      SERIAL PRIMARY KEY,
                         name            VARCHAR(80) NOT NULL,
                         status          VARCHAR(20) NOT NULL DEFAULT 'idle'
                             CHECK (status IN ('aktiv', 'idle', 'wartung', 'offline'))
);

-- ---------------------------------------------------------
-- ROBOTER_POSITION
-- Zeitreihe der Roboter-Positionen (Live-Tracking).
-- x/y = Koordinaten im Lager-Grid, platz_id optional, falls der
-- Roboter sich gerade exakt an einem definierten Lagerplatz befindet.
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
-- ---------------------------------------------------------
CREATE TABLE event_log (
                           event_id        SERIAL PRIMARY KEY,
                           tabelle         VARCHAR(50) NOT NULL,
                           aktion          VARCHAR(20) NOT NULL CHECK (aktion IN ('INSERT', 'UPDATE', 'DELETE')),
                           zeitstempel     TIMESTAMPTZ NOT NULL DEFAULT now(),
                           details         JSONB
);