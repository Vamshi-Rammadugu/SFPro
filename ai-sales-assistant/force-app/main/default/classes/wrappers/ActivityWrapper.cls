/**
 * Normalized Task/Event row for the recentActivities LWC's deal timeline.
 */
public with sharing class ActivityWrapper implements Comparable {
    @AuraEnabled public Id recordId;
    @AuraEnabled public String activityType;
    @AuraEnabled public String subject;
    @AuraEnabled public Date activityDate;
    @AuraEnabled public String status;
    @AuraEnabled public String description;

    public ActivityWrapper(Task t) {
        this.recordId = t.Id;
        this.activityType = 'Task';
        this.subject = t.Subject;
        this.activityDate = t.ActivityDate;
        this.status = t.Status;
        this.description = t.Description;
    }

    public ActivityWrapper(Event e) {
        this.recordId = e.Id;
        this.activityType = 'Event';
        this.subject = e.Subject;
        this.activityDate = e.ActivityDate;
        this.status = 'Completed';
        this.description = e.Description;
    }

    public Integer compareTo(Object compareTo) {
        ActivityWrapper other = (ActivityWrapper) compareTo;
        if (this.activityDate == other.activityDate) {
            return 0;
        }
        if (this.activityDate == null) {
            return 1;
        }
        if (other.activityDate == null) {
            return -1;
        }
        return this.activityDate < other.activityDate ? 1 : -1;
    }
}
