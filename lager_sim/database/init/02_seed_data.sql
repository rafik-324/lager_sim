-- =========================================================
-- 02_seed_data.sql
-- Testdaten für alle Tabellen der Lagersimulation
-- =========================================================

-- ---------------------------------------------------------
-- ARTIKEL
-- ---------------------------------------------------------
INSERT INTO artikel (bezeichnung, kategorie, min_bestand, max_bestand, ek_preis) VALUES
                                                                                     ('Schraube M6x20',        'Kleinteile',   100, 2000,  0.05),
                                                                                     ('Aluminiumblech 2mm',    'Rohmaterial',   20,  200, 18.50),
                                                                                     ('Verpackungskarton L',   'Verpackung',    50, 1000,  0.80),
                                                                                     ('Elektromotor 24V',      'Elektronik',     5,   80, 42.30),
                                                                                     ('Kabelbinder 200mm',     'Kleinteile',   200, 5000,  0.02),
                                                                                     ('Förderband-Rolle',      'Ersatzteile',    2,   30, 95.00);

-- ---------------------------------------------------------
-- LAGERPLATZ
-- ---------------------------------------------------------
INSERT INTO lagerplatz (zone, kapazitaet, status) VALUES
                                                      ('A1', 500, 'belegt'),
                                                      ('A2', 500, 'belegt'),
                                                      ('B1', 200, 'belegt'),
                                                      ('B2', 200, 'frei'),
                                                      ('C1', 50,  'belegt'),
                                                      ('C2', 50,  'gesperrt');

-- ---------------------------------------------------------
-- BESTAND
-- (artikel_id / platz_id beziehen sich auf die Reihenfolge oben:
--  1=Schraube, 2=Alublech, 3=Karton, 4=Motor, 5=Kabelbinder, 6=Förderband)
-- ---------------------------------------------------------
INSERT INTO bestand (artikel_id, platz_id, menge) VALUES
                                                      (1, 1, 1500),   -- Schrauben auf A1
                                                      (5, 2, 3200),   -- Kabelbinder auf A2
                                                      (2, 3, 80),     -- Alublech auf B1
                                                      (3, 1, 400),    -- Karton zusätzlich auf A1 (anderer Artikel, gleicher Platz erlaubt)
                                                      (4, 5, 22),     -- Motoren auf C1
                                                      (6, 5, 8);      -- Förderbandrollen auf C1

-- ---------------------------------------------------------
-- BEWEGUNG
-- Je ein Beispiel pro Typ
-- ---------------------------------------------------------
INSERT INTO bewegung (artikel_id, typ, menge, quelle_platz_id, ziel_platz_id, zeitstempel) VALUES
                                                                                               (1, 'wareneingang',    500, NULL, 1,    now() - interval '5 days'),
                                                                                               (4, 'warenausgang',     10, 5,    NULL, now() - interval '4 days'),
                                                                                               (2, 'umlagerung',       20, 3,    4,    now() - interval '3 days'),
                                                                                               (5, 'kommissionierung', 50, 2,    NULL, now() - interval '1 days'),
                                                                                               (3, 'inventur',         -8, NULL, NULL, now() - interval '12 hours'); -- Schwund: 8 Stück fehlen

-- ---------------------------------------------------------
-- AUFTRAG + AUFTRAG_POSITION
-- ---------------------------------------------------------
INSERT INTO auftrag (typ, status, erstellt_am, abgeschlossen_am) VALUES
                                                                     ('eingang', 'abgeschlossen', now() - interval '6 days', now() - interval '5 days'),
                                                                     ('ausgang', 'abgeschlossen', now() - interval '3 days', now() - interval '2 days'),
                                                                     ('ausgang', 'in_bearbeitung', now() - interval '1 days', NULL);

INSERT INTO auftrag_position (auftrag_id, artikel_id, menge, status) VALUES
                                                                         (1, 1, 500, 'versendet'),
                                                                         (2, 4, 10,  'versendet'),
                                                                         (2, 5, 60,  'fehlend'),      -- bestellt 60, aber nur 50 kommissioniert -> Service-Level-Test
                                                                         (3, 6, 3,   'offen');

-- ---------------------------------------------------------
-- ROBOTER
-- ---------------------------------------------------------
INSERT INTO roboter (name, status) VALUES
                                       ('Kommissionierer-01', 'aktiv'),
                                       ('Kommissionierer-02', 'idle');

-- ---------------------------------------------------------
-- ROBOTER_POSITION
-- Mehrere Zeitpunkte je Roboter, simuliert Bewegung über die Zeit
-- ---------------------------------------------------------
INSERT INTO roboter_position (roboter_id, x, y, platz_id, zeitstempel) VALUES
                                                                           (1, 0.0,  0.0,  NULL, now() - interval '10 minutes'),
                                                                           (1, 5.2,  3.1,  NULL, now() - interval '8 minutes'),
                                                                           (1, 10.0, 3.1,  1,    now() - interval '6 minutes'),
                                                                           (1, 10.0, 6.5,  NULL, now() - interval '4 minutes'),
                                                                           (1, 12.3, 6.5,  2,    now() - interval '2 minutes'),
                                                                           (2, 1.0,  1.0,  NULL, now() - interval '15 minutes'),
                                                                           (2, 1.0,  4.0,  5,    now() - interval '5 minutes');