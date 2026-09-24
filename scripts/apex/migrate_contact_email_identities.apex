/*
 * Contact Orbit pre-managed migration.
 *
 * Run in a disposable copy first. The first pass aborts on duplicate active
 * primaries; it never chooses a winner. Output contains counts and record IDs
 * only. It never logs Email_Address__c or any normalized sender value.
 */
List<Contact_Email__c> identities = [
    SELECT Id, Contact__c, Purpose__c, Purpose_Key__c, Is_Primary__c, Active__c
    FROM Contact_Email__c
    WHERE Contact__c != null
];

Map<String, List<Id>> primaryIdsByScope = new Map<String, List<Id>>();
for (Contact_Email__c identity : identities) {
    String purposeKey = String.isBlank(identity.Purpose_Key__c) ? identity.Purpose__c : identity.Purpose_Key__c;
    if (identity.Active__c == true && identity.Is_Primary__c == true && !String.isBlank(purposeKey)) {
        String scope = String.valueOf(identity.Contact__c) + '|' + purposeKey;
        if (!primaryIdsByScope.containsKey(scope)) primaryIdsByScope.put(scope, new List<Id>());
        primaryIdsByScope.get(scope).add(identity.Id);
    }
}

List<String> conflictScopes = new List<String>();
List<Id> conflictIds = new List<Id>();
for (String scope : primaryIdsByScope.keySet()) {
    if (primaryIdsByScope.get(scope).size() > 1) {
        conflictScopes.add(scope);
        conflictIds.addAll(primaryIdsByScope.get(scope));
    }
}
if (!conflictScopes.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'CONTACT_ORBIT_MIGRATION_ABORTED duplicatePrimaryScopes=' + conflictScopes.size() + ' identityIds=' + conflictIds);
    throw new ContactOrbitMigrationException('Resolve duplicate active primary scopes before migration.');
}

for (Contact_Email__c identity : identities) {
    String purposeKey = String.isBlank(identity.Purpose_Key__c) ? identity.Purpose__c : identity.Purpose_Key__c;
    identity.Purpose_Key__c = purposeKey;
    identity.Primary_Scope_Key__c = identity.Active__c == true && identity.Is_Primary__c == true && !String.isBlank(purposeKey)
        ? String.valueOf(identity.Contact__c) + '|' + purposeKey : null;
    identity.Verification_Status__c = 'Unverified';
    identity.Verified_At__c = null;
    identity.Verified_By__c = null;
    identity.Verification_Method__c = null;
}
Database.update(identities, false);
System.debug(LoggingLevel.INFO, 'CONTACT_ORBIT_MIGRATION_COMPLETED identityCount=' + identities.size() + ' conflictCount=0');

public class ContactOrbitMigrationException extends Exception {}
