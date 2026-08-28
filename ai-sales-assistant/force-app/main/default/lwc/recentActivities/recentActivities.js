import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';
import getDealTimeline from '@salesforce/apex/OpportunityDashboardController.getDealTimeline';

/**
 * Renders the deal timeline: the opportunity's expected close entry plus
 * its recent Tasks and Events, newest first.
 */
export default class RecentActivities extends LightningElement {
    @api recordId;

    timeline;
    errorMessage;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getDealTimeline, { opportunityId: '$recordId' })
    wiredTimeline({ data, error }) {
        if (data !== undefined) {
            this.timeline = data.map((entry, index) => ({ ...entry, key: index }));
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    connectedCallback() {
        this.subscription = subscribe(this.messageContext, OPPORTUNITY_SELECTED_CHANNEL, (message) => {
            this.recordId = message.recordId;
        });
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    get hasTimeline() {
        return this.timeline && this.timeline.length > 0;
    }

    get placeholderText() {
        return this.recordId ? 'No recent activity found.' : 'Select an opportunity to see its deal timeline.';
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return (error.body && error.body.message) || 'Unable to load recent activity.';
    }
}
