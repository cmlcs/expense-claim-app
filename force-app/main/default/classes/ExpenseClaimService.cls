/**
 * Prepares Expense Claims for submission.
 *
 * This service performs validation, applies current Expense Type policy,
 * snapshots trusted claimant identity, and transitions a Draft claim to
 * Submitted. It performs no DML.
 */
public with sharing class ExpenseClaimService {

    private static final String STATUS_SUBMITTED =
        'Submitted';

    /**
     * Exception representing invalid Expense Claim submission data.
     */
    public class ExpenseClaimException extends Exception {
    }

    /**
     * Prepares an authenticated user's Expense Claim for submission.
     *
     * Claimant identity is always derived from UserInfo. Client-supplied
     * claimant identity is never trusted.
     *
     * @param claim Expense Claim being submitted.
     * @param items Expense Items associated with the claim.
     */
    public static void prepareForSubmission(
        Expense_Claim__c claim,
        List<Expense_Item__c> items
    ) {
        prepareSubmission(
            claim,
            items
        );

        snapshotAuthenticatedClaimant(
            claim
        );

        finalizeSubmission(
            claim
        );
    }

    /**
     * Prepares a verified guest claimant's Expense Claim for submission.
     *
     * Claimant identity is derived from a Contact that has already been
     * resolved and verified by trusted server-side guest access logic.
     *
     * @param claim Expense Claim being submitted.
     * @param items Expense Items associated with the claim.
     * @param claimantContact Verified claimant Contact.
     */
    public static void prepareForGuestSubmission(
        Expense_Claim__c claim,
        List<Expense_Item__c> items,
        Contact claimantContact
    ) {
        prepareSubmission(
            claim,
            items
        );

        snapshotGuestClaimant(
            claim,
            claimantContact
        );

        finalizeSubmission(
            claim
        );
    }

    /**
     * Performs submission validation and applies current policy.
     *
     * This shared preparation logic is independent of the claimant's
     * authentication mechanism.
     *
     * @param claim Expense Claim being submitted.
     * @param items Expense Items associated with the claim.
     */
    private static void prepareSubmission(
        Expense_Claim__c claim,
        List<Expense_Item__c> items
    ) {
        Expense_Settings__mdt settings =
            ExpensePolicyService.getSettings();

        ExpenseClaimValidator.validateDraft(
            claim,
            items
        );

        ExpenseClaimValidator.validateSettings(
            settings
        );

        for (Expense_Item__c item : items) {
            prepareItem(
                item,
                settings
            );
        }
    }

    /**
     * Applies current Expense Type policy and validates one Expense Item.
     *
     * @param item Expense Item being prepared.
     * @param settings Current Expense Claim settings.
     */
    private static void prepareItem(
        Expense_Item__c item,
        Expense_Settings__mdt settings
    ) {
        ExpenseClaimValidator.validateItemReference(
            item
        );

        ExpensePolicyService.applyPolicy(
            item,
            item.Expense_Type_Code__c
        );

        Expense_Type__mdt expenseType =
            Expense_Type__mdt.getInstance(
                item.Expense_Type_Code__c
            );

        ExpenseItemValidator.validatePreparedItem(
            item,
            expenseType,
            settings
        );
    }

    /**
     * Snapshots the authenticated Salesforce user's identity.
     *
     * Claimant_Contact__c is explicitly cleared so an authenticated
     * submission cannot retain a Contact identity supplied elsewhere.
     *
     * @param claim Expense Claim being submitted.
     */
    private static void snapshotAuthenticatedClaimant(
        Expense_Claim__c claim
    ) {
        claim.Claimant_User__c =
            UserInfo.getUserId();

        claim.Claimant_Contact__c =
            null;

        claim.Claimant_Name__c =
            UserInfo.getName();

        claim.Claimant_Email__c =
            UserInfo.getUserEmail();
    }

    /**
     * Snapshots the verified Contact identity for a guest submission.
     *
     * Claimant_User__c is explicitly cleared because the Experience Cloud
     * Guest User is not the claimant.
     *
     * @param claim Expense Claim being submitted.
     * @param claimantContact Verified claimant Contact.
     */
    private static void snapshotGuestClaimant(
        Expense_Claim__c claim,
        Contact claimantContact
    ) {
        validateGuestClaimant(
            claimantContact
        );

        claim.Claimant_User__c =
            null;

        claim.Claimant_Contact__c =
            claimantContact.Id;

        claim.Claimant_Name__c =
            claimantContact.Name;

        claim.Claimant_Email__c =
            claimantContact.Email;
    }

    /**
     * Validates the Contact used as the trusted guest claimant identity.
     *
     * @param claimantContact Verified claimant Contact.
     */
    private static void validateGuestClaimant(
        Contact claimantContact
    ) {
        if (
            claimantContact == null ||
            claimantContact.Id == null ||
            String.isBlank(
                claimantContact.Email
            )
        ) {
            throw new ExpenseClaimException(
                'A verified claimant Contact is required.'
            );
        }
    }

    /**
     * Completes the Draft-to-Submitted transition.
     *
     * @param claim Expense Claim being submitted.
     */
    private static void finalizeSubmission(
        Expense_Claim__c claim
    ) {
        claim.Submitted_At__c =
            System.now();

        claim.Status__c =
            STATUS_SUBMITTED;
    }
}