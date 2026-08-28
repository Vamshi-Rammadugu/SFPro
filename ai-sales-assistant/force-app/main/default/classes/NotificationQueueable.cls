/**
 * Async wrapper so risk alert notifications never block the platform event
 * trigger (or any other caller) that raised them.
 */
public with sharing class NotificationQueueable implements Queueable {

    private final List<Risk_Alert__e> alerts;

    public NotificationQueueable(List<Risk_Alert__e> alerts) {
        this.alerts = alerts;
    }

    public void execute(QueueableContext context) {
        NotificationService.notifyOwners(alerts);
    }
}
