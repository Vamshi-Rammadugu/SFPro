public with sharing class PlatformEventController {
    @AuraEnabled(cacheable=true)
    public static List<PlatformEventInfo> getActivePlatformEvents() {
        List<PlatformEventInfo> events = new List<PlatformEventInfo>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (String name : gd.keySet()) {
            if (name.endsWith('__e')) {
                Schema.DescribeSObjectResult d = gd.get(name).getDescribe();
                events.add(new PlatformEventInfo(
                    d.getName(),
                    d.getLabel(),
                    d.fields.getMap().size()
                ));
            }
        }
        events.sort();
        return events;
    }

    public class PlatformEventInfo implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Integer fieldCount;

        public PlatformEventInfo(String apiName, String label, Integer fieldCount) {
            this.apiName = apiName;
            this.label = label;
            this.fieldCount = fieldCount;
        }

        public Integer compareTo(Object other) {
            return this.label.compareTo(((PlatformEventInfo) other).label);
        }
    }
}