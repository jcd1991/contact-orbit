import { LightningElement, api, wire } from 'lwc';
import getEmails from '@salesforce/apex/CEI_ContactEmailController.getEmails';
import getPurposeOptions from '@salesforce/apex/CEI_ContactEmailController.getPurposeOptions';
import createEmail from '@salesforce/apex/CEI_ContactEmailController.createEmail';
import deactivateEmail from '@salesforce/apex/CEI_ContactEmailController.deactivateEmail';
import verifyEmail from '@salesforce/apex/CEI_ContactEmailAttestation.verifyEmail';
import revokeEmail from '@salesforce/apex/CEI_ContactEmailAttestation.revokeEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';

const ROW_ACTIONS = [
    { label: 'Verify', name: 'verify' },
    { label: 'Revoke verification', name: 'revoke' },
    { label: 'Deactivate', name: 'deactivate' }
];
const COLUMNS = [
    { label: 'Email', fieldName: 'Email_Address__c', type: 'email', editable: true },
    { label: 'Purpose', fieldName: 'Purpose_Key__c', type: 'text', editable: true },
    { label: 'Primary', fieldName: 'Is_Primary__c', type: 'boolean', editable: true },
    { label: 'Active', fieldName: 'Active__c', type: 'boolean', editable: true },
    { label: 'Verification', fieldName: 'Verification_Status__c', type: 'text' },
    { label: 'Verified at', fieldName: 'Verified_At__c', type: 'date' },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class ContactEmailManager extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows = [];
    draftValues = [];
    purposeOptions = [];
    showForm = false;
    isLoading = false;
    pendingAction;
    wiredResult;
    draft = this.newDraft();

    @wire(getEmails, { contactId: '$recordId' })
    wiredEmails(result) {
        this.wiredResult = result;
        if (result.data) this.rows = result.data;
        if (result.error) this.toast('Unable to load contact emails', this.errorMessage(result.error), 'error');
    }

    @wire(getPurposeOptions)
    wiredPurposes({ data, error }) {
        if (data) this.purposeOptions = data.map((option) => ({ label: option.label, value: option.value }));
        if (error) this.toast('Unable to load purposes', this.errorMessage(error), 'error');
    }

    get hasRows() { return this.rows.length > 0; }
    get hasPendingAction() { return !!this.pendingAction; }
    get confirmationLabel() { return this.pendingAction?.action === 'deactivate' ? 'Deactivate identity' : 'Continue'; }

    newDraft() { return { emailAddress: '', purposeKey: 'General', isPrimary: false }; }
    showCreateForm() { this.draft = this.newDraft(); this.showForm = true; }
    hideCreateForm() { this.showForm = false; }

    handleInput(event) {
        const value = event.target.type === 'checkbox' ? event.target.checked : (event.detail?.value ?? event.target.value);
        this.draft = { ...this.draft, [event.target.name]: value };
    }

    async createEmail() {
        if (!this.draft.emailAddress || !this.draft.purposeKey) return;
        this.isLoading = true;
        try {
            await createEmail({ contactId: this.recordId, emailAddress: this.draft.emailAddress, purposeKey: this.draft.purposeKey, isPrimary: this.draft.isPrimary });
            this.showForm = false;
            this.toast('Email added', 'The identity is unverified until an authorized verifier attests it.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) { this.toast('Unable to add email', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    async handleSave(event) {
        this.isLoading = true;
        try {
            await Promise.all(event.detail.draftValues.map((fields) => updateRecord({ fields })));
            this.draftValues = [];
            this.toast('Changes saved', 'Contact email identities were updated.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) { this.toast('Unable to save changes', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    handleRowAction(event) { this.pendingAction = { action: event.detail.action.name, row: event.detail.row }; }
    cancelAction() { this.pendingAction = null; }

    async confirmAction() {
        const action = this.pendingAction;
        if (!action) return;
        this.pendingAction = null;
        this.isLoading = true;
        try {
            if (action.action === 'verify') await verifyEmail({ contactEmailId: action.row.Id });
            if (action.action === 'revoke') await revokeEmail({ contactEmailId: action.row.Id });
            if (action.action === 'deactivate') await deactivateEmail({ contactEmailId: action.row.Id });
            this.toast('Identity updated', 'The change was recorded and the list was refreshed.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) { this.toast('Unable to update identity', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    errorMessage(error) { return error?.body?.message || error?.message || 'Unexpected error'; }
}
