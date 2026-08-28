import { LightningElement, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';

/**
 * Compact opportunity summary. Publishing on the OpportunitySelected message
 * channel (rather than a plain CustomEvent) lets the detail panels react
 * even when they are not a parent/child of whatever renders this card.
 */
export default class OpportunityCard extends LightningElement {
    @api opportunity;

    @wire(MessageContext)
    messageContext;

    get riskBadgeClass() {
        const level = this.opportunity && this.opportunity.riskLevel;
        if (level === 'High') {
            return 'slds-badge slds-theme_error';
        }
        if (level === 'Medium') {
            return 'slds-badge slds-theme_warning';
        }
        if (level === 'Low') {
            return 'slds-badge slds-theme_success';
        }
        return 'slds-badge';
    }

    get riskLabel() {
        return (this.opportunity && this.opportunity.riskLevel) || 'Not scored';
    }

    handleSelect() {
        if (!this.opportunity) {
            return;
        }
        publish(this.messageContext, OPPORTUNITY_SELECTED_CHANNEL, {
            recordId: this.opportunity.opportunityId
        });
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.handleSelect();
        }
    }
}
