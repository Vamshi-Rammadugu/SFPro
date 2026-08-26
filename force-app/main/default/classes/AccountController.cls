public with sharing class AccountController {
    @AuraEnabled(cacheable=true)
    public static List<Account> getOwnedAccounts(Integer limitCount) {
        return [
            SELECT Id, Name, Industry, Phone, OwnerId
            FROM Account
            WHERE OwnerId = :UserInfo.getUserId()
            LIMIT :limitCount
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getRecentlyViewedAccounts() {
        Set<Id> recentIds = new Set<Id>();
        for (RecentlyViewed rv : [
            SELECT Id FROM RecentlyViewed
            WHERE Type = 'Account'
            ORDER BY LastViewedDate DESC
            LIMIT 10
        ]) {
            recentIds.add(rv.Id);
        }
        if (recentIds.isEmpty()) return new List<Account>();
        return [
            SELECT Id, Name, Industry, Phone, LastViewedDate
            FROM Account
            WHERE Id IN :recentIds
            ORDER BY LastViewedDate DESC
        ];
    }
}