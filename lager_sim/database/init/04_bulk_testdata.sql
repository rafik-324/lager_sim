-- =========================================================
-- 04_bulk_testdata.sql
-- Erzeugt größere Mengen an Testdaten in einem Schritt (kein Echtzeit-Insert!).
-- Die Zeitstempel werden so berechnet, als wären die Daten über einen
-- bestimmten Zeitraum entstanden - das Skript selbst läuft aber sofort durch.
--
-- Hinweis v2: inhaltlich unverändert zu v1. quelle_platz_id/ziel_platz_id
-- werden weiterhin zufällig aus lagerplatz gewählt - das funktioniert
-- unverändert, es gibt jetzt einfach 60 statt 6 mögliche Plätze.
-- =========================================================

-- ---------------------------------------------------------
-- 1) BULK BEWEGUNGEN
-- 1000 zufällige Bewegungen, verteilt über die letzten 30 Tage
-- ---------------------------------------------------------
-- Wichtig: typ und menge werden zuerst in einer CTE bestimmt und dann
-- voneinander ABHAENGIG weiterverarbeitet (nicht unabhaengig in derselben
-- SELECT-Liste), sonst kann eine negative Menge bei einem Nicht-'inventur'-Typ
-- entstehen und den CHECK-Constraint verletzen.
WITH zufall AS (
    SELECT
        s,
        (SELECT artikel_id FROM artikel ORDER BY random() LIMIT 1) AS artikel_id,
        (ARRAY['wareneingang','warenausgang','umlagerung','kommissionierung','inventur'])[(floor(random()*5)+1)::int] AS typ,
        random() AS r_menge,
        (CASE WHEN random() < 0.7 THEN (SELECT platz_id FROM lagerplatz ORDER BY random() LIMIT 1) ELSE NULL END) AS quelle_platz_id,
        (CASE WHEN random() < 0.7 THEN (SELECT platz_id FROM lagerplatz ORDER BY random() LIMIT 1) ELSE NULL END) AS ziel_platz_id,
        now() - (random() * interval '30 days') AS zeitstempel
FROM generate_series(1, 1000) AS s
    )
INSERT INTO bewegung (artikel_id, typ, menge, quelle_platz_id, ziel_platz_id, zeitstempel)
SELECT
    artikel_id,
    typ,
    -- Menge haengt jetzt vom bereits feststehenden typ ab:
    -- bei 'inventur' darf sie negativ sein (Schwund), sonst MUSS sie positiv sein
    CASE
        WHEN typ = 'inventur' AND r_menge < 0.5 THEN -(floor(r_menge*10)+1)::int
        ELSE (floor(r_menge*50)+1)::int
END,
    quelle_platz_id,
    ziel_platz_id,
    zeitstempel
FROM zufall;

-- ---------------------------------------------------------
-- 2) SIMULIERTER ROBOTERPFAD ÜBER 2 MINUTEN
-- Roboter 1 läuft einen Pfad von Punkt A nach Punkt B,
-- mit 60 Zwischenschritten (alle 2 Sekunden ein Punkt, simulierte Zeit).
-- Kein Echtzeit-Insert - alle Zeilen werden sofort eingefügt,
-- nur die zeitstempel-Spalte spiegelt den 2-Minuten-Verlauf wider.
-- ---------------------------------------------------------
WITH pfad AS (
    SELECT
        s AS schritt,
        -- lineare Interpolation zwischen Startpunkt (0,0) und Zielpunkt (40,25)
        0   + (40 - 0)   * (s::float / 60) AS x,
        0   + (25 - 0)   * (s::float / 60) AS y,
        -- Startzeitpunkt: vor 2 Minuten, dann je Schritt +2 Sekunden
        now() - interval '2 minutes' + (s * interval '2 seconds') AS zeitstempel
FROM generate_series(0, 60) AS s
    )
INSERT INTO roboter_position (roboter_id, x, y, platz_id, zeitstempel)
SELECT
    1,              -- Roboter-ID 1 (Kommissionierer-01)
    round(x::numeric, 2),
    round(y::numeric, 2),
    NULL,           -- kein fester Lagerplatz während der Fahrt
    zeitstempel
FROM pfad;

-- Endpunkt des Pfads exakt auf einen Lagerplatz "einrasten" lassen (platz_id 2 = "aA2")
UPDATE roboter_position
SET platz_id = 2
WHERE roboter_id = 1
  AND zeitstempel = (SELECT max(zeitstempel) FROM roboter_position WHERE roboter_id = 1);
