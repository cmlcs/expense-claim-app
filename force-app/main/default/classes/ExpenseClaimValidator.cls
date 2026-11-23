/**
 * Validates Expense Claim lifecycle and submission-level data.
 */
public inherited sharing class ExpenseClaimValidator {

    private static final String STATUS_DRAFT = 'Draft';

    /**
     * Validates claim-level requirements for submission.
     *
     * @param claim Expense Claim being submitted.
     * @param items Expense Items associated with the claim.
     */
    public static void validateDraft(
        Expense_Claim__c claim,
        List<Expense_Item__c> items
    ) {
        requireClaim(claim);
        validateDraftStatus(claim);
        validateItemsPresent(items);
    }

    /**
     * Validates application-wide settings used during claim submission.
     *
     * @param settings Expense Claim settings.
     */
    public static void validateSettings(
        Expense_Settings__mdt settings
    ) {
        if (settings == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Expense Claim settings configuration is missing.'
            );
        }

        if (
            settings.Maximum_Expense_Age_Days__c != null &&
            settings.Maximum_Expense_Age_Days__c < 0
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Maximum Expense Age Days cannot be negative.'
            );
        }
    }

    /**
     * Validates information required to resolve Expense Type policy.
     *
     * @param item Expense Item being prepared.
     */
    public static void validateItemReference(
        Expense_Item__c item
    ) {
        if (item == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'An Expense Item must be provided.'
            );
        }

        if (String.isBlank(item.Expense_Type_Code__c)) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'An Expense Type must be selected.'
            );
        }
    }

    /**
     * Ensures an Expense Claim was supplied.
     *
     * @param claim Expense Claim supplied by the caller.
     */
    private static void requireClaim(
        Expense_Claim__c claim
    ) {
        if (claim == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'An Expense Claim must be provided.'
            );
        }
    }

    /**
     * Ensures only Draft claims can be submitted.
     *
     * @param claim Expense Claim being submitted.
     */
    private static void validateDraftStatus(
        Expense_Claim__c claim
    ) {
        if (claim.Status__c != STATUS_DRAFT) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Only a Draft expense claim can be submitted.'
            );
        }
    }

    /**
     * Requires at least one Expense Item.
     *
     * @param items Expense Items supplied by the caller.
     */
    private static void validateItemsPresent(
        List<Expense_Item__c> items
    ) {
        if (items == null || items.isEmpty()) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'At least one Expense Item is required.'
            );
        }
    }
}