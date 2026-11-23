/**
 * Provides privileged persistence operations for guest Expense Claim access.
 *
 * This repository is internal application infrastructure. Guest users receive
 * no direct CRUD/FLS access to Expense_Claim_Access__c or Contact.
 */
public without sharing class ExpenseClaimGuestAccessRepository {

    private static final String STATUS_PENDING =
        'Pending';

    private static final String STATUS_LOCKED =
        'Locked';

    private static final String STATUS_VERIFIED =
        'Verified';

    /**
     * Finds Contacts matching a normalized email address.
     *
     * At most two records are returned so duplicate email addresses can be
     * detected without unnecessarily retrieving additional Contact data.
     *
     * @param normalizedEmail Normalized claimant email.
     * @return Matching Contacts.
     */
    public static List<Contact> findContacts(
        String normalizedEmail
    ) {
        return [
            SELECT
                Id,
                Name,
                Email
            FROM Contact
            WHERE Email = :normalizedEmail
            WITH SYSTEM_MODE
            LIMIT 2
        ];
    }

    /**
     * Finds the most recent access record that can govern another
     * verification request.
     *
     * @param emailHash Hash of the normalized email.
     * @return Most recent Pending or Locked access record, or null.
     */
    public static Expense_Claim_Access__c findReusableAccess(
        String emailHash
    ) {
        Set<String> reusableStatuses =
            new Set<String>{
                STATUS_PENDING,
                STATUS_LOCKED
            };

        List<Expense_Claim_Access__c> accessRecords = [
            SELECT
                Id,
                Contact__c,
                Email_Hash__c,
                Status__c,
                Verification_Attempts__c,
                Last_Code_Sent_At__c,
                Code_Send_Count__c
            FROM Expense_Claim_Access__c
            WHERE
                Email_Hash__c = :emailHash
                AND Status__c IN :reusableStatuses
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return firstOrNull(
            accessRecords
        );
    }

    /**
     * Finds a currently usable pending verification request.
     *
     * @param emailHash Hash of the normalized email.
     * @param maximumAttempts Maximum permitted verification attempts.
     * @return Valid pending access record, or null.
     */
    public static Expense_Claim_Access__c findPendingAccess(
        String emailHash,
        Integer maximumAttempts
    ) {
        Datetime nowValue =
            System.now();

        List<Expense_Claim_Access__c> accessRecords = [
            SELECT
                Id,
                Contact__c,
                Email_Hash__c,
                Verification_Code_Hash__c,
                Verification_Salt__c,
                Verification_Expires_At__c,
                Verification_Attempts__c,
                Last_Code_Sent_At__c,
                Code_Send_Count__c,
                Status__c
            FROM Expense_Claim_Access__c
            WHERE
                Email_Hash__c = :emailHash
                AND Status__c = :STATUS_PENDING
                AND Contact__c != null
                AND Verification_Code_Hash__c != null
                AND Verification_Salt__c != null
                AND Verification_Expires_At__c > :nowValue
                AND Verification_Attempts__c < :maximumAttempts
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return firstOrNull(
            accessRecords
        );
    }

    /**
     * Finds a valid verified access record by token hash.
     *
     * @param tokenHash Hash of the browser-held access token.
     * @return Valid verified access record, or null.
     */
    public static Expense_Claim_Access__c findVerifiedAccess(
        String tokenHash
    ) {
        Datetime nowValue =
            System.now();

        List<Expense_Claim_Access__c> accessRecords = [
            SELECT
                Id,
                Contact__c,
                Contact__r.Name,
                Contact__r.Email,
                Status__c,
                Access_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE
                Access_Token_Hash__c = :tokenHash
                AND Status__c = :STATUS_VERIFIED
                AND Contact__c != null
                AND Contact__r.Email != null
                AND Access_Expires_At__c > :nowValue
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return firstOrNull(
            accessRecords
        );
    }

    /**
     * Finds a valid verified access record by ID.
     *
     * @param accessId Expense Claim Access record ID.
     * @return Valid verified access record, or null.
     */
    public static Expense_Claim_Access__c findVerifiedAccessById(
        Id accessId
    ) {
        Datetime nowValue =
            System.now();

        List<Expense_Claim_Access__c> accessRecords = [
            SELECT
                Id,
                Status__c,
                Access_Token_Hash__c,
                Access_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE
                Id = :accessId
                AND Status__c = :STATUS_VERIFIED
                AND Access_Expires_At__c > :nowValue
            WITH SYSTEM_MODE
            LIMIT 1
            FOR UPDATE
        ];

        return firstOrNull(
            accessRecords
        );
    }

    /**
     * Persists guest access state in system mode.
     *
     * @param accessRecord Access record to insert or update.
     */
    public static void save(
        Expense_Claim_Access__c accessRecord
    ) {
        if (accessRecord.Id == null) {
            Database.insert(
                accessRecord,
                AccessLevel.SYSTEM_MODE
            );

            return;
        }

        Database.update(
            accessRecord,
            AccessLevel.SYSTEM_MODE
        );
    }

    /**
     * Returns the first access record in a query result.
     *
     * @param accessRecords Query result.
     * @return First record, or null when no records were returned.
     */
    private static Expense_Claim_Access__c firstOrNull(
        List<Expense_Claim_Access__c> accessRecords
    ) {
        if (accessRecords.isEmpty()) {
            return null;
        }

        return accessRecords[0];
    }
}