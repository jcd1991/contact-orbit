import ContactEmailManager from 'c/contactEmailManager';

describe('c-contact-email-manager', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    });

    it('starts with a safe General purpose draft', () => {
        expect(ContactEmailManager.prototype.newDraft()).toEqual({ emailAddress: '', purposeKey: 'General', isPrimary: false });
    });

    it('normalizes nested Apex errors for accessible feedback', () => {
        expect(ContactEmailManager.prototype.errorMessage({ body: { message: 'Permission denied' } })).toBe('Permission denied');
    });
});
