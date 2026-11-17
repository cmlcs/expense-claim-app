/**
 * Validates prepared Expense Items against application and Expense Type policy.
 */
public inherited sharing class ExpenseItemValidator {

    /**
     * Validates an Expense Item after current Expense Type policy is applied.
     *
     * @param item Expense Item being submitted.
     * @param expenseType Expense Type policy applied to the item.
     * @param settings Global Expense Claim settings.
     */
    public static void validatePreparedItem(
        Expense_Item__c item,
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        if (expenseType == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Expense Type configuration is missing.'
            );
        }

        validateExpenseDate(
            item,
            settings
        );

        validateAmount(
            item,
            expenseType
        );

        validateDescription(
            item,
            expenseType,
            settings
        );
    }

    /**
     * Validates that an Expense Date is present and compliant with policy.
     *
     * @param item Expense Item being submitted.
     * @param settings Global Expense Claim settings.
     */
    private static void validateExpenseDate(
        Expense_Item__c item,
        Expense_Settings__mdt settings
    ) {
        if (item.Expense_Date__c == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Expense Date is required.'
            );
        }

        validateFutureExpenseDate(
            item.Expense_Date__c,
            settings
        );

        validateMaximumExpenseAge(
            item.Expense_Date__c,
            settings
        );
    }

    /**
     * Validates whether a future expense date is allowed.
     *
     * @param expenseDate Expense Date being validated.
     * @param settings Global Expense Claim settings.
     */
    private static void validateFutureExpenseDate(
        Date expenseDate,
        Expense_Settings__mdt settings
    ) {
        if (
            expenseDate > Date.today() &&
            settings.Allow_Future_Expense_Dates__c != true
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Future expense dates are not allowed.'
            );
        }
    }

    /**
     * Validates the configured maximum age of an expense.
     *
     * @param expenseDate Expense Date being validated.
     * @param settings Global Expense Claim settings.
     */
    private static void validateMaximumExpenseAge(
        Date expenseDate,
        Expense_Settings__mdt settings
    ) {
        if (settings.Maximum_Expense_Age_Days__c == null) {
            return;
        }

        Date today = Date.today();

        if (expenseDate >= today) {
            return;
        }

        Integer maximumAge =
            settings.Maximum_Expense_Age_Days__c.intValue();

        if (expenseDate.daysBetween(today) > maximumAge) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'The expense date exceeds the maximum allowed age.'
            );
        }
    }

    /**
     * Validates the claimed amount against Expense Type policy.
     *
     * @param item Expense Item being submitted.
     * @param expenseType Expense Type policy.
     */
    private static void validateAmount(
        Expense_Item__c item,
        Expense_Type__mdt expenseType
    ) {
        if (
            item.Claimed_Amount__c == null ||
            item.Claimed_Amount__c <= 0
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Claimed Amount must be greater than zero.'
            );
        }

        if (
            expenseType.Maximum_Amount__c != null &&
            item.Claimed_Amount__c >
                expenseType.Maximum_Amount__c
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Claimed Amount exceeds the maximum allowed for this Expense Type.'
            );
        }
    }

    /**
     * Validates item description requirements.
     *
     * @param item Expense Item being submitted.
     * @param expenseType Expense Type policy.
     * @param settings Global Expense Claim settings.
     */
    private static void validateDescription(
        Expense_Item__c item,
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        Boolean descriptionRequired =
            settings.Require_Description__c == true ||
            expenseType.Description_Required__c == true;

        if (
            descriptionRequired &&
            String.isBlank(item.Description__c)
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Description is required for this expense.'
            );
        }
    }
}