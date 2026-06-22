-- =========================================================
-- 02_seed_data.sql
-- Testdaten für alle Tabellen der Lagersimulation (v3)
--
-- v3: 10 Artikel statt 6, Bestände bewusst gleichmäßiger verteilt
-- (vorher 8 bis 3200 Stück - schlecht für Balkendiagramme in Grafana,
-- jetzt 320 bis 600 Stück pro Artikel).
-- =========================================================

-- ---------------------------------------------------------
-- ARTIKEL
-- bestand_gesamt NICHT mit einfügen - wird automatisch per Trigger
-- gesetzt, sobald unten die lagerplatz-Zeilen befüllt werden.
-- ---------------------------------------------------------
INSERT INTO artikel (bezeichnung, kategorie, min_bestand, max_bestand, ek_preis) VALUES
    ('Schraube M6x20',         'Kleinteile',   50, 1000,  0.05),  -- 1
    ('Kabelbinder 200mm',      'Kleinteile',   50, 1000,  0.02),  -- 2
    ('Verpackungskarton M',    'Verpackung',   50,  800,  0.60),  -- 3
    ('Verpackungskarton L',    'Verpackung',   50,  800,  0.80),  -- 4
    ('Aluminiumblech 2mm',     'Rohmaterial',  50,  800, 18.50),  -- 5
    ('Stahlblech 3mm',         'Rohmaterial',  50,  800, 22.00),  -- 6
    ('Elektromotor 24V',       'Elektronik',   50,  800, 42.30),  -- 7
    ('Sensor-Modul IR',        'Elektronik',   50,  800, 15.90),  -- 8
    ('Förderband-Rolle',       'Ersatzteile',  50,  800, 95.00),  -- 9
    ('Lagerrolle Kugellager',  'Ersatzteile',  50,  800, 28.50);  -- 10

-- ---------------------------------------------------------
-- LAGERPLATZ
-- Alle 60 Plätze anlegen: 2 Lager (a/b) x 3 Schichten (A/B/C) x 10 Plätze.
-- platz_id 1 = "aA1", platz_id 2 = "aA2", ... (Reihenfolge: a vor b,
-- A vor B vor C, 1 vor 10).
-- ---------------------------------------------------------
INSERT INTO lagerplatz (lager, schicht, nummer)
SELECT lager, schicht, nummer
FROM unnest(ARRAY['a', 'b']) AS lager
       CROSS JOIN unnest(ARRAY['A', 'B', 'C']) AS schicht
       CROSS JOIN generate_series(1, 10) AS nummer
ORDER BY lager, schicht, nummer;

-- Artikel 1 = Schraube M6x20: 320 Stück (aA1-3 @100 + aA4 @20)
UPDATE lagerplatz SET artikel_id = 1, bestand = 100 WHERE lager='a' AND schicht='A' AND nummer BETWEEN 1 AND 3;
UPDATE lagerplatz SET artikel_id = 1, bestand = 20  WHERE lager='a' AND schicht='A' AND nummer = 4;

-- Artikel 2 = Kabelbinder 200mm: 380 Stück (aA5-7 @100 + aA8 @80)
UPDATE lagerplatz SET artikel_id = 2, bestand = 100 WHERE lager='a' AND schicht='A' AND nummer BETWEEN 5 AND 7;
UPDATE lagerplatz SET artikel_id = 2, bestand = 80  WHERE lager='a' AND schicht='A' AND nummer = 8;
-- aA9, aA10 bleiben frei

-- Artikel 3 = Verpackungskarton M: 410 Stück (aB1-4 @100 + aB5 @10)
UPDATE lagerplatz SET artikel_id = 3, bestand = 100 WHERE lager='a' AND schicht='B' AND nummer BETWEEN 1 AND 4;
UPDATE lagerplatz SET artikel_id = 3, bestand = 10  WHERE lager='a' AND schicht='B' AND nummer = 5;

-- Artikel 4 = Verpackungskarton L: 450 Stück (aB6-9 @100 + aB10 @50)
UPDATE lagerplatz SET artikel_id = 4, bestand = 100 WHERE lager='a' AND schicht='B' AND nummer BETWEEN 6 AND 9;
UPDATE lagerplatz SET artikel_id = 4, bestand = 50  WHERE lager='a' AND schicht='B' AND nummer = 10;

-- Artikel 5 = Aluminiumblech 2mm: 470 Stück (aC1-4 @100 + aC5 @70)
UPDATE lagerplatz SET artikel_id = 5, bestand = 100 WHERE lager='a' AND schicht='C' AND nummer BETWEEN 1 AND 4;
UPDATE lagerplatz SET artikel_id = 5, bestand = 70  WHERE lager='a' AND schicht='C' AND nummer = 5;

-- Artikel 6 = Stahlblech 3mm: 500 Stück (bA1-5 @100)
UPDATE lagerplatz SET artikel_id = 6, bestand = 100 WHERE lager='b' AND schicht='A' AND nummer BETWEEN 1 AND 5;

-- Artikel 7 = Elektromotor 24V: 520 Stück (bA6-10 @100 + bB1 @20)
UPDATE lagerplatz SET artikel_id = 7, bestand = 100 WHERE lager='b' AND schicht='A' AND nummer BETWEEN 6 AND 10;
UPDATE lagerplatz SET artikel_id = 7, bestand = 20  WHERE lager='b' AND schicht='B' AND nummer = 1;

-- Artikel 8 = Sensor-Modul IR: 540 Stück (bB2-6 @100 + bB7 @40)
UPDATE lagerplatz SET artikel_id = 8, bestand = 100 WHERE lager='b' AND schicht='B' AND nummer BETWEEN 2 AND 6;
UPDATE lagerplatz SET artikel_id = 8, bestand = 40  WHERE lager='b' AND schicht='B' AND nummer = 7;
-- bB8, bB9, bB10 bleiben frei

-- Artikel 9 = Förderband-Rolle: 560 Stück (bC1-5 @100 + bC6 @60)
UPDATE lagerplatz SET artikel_id = 9, bestand = 100 WHERE lager='b' AND schicht='C' AND nummer BETWEEN 1 AND 5;
UPDATE lagerplatz SET artikel_id = 9, bestand = 60  WHERE lager='b' AND schicht='C' AND nummer = 6;

-- Artikel 10 = Lagerrolle Kugellager: 600 Stück (bC7-10 @100 + aC6-7 @100)
UPDATE lagerplatz SET artikel_id = 10, bestand = 100 WHERE lager='b' AND schicht='C' AND nummer BETWEEN 7 AND 10;
UPDATE lagerplatz SET artikel_id = 10, bestand = 100 WHERE lager='a' AND schicht='C' AND nummer BETWEEN 6 AND 7;
-- aC8, aC9, aC10 bleiben frei

-- ---------------------------------------------------------
-- BEWEGUNG
-- Je ein Beispiel pro Typ, jetzt mit den neuen Artikeln/Plätzen.
-- ---------------------------------------------------------
INSERT INTO bewegung (artikel_id, typ, menge, quelle_platz_id, ziel_platz_id, zeitstempel) VALUES
    (1, 'wareneingang',    50, NULL,
        (SELECT platz_id FROM lagerplatz WHERE bezeichnung = 'aA1'),
        now() - interval '5 days'),
    (7, 'warenausgang',     10,
        (SELECT platz_id FROM lagerplatz WHERE bezeichnung = 'bA6'), NULL,
        now() - interval '4 days'),
    (5, 'umlagerung',       20,
        (SELECT platz_id FROM lagerplatz WHERE bezeichnung = 'aC1'),
        (SELECT platz_id FROM lagerplatz WHERE bezeichnung = 'aA9'),
        now() - interval '3 days'),
    (9, 'kommissionierung', 50,
        (SELECT platz_id FROM lagerplatz WHERE bezeichnung = 'bC1'), NULL,
        now() - interval '1 days'),
    (3, 'inventur',         -5, NULL, NULL, now() - interval '12 hours'); -- Schwund: 5 Stück fehlen

-- ---------------------------------------------------------
-- AUFTRAG
-- Genau 1 Artikel pro Auftrag. menge_erfuellt = tatsächlich erfüllte Menge
-- (Service-Level-Demo: Auftrag 3 - 60 Kabelbinder bestellt, nur 50 erfüllt)
-- ---------------------------------------------------------
INSERT INTO auftrag (typ, status, artikel_id, menge, menge_erfuellt, erstellt_am, abgeschlossen_am) VALUES
    ('eingang', 'abgeschlossen',  1, 50, 50,   now() - interval '6 days', now() - interval '5 days'),
    ('ausgang', 'abgeschlossen',  7, 10, 10,   now() - interval '3 days', now() - interval '2 days'),
    ('ausgang', 'abgeschlossen',  2, 60, 50,   now() - interval '3 days', now() - interval '2 days'),
    ('ausgang', 'in_bearbeitung', 9, 3,  NULL, now() - interval '1 days', NULL),
    ('eingang', 'abgeschlossen',  3, 100, 100, now() - interval '8 days', now() - interval '7 days'),
    ('eingang', 'offen',          4, 50,  NULL, now() - interval '2 hours', NULL),
    ('ausgang', 'abgeschlossen',  5, 30,  30,  now() - interval '4 days', now() - interval '3 days'),
    ('ausgang', 'storniert',      6, 20,  0,   now() - interval '5 days', now() - interval '4 days'),
    ('eingang', 'in_bearbeitung', 8, 40,  NULL, now() - interval '6 hours', NULL),
    ('ausgang', 'offen',          10, 25, NULL, now() - interval '1 hours', NULL);
-- ---------------------------------------------------------
-- ROBOTER
-- ---------------------------------------------------------
INSERT INTO roboter (name, status) VALUES
    ('Kommissionierer-01', 'aktiv'),
    ('Kommissionierer-02', 'idle');

-- ---------------------------------------------------------
-- ROBOTER_POSITION
-- Mehrere Zeitpunkte je Roboter, simuliert Bewegung über die Zeit.
-- platz_id 1, 2, 5 entsprechen "aA1", "aA2", "aA5" (siehe oben).
-- ---------------------------------------------------------
INSERT INTO roboter_position (roboter_id, x, y, platz_id, zeitstempel) VALUES
    (1, 0.0,  0.0,  NULL, now() - interval '10 minutes'),
    (1, 5.2,  3.1,  NULL, now() - interval '8 minutes'),
    (1, 10.0, 3.1,  1,    now() - interval '6 minutes'),
    (1, 10.0, 6.5,  NULL, now() - interval '4 minutes'),
    (1, 12.3, 6.5,  2,    now() - interval '2 minutes'),
    (2, 1.0,  1.0,  NULL, now() - interval '15 minutes'),
    (2, 1.0,  4.0,  5,    now() - interval '5 minutes');
