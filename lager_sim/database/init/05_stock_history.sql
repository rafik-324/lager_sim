-- =========================================================
-- 05_stock_history.sql
-- Historisierung des Gesamtbestands pro Artikel über die Zeit.
-- Wird automatisch über den bestehenden Trigger befüllt -
-- IMMER wenn sich lagerplatz.bestand ändert (Insert/Update/Delete),
-- entsteht ein neuer Snapshot in stock_history.
-- =========================================================

CREATE TABLE stock_history (
                               history_id      SERIAL PRIMARY KEY,
                               artikel_id      INTEGER NOT NULL REFERENCES artikel(artikel_id),
                               total_stock     INTEGER NOT NULL CHECK (total_stock >= 0),
                               recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_history_artikel_zeit ON stock_history (artikel_id, recorded_at);

-- ---------------------------------------------------------
-- Bestehenden Trigger-Funktion erweitern:
-- Zusätzlich zum Update von artikel.bestand_gesamt wird jetzt
-- bei jeder Änderung auch ein Snapshot in stock_history geschrieben.
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_artikel_bestand_sync()
RETURNS TRIGGER AS $$
DECLARE
neuer_bestand INTEGER;
BEGIN
    IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND OLD.artikel_id IS NOT NULL THEN
SELECT COALESCE(SUM(bestand), 0) INTO neuer_bestand
FROM lagerplatz WHERE artikel_id = OLD.artikel_id;

UPDATE artikel SET bestand_gesamt = neuer_bestand WHERE artikel_id = OLD.artikel_id;
INSERT INTO stock_history (artikel_id, total_stock) VALUES (OLD.artikel_id, neuer_bestand);
END IF;

    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.artikel_id IS NOT NULL THEN
SELECT COALESCE(SUM(bestand), 0) INTO neuer_bestand
FROM lagerplatz WHERE artikel_id = NEW.artikel_id;

UPDATE artikel SET bestand_gesamt = neuer_bestand WHERE artikel_id = NEW.artikel_id;
INSERT INTO stock_history (artikel_id, total_stock) VALUES (NEW.artikel_id, neuer_bestand);
END IF;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
-- Trigger trg_artikel_bestand_sync existiert schon und nutzt diese Funktion -
-- muss NICHT neu angelegt werden, CREATE OR REPLACE reicht.

-- ---------------------------------------------------------
-- Backfill: aktuellen Stand als ersten historischen Datenpunkt einfügen.
-- ---------------------------------------------------------
INSERT INTO stock_history (artikel_id, total_stock, recorded_at)
SELECT artikel_id, bestand_gesamt, now()
FROM artikel;