/**
 * Prepares Expense Claims for submission.
 *
 * This service applies current Expense Type policy, validates the complete
 * claim, snapshots claimant information, and performs the in-memory
 * Draft-to-Submitted lifecycle transition.
 *
 * This service performs no DML.
 */
public with sharing class ExpenseClaimService {

    private static final String STATUS_SUBMITTED = 'Submitted';

    /**
     * Exception raised when claim data or lifecycle state is invalid.
     */
    public class ExpenseClaimException extends Exception {
    }

    /**
     * Prepares a Draft Expense Claim and its items for submission.
     *
     * The supplied claim and items are modified in memory. No DML is performed.
     *
     * @param claim Draft Expense Claim.
     * @param items Expense Items belonging to the claim.
     */
    public static void prepareForSubmission(
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

        snapshotClaimant(claim);

        claim.Submitted_At__c =
            System.now();

        claim.Status__c =
            STATUS_SUBMITTED;
    }

    /**
     * Applies current policy and validates an Expense Item.
     *
     * @param item Expense Item being prepared.
     * @param settings Global Expense Claim settings.
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
     * Snapshots the authenticated claimant onto the claim.
     *
     * @param claim Expense Claim being submitted.
     */
    private static void snapshotClaimant(
        Expense_Claim__c claim
    ) {
        claim.Claimant_User__c =
            UserInfo.getUserId();

        claim.Claimant_Name__c =
            UserInfo.getName();

        claim.Claimant_Email__c =
            UserInfo.getUserEmail();
    }
}