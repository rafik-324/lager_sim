package scheduler;

import repositories.AuftragRepository;
import repositories.LagerplatzRepository;

import java.util.Scanner;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.Random;

public class UpdateScheduler {

    private final LagerplatzRepository lagerplatzRepository;
    private final AuftragRepository auftragRepository;
    private final ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor();
    private final Random random = new Random();

    private static final int MIN_INTERVALL_SEKUNDEN = 2;
    private static final int MAX_INTERVALL_SEKUNDEN = 7;

    // Steuert, ob der Scheduler im Normalbetrieb läuft oder ausschließlich
    // Restock-, Destock- bzw. Abarbeitungs-Aufträge sendet. Volatile, da von
    // außen (anderem Thread, z.B. der Konsoleneingabe) während des laufenden
    // Schedulers umgeschaltet wird.
    private volatile boolean restockModus = false;
    private volatile boolean destockModus = false;
    private volatile boolean sorderModus = false;

    public UpdateScheduler(LagerplatzRepository lagerplatzRepository, AuftragRepository auftragRepository) {
        this.lagerplatzRepository = lagerplatzRepository;
        this.auftragRepository = auftragRepository;
    }

    public void start() {
        System.out.println("UpdateScheduler gestartet.");
        scheduleNext();
    }

    private void scheduleNext() {
        int delay = MIN_INTERVALL_SEKUNDEN + random.nextInt(MAX_INTERVALL_SEKUNDEN - MIN_INTERVALL_SEKUNDEN + 1);
        executor.schedule(this::tick, delay, TimeUnit.SECONDS);
    }

    private void tick() {
        try {
            if (restockModus) {
                System.out.println("[Tick] Restock-Modus: zufälliger Eingangsauftrag wird erstellt...");
                auftragRepository.randRestock();
            } else if (destockModus) {
                System.out.println("[Tick] Destock-Modus: zufälliger Ausgangsauftrag wird erstellt...");
                auftragRepository.randDestock();
            } else if (sorderModus) {
                System.out.println("[Tick] Sorder-Modus: ältester offener Auftrag wird bearbeitet...");
                lagerplatzRepository.bearbeiteAeltestenOffenenAuftrag();
            } else if (random.nextInt(4) < 3) {
                System.out.println("[Tick] Neuer zufälliger Auftrag wird erstellt...");
                auftragRepository.randOrder();
            } else {
                System.out.println("[Tick] Ältester offener Auftrag wird bearbeitet...");
                lagerplatzRepository.bearbeiteAeltestenOffenenAuftrag();
            }
        } catch (Exception e) {
            System.out.println("Fehler im UpdateScheduler-Tick:");
            e.printStackTrace();
        } finally {
            scheduleNext();
        }
    }

    // --- Steuerung von außen während der Scheduler läuft ---

    public void aktiviereRestockModus() {
        restockModus = true;
        destockModus = false;
        sorderModus = false;
        System.out.println(">>> Restock-Modus aktiviert.");
    }

    public void deaktiviereRestockModus() {
        restockModus = false;
        System.out.println(">>> Restock-Modus deaktiviert.");
    }

    public void aktiviereDestockModus() {
        destockModus = true;
        restockModus = false;
        sorderModus = false;
        System.out.println(">>> Destock-Modus aktiviert.");
    }

    public void deaktiviereDestockModus() {
        destockModus = false;
        System.out.println(">>> Destock-Modus deaktiviert.");
    }

    public void aktiviereSorderModus() {
        sorderModus = true;
        restockModus = false;
        destockModus = false;
        System.out.println(">>> Sorder-Modus aktiviert (nur Abarbeitung).");
    }

    public void deaktiviereSorderModus() {
        sorderModus = false;
        System.out.println(">>> Sorder-Modus deaktiviert.");
    }

    public void stop() {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }

    public static void main(String[] args) {
        AuftragRepository auftragRepository = new AuftragRepository();
        LagerplatzRepository lagerplatzRepository = new LagerplatzRepository(auftragRepository);

        UpdateScheduler scheduler = new UpdateScheduler(lagerplatzRepository, auftragRepository);
        scheduler.start();

        System.out.println("Befehle: 'restock', 'destock', 'sorder', 'normal', 'exit'");

        Scanner scanner = new Scanner(System.in);
        while (true) {
            String input = scanner.nextLine().trim().toLowerCase();

            switch (input) {
                case "restock":
                    scheduler.aktiviereRestockModus();
                    break;
                case "destock":
                    scheduler.aktiviereDestockModus();
                    break;
                case "sorder":
                    scheduler.aktiviereSorderModus();
                    break;
                case "normal":
                    scheduler.deaktiviereRestockModus();
                    scheduler.deaktiviereDestockModus();
                    scheduler.deaktiviereSorderModus();
                    break;
                case "exit":
                    scheduler.stop();
                    System.out.println("Beendet.");
                    return;
                default:
                    System.out.println("Unbekannter Befehl. Verfügbar: restock, destock, sorder, normal, exit");
            }
        }
    }
}