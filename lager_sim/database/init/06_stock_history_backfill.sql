-- =========================================================
-- 06_stock_history_backfill.sql
-- Rekonstruiert die Historie aus den vorhandenen bewegung-Einträgen
-- (rückwärts verankert am aktuellen bestand_gesamt), damit der Chart
-- nicht nur einen, sondern viele Punkte über die letzten 30 Tage zeigt.
-- Einmalig ausführen!
-- =========================================================
WITH deltas AS (
    SELECT
        artikel_id,
        zeitstempel,
        CASE
            WHEN typ = 'wareneingang'      THEN menge
            WHEN typ = 'warenausgang'      THEN -menge
            WHEN typ = 'kommissionierung'  THEN -menge
            WHEN typ = 'inventur'          THEN menge
            ELSE 0
            END AS delta
    FROM bewegung
),
     cumsum AS (
         SELECT
             artikel_id,
             zeitstempel,
             SUM(delta) OVER (PARTITION BY artikel_id ORDER BY zeitstempel) AS laufsumme,
             SUM(delta) OVER (PARTITION BY artikel_id) AS gesamtsumme
         FROM deltas
     )
INSERT INTO stock_history (artikel_id, total_stock, recorded_at)
SELECT
    c.artikel_id,
    GREATEST(a.bestand_gesamt - c.gesamtsumme + c.laufsumme, 0) AS total_stock,
    c.zeitstempel
FROM cumsum c
         JOIN artikel a ON a.artikel_id = c.artikel_id
ORDER BY c.artikel_id, c.zeitstempel;