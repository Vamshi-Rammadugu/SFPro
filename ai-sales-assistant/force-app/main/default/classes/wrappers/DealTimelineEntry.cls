/**
 * A single point on an opportunity's deal timeline (stage changes and activities, merged).
 */
public with sharing class DealTimelineEntry {
    @AuraEnabled public Datetime entryDate;
    @AuraEnabled public String label;
    @AuraEnabled public String detail;
    @AuraEnabled public String iconName;

    public DealTimelineEntry(Datetime entryDate, String label, String detail, String iconName) {
        this.entryDate = entryDate;
        this.label = label;
        this.detail = detail;
        this.iconName = iconName;
    }
}
