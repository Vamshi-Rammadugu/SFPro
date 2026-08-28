/**
 * Flat view of a Task for the "Upcoming Tasks" dashboard tile.
 */
public with sharing class TaskWrapper {
    @AuraEnabled public Id taskId;
    @AuraEnabled public String subject;
    @AuraEnabled public Id whatId;
    @AuraEnabled public String relatedTo;
    @AuraEnabled public Date activityDate;
    @AuraEnabled public String status;
    @AuraEnabled public String priority;
    @AuraEnabled public String ownerName;

    public TaskWrapper(Task t) {
        this.taskId = t.Id;
        this.subject = t.Subject;
        this.whatId = t.WhatId;
        this.relatedTo = t.What != null ? t.What.Name : null;
        this.activityDate = t.ActivityDate;
        this.status = t.Status;
        this.priority = t.Priority;
        this.ownerName = t.Owner != null ? t.Owner.Name : null;
    }

    public static List<TaskWrapper> wrapAll(List<Task> tasks) {
        List<TaskWrapper> wrapped = new List<TaskWrapper>();
        for (Task t : tasks) {
            wrapped.add(new TaskWrapper(t));
        }
        return wrapped;
    }
}
