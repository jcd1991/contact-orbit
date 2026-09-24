import { LightningElement, api, wire } from 'lwc';
import getMatches from '@salesforce/apex/CEI_ContactEmailRoutingController.getMatches';
import confirmMatch from '@salesforce/apex/CEI_ContactEmailRoutingController.confirmMatch';
import rejectMatch from '@salesforce/apex/CEI_ContactEmailRoutingController.rejectMatch';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ContactEmailMatchManager extends LightningElement {
    @api recordId;
    matches = [];
    isLoading = false;
    pending;
    wiredResult;

    @wire(getMatches, { caseId: '$recordId' })
    wiredMatches(result) {
        this.wiredResult = result;
        if (result.data) this.matches = result.data;
        if (result.error) this.toast('Unable to load suggestions', this.errorMessage(result.error), 'error');
    }

    get hasMatches() { return this.matches.length > 0; }
    get hasPending() { return !!this.pending; }
    askConfirm(event) { this.ask('confirm', this.matches.find((row) => row.Id === event.currentTarget.dataset.id)); }
    askReject(event) { this.ask('reject', this.matches.find((row) => row.Id === event.currentTarget.dataset.id)); }
    ask(action, row) { this.pending = { action, row }; }
    cancel() { this.pending = null; }

    async complete() {
        if (!this.pending) return;
        const action = this.pending;
        this.pending = null;
        this.isLoading = true;
        try {
            if (action.action === 'confirm') await confirmMatch({ matchId: action.row.Id });
            else await rejectMatch({ matchId: action.row.Id });
            this.toast('Suggestion updated', 'The Case and audit record were refreshed.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) { this.toast('Unable to update suggestion', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    errorMessage(error) { return error?.body?.message || error?.message || 'Unexpected error'; }
}
