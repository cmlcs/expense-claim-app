/**
 * Validates Expense Claim policy configuration.
 */
public inherited sharing class ExpensePolicyValidator {

    private static final String METHOD_AMOUNT = 'Amount';
    private static final String METHOD_DISTANCE = 'Distance';

    /**
     * Validates an Expense Type and its global settings.
     *
     * @param expenseType Expense Type configuration.
     * @param settings Global Expense Claim settings.
     */
    public static void validate(
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        validateRequiredConfiguration(
            expenseType,
            settings
        );

        validateCalculationMethod(expenseType);
        validateMaximumAmount(expenseType);

        if (expenseType.Calculation_Method__c == METHOD_DISTANCE) {
            validateDistanceConfiguration(
                expenseType,
                settings
            );
        }
    }

    /**
     * Resolves the effective distance unit.
     *
     * Expense Type configuration takes precedence over the application
     * default.
     *
     * @param expenseType Expense Type configuration.
     * @param settings Global Expense Claim settings.
     * @return Effective distance unit.
     */
    public static String resolveDistanceUnit(
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        if (!String.isBlank(expenseType.Distance_Unit__c)) {
            return expenseType.Distance_Unit__c;
        }

        if (
            settings != null &&
            !String.isBlank(settings.Default_Distance_Unit__c)
        ) {
            return settings.Default_Distance_Unit__c;
        }

        throw new ExpensePolicyService.ExpensePolicyException(
            'No distance unit is configured for expense type "' +
            expenseType.DeveloperName +
            '".'
        );
    }

    /**
     * Validates records required by all Expense Types.
     *
     * @param expenseType Expense Type configuration.
     * @param settings Global Expense Claim settings.
     */
    private static void validateRequiredConfiguration(
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        if (expenseType == null) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type configuration is missing.'
            );
        }

        if (settings == null) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense settings configuration is missing.'
            );
        }

        if (expenseType.Active__c != true) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type "' +
                expenseType.DeveloperName +
                '" is inactive.'
            );
        }
    }

    /**
     * Validates the configured calculation method.
     *
     * @param expenseType Expense Type configuration.
     */
    private static void validateCalculationMethod(
        Expense_Type__mdt expenseType
    ) {
        if (String.isBlank(expenseType.Calculation_Method__c)) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type "' +
                expenseType.DeveloperName +
                '" does not have a calculation method.'
            );
        }

        if (
            expenseType.Calculation_Method__c != METHOD_AMOUNT &&
            expenseType.Calculation_Method__c != METHOD_DISTANCE
        ) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type "' +
                expenseType.DeveloperName +
                '" has an unsupported calculation method.'
            );
        }
    }

    /**
     * Validates the optional maximum amount.
     *
     * @param expenseType Expense Type configuration.
     */
    private static void validateMaximumAmount(
        Expense_Type__mdt expenseType
    ) {
        if (
            expenseType.Maximum_Amount__c != null &&
            expenseType.Maximum_Amount__c < 0
        ) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type "' +
                expenseType.DeveloperName +
                '" has an invalid maximum amount.'
            );
        }
    }

    /**
     * Validates distance-specific policy.
     *
     * @param expenseType Expense Type configuration.
     * @param settings Global Expense Claim settings.
     */
    private static void validateDistanceConfiguration(
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        if (
            expenseType.Rate__c == null ||
            expenseType.Rate__c <= 0
        ) {
            throw new ExpensePolicyService.ExpensePolicyException(
                'Expense type "' +
                expenseType.DeveloperName +
                '" requires a distance rate greater than zero.'
            );
        }

        resolveDistanceUnit(
            expenseType,
            settings
        );
    }
}