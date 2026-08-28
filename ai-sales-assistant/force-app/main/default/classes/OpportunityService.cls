/**
 * Read-side data access for opportunities, tasks and activities. Every entry point
 * runs in AccessLevel.USER_MODE so object/field-level security and sharing are always
 * respected, and queries are assembled dynamically from bind-safe fragments rather
 * than string concatenation.
 */
public with sharing class OpportunityService {

    private static final Set<String> ALLOWED_ORDER_FIELDS = new Set<String>{
        'CloseDate', 'Amount', 'Risk_Score__c', 'Name'
    };

    private static final String BASE_FIELDS =
        'Id, Name, Amount, StageName, CloseDate, Probability, IsClosed, IsWon, OwnerId, AccountId, ' +
        'Risk_Score__c, Risk_Level__c, AI_Summary__c, Next_Best_Action__c, Competitor_Insights__c, ' +
        'Revenue_Forecast__c, AI_Last_Analyzed__c, Account.Name, Owner.Name';

    public static AI_Config__mdt getConfig() {
        return AI_Config__mdt.getInstance('Default_Config');
    }

    public static List<Opportunity> getOpenOpportunities(Integer limitCount) {
        return queryOpportunities(
            new Map<String, Object>{ 'isClosed' => false },
            'CloseDate',
            true,
            limitCount
        );
    }

    public static List<Opportunity> getHighRiskOpportunities(Integer limitCount) {
        AI_Config__mdt config = getConfig();
        return queryOpportunities(
            new Map<String, Object>{ 'isClosed' => false, 'minRiskScore' => config.High_Risk_Threshold__c },
            'Risk_Score__c',
            false,
            limitCount
        );
    }

    public static Opportunity getOpportunityById(Id opportunityId) {
        List<Opportunity> results = queryOpportunities(
            new Map<String, Object>{ 'opportunityId' => opportunityId },
            null,
            true,
            1
        );
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Builds and runs a dynamic SOQL query against Opportunity from a small, whitelisted
     * set of filter keys, using bind variables (never string-concatenated values) and
     * Database.queryWithBinds in USER_MODE for CRUD/FLS/sharing enforcement.
     */
    public static List<Opportunity> queryOpportunities(
        Map<String, Object> filters,
        String orderByField,
        Boolean ascending,
        Integer limitCount
    ) {
        if (String.isNotBlank(orderByField) && !ALLOWED_ORDER_FIELDS.contains(orderByField)) {
            throw new IllegalArgumentException('Unsupported sort field: ' + orderByField);
        }

        List<String> whereClauses = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (filters.containsKey('opportunityId')) {
            whereClauses.add('Id = :opportunityId');
            binds.put('opportunityId', filters.get('opportunityId'));
        }
        if (filters.containsKey('isClosed')) {
            whereClauses.add('IsClosed = :isClosed');
            binds.put('isClosed', filters.get('isClosed'));
        }
        if (filters.containsKey('minRiskScore')) {
            whereClauses.add('Risk_Score__c >= :minRiskScore');
            binds.put('minRiskScore', filters.get('minRiskScore'));
        }
        if (filters.containsKey('ownerId')) {
            whereClauses.add('OwnerId = :ownerId');
            binds.put('ownerId', filters.get('ownerId'));
        }

        String query = 'SELECT ' + BASE_FIELDS + ' FROM Opportunity';
        if (!whereClauses.isEmpty()) {
            query += ' WHERE ' + String.join(whereClauses, ' AND ');
        }
        if (String.isNotBlank(orderByField)) {
            query += ' ORDER BY ' + orderByField + (ascending ? ' ASC' : ' DESC');
        }
        if (limitCount != null) {
            binds.put('limitCount', limitCount);
            query += ' LIMIT :limitCount';
        }

        return Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }

    public static List<Task> getUpcomingTasks(Integer daysAhead, Integer limitCount) {
        Date todayDate = Date.today();
        Date endDate = todayDate.addDays(daysAhead);
        String query =
            'SELECT Id, Subject, WhatId, What.Name, ActivityDate, Status, Priority, Owner.Name ' +
            'FROM Task ' +
            'WHERE ActivityDate >= :todayDate AND ActivityDate <= :endDate AND Status != :completedStatus ' +
            'ORDER BY ActivityDate ASC ' +
            'LIMIT :limitCount';
        Map<String, Object> binds = new Map<String, Object>{
            'todayDate' => todayDate,
            'endDate' => endDate,
            'completedStatus' => 'Completed',
            'limitCount' => limitCount
        };
        return Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }

    public static Integer countOpenOpportunitiesWithRecommendations() {
        String query = 'SELECT COUNT() FROM Opportunity WHERE IsClosed = false AND AI_Summary__c != null';
        return Database.countQueryWithBinds(query, new Map<String, Object>(), AccessLevel.USER_MODE);
    }

    public static List<ActivityWrapper> getRecentActivities(Id opportunityId, Integer limitCount) {
        List<ActivityWrapper> activities = new List<ActivityWrapper>();
        for (Task t : [
            SELECT Id, Subject, ActivityDate, Status, Description
            FROM Task
            WHERE WhatId = :opportunityId
            WITH USER_MODE
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT :limitCount
        ]) {
            activities.add(new ActivityWrapper(t));
        }
        for (Event e : [
            SELECT Id, Subject, ActivityDate, Description
            FROM Event
            WHERE WhatId = :opportunityId
            WITH USER_MODE
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT :limitCount
        ]) {
            activities.add(new ActivityWrapper(e));
        }
        activities.sort();
        if (limitCount != null && activities.size() > limitCount) {
            activities = new List<ActivityWrapper>(new List<ActivityWrapper>(activities).subList(0, limitCount));
        }
        return activities;
    }

    public static List<DealTimelineEntry> getDealTimeline(Opportunity opp, List<ActivityWrapper> activities) {
        List<DealTimelineEntry> timeline = new List<DealTimelineEntry>();
        timeline.add(new DealTimelineEntry(
            Datetime.newInstance(opp.CloseDate, Time.newInstance(0, 0, 0, 0)),
            'Expected Close',
            opp.StageName + ' • ' + (opp.Amount != null ? opp.Amount.format() : 'no amount'),
            'utility:event'
        ));
        for (ActivityWrapper activity : activities) {
            timeline.add(new DealTimelineEntry(
                activity.activityDate != null
                    ? Datetime.newInstance(activity.activityDate, Time.newInstance(0, 0, 0, 0))
                    : null,
                activity.subject,
                activity.activityType + (activity.status != null ? ' • ' + activity.status : ''),
                activity.activityType == 'Event' ? 'utility:date_time' : 'utility:task'
            ));
        }
        return timeline;
    }
}
