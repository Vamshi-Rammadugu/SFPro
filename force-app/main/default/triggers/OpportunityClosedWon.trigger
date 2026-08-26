trigger OpportunityClosedWon on Opportunity (after update) {
    if(Trigger.IsAfter && Trigger.IsUpdate){
        List<Opportunity> opps = new List<Opportunity>();
            for(Opportunity opportunityOrder : Trigger.New){
                Opportunity oldopp= Trigger.oldMap.get(opportunityOrder.Id);
                if (opportunityOrder.StageName=='Closed Won' && oldopp.StageName!='Closed Won'){
                    opps.add(opportunityOrder);
                }                
            }
        if(!opps.IsEmpty()){
			System.debug(opps);
        }          
    }
}