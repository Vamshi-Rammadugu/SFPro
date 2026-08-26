public with sharing class IPLMatchController {

    @AuraEnabled(cacheable=true)
    public static List<IPL_Match__c> getMatches(String statusFilter, String teamFilter) {
        String query = 'SELECT Id, Name, Match_Number__c, Match_Date__c, Match_Type__c, Match_Status__c, ' +
                       'Team1__c, Team2__c, Team1_Score__c, Team2_Score__c, ' +
                       'Winner__c, Win_Margin__c, Venue__c, ' +
                       'Toss_Winner__c, Toss_Decision__c, ' +
                       'Man_of_the_Match__c, Top_Scorer__c, Top_Wicket_Taker__c ' +
                       'FROM IPL_Match__c';

        List<String> conditions = new List<String>();
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            conditions.add('Match_Status__c = :statusFilter');
        }
        if (String.isNotBlank(teamFilter) && teamFilter != 'All') {
            conditions.add('(Team1__c = :teamFilter OR Team2__c = :teamFilter)');
        }
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' ORDER BY Match_Number__c ASC';

        return Database.query(query);
    }

    @AuraEnabled
    public static IPL_Match__c saveMatch(IPL_Match__c match) {
        upsert match;
        return match;
    }

    @AuraEnabled
    public static void deleteMatch(Id matchId) {
        delete new IPL_Match__c(Id = matchId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPointsTable() {
        List<IPL_Match__c> completedMatches = [
            SELECT Team1__c, Team2__c, Winner__c
            FROM IPL_Match__c
            WHERE Match_Status__c = 'Completed' AND Match_Type__c = 'League Stage'
        ];

        Map<String, Map<String, Integer>> table = new Map<String, Map<String, Integer>>();
        List<String> teams = new List<String>{
            'Chennai Super Kings', 'Delhi Capitals', 'Gujarat Titans',
            'Kolkata Knight Riders', 'Lucknow Super Giants', 'Mumbai Indians',
            'Punjab Kings', 'Rajasthan Royals', 'Royal Challengers Bengaluru',
            'Sunrisers Hyderabad'
        };
        for (String t : teams) {
            table.put(t, new Map<String, Integer>{'played' => 0, 'won' => 0, 'lost' => 0, 'points' => 0});
        }

        for (IPL_Match__c m : completedMatches) {
            if (table.containsKey(m.Team1__c)) {
                table.get(m.Team1__c).put('played', table.get(m.Team1__c).get('played') + 1);
            }
            if (table.containsKey(m.Team2__c)) {
                table.get(m.Team2__c).put('played', table.get(m.Team2__c).get('played') + 1);
            }
            if (String.isNotBlank(m.Winner__c) && m.Winner__c != 'No Result' && table.containsKey(m.Winner__c)) {
                table.get(m.Winner__c).put('won', table.get(m.Winner__c).get('won') + 1);
                table.get(m.Winner__c).put('points', table.get(m.Winner__c).get('points') + 2);
                String loser = (m.Winner__c == m.Team1__c) ? m.Team2__c : m.Team1__c;
                if (table.containsKey(loser)) {
                    table.get(loser).put('lost', table.get(loser).get('lost') + 1);
                }
            }
        }

        return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(table));
    }
}