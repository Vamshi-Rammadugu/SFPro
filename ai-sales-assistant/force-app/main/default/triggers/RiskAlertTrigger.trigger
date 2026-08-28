trigger RiskAlertTrigger on Risk_Alert__e (after insert) {
    NotificationService.handleRiskAlerts(Trigger.new);
}
