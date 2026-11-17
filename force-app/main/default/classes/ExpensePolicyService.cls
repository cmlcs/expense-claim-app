/**
 * Reads Expense Claim policy configuration and applies it to expense items.
 *
 * This service performs no DML. Callers remain responsible for persisting
 * Expense_Item__c records after policy has been applied.
 */
public with sharing class ExpensePolicyService {

    private static final String DEFAULT_SETTINGS_NAME = 'Default';
    private static final String METHOD_DISTANCE = 'Distance';

    /**
     * Exception raised when Expense Claim policy configuration or input is invalid.
     */
    public class ExpensePolicyException extends Exception {
    }

    /**
     * Returns the application-wide default Expense Claim settings.
     *
     * @return The Default Expense Settings custom metadata record.
     */
    public static Expense_Settings__mdt getSettings() {
        Expense_Settings__mdt settings =
            Expense_Settings__mdt.getInstance(DEFAULT_SETTINGS_NAME);

        if (settings == null) {
            throw new ExpensePolicyException(
                'Expense Claim configuration is incomplete. ' +
                'Expense Settings record "Default" was not found.'
            );
        }

        return settings;
    }

    /**
     * Returns and validates an Expense Type by Developer Name.
     *
     * @param developerName Developer Name of the Expense Type metadata record.
     * @return The validated Expense Type metadata record.
     */
    public static Expense_Type__mdt getExpenseType(
        String developerName
    ) {
        if (String.isBlank(developerName)) {
            throw new ExpensePolicyException(
                'An expense type must be specified.'
            );
        }

        Expense_Type__mdt expenseType =
            Expense_Type__mdt.getInstance(developerName);

        if (expenseType == null) {
            throw new ExpensePolicyException(
                'Expense type "' + developerName + '" was not found.'
            );
        }

        ExpensePolicyValidator.validate(
            expenseType,
            getSettings()
        );

        return expenseType;
    }

    /**
     * Returns all active and valid Expense Types in configured display order.
     *
     * @return Active Expense Types ordered by configured Sort Order.
     */
    public static List<Expense_Type__mdt> getActiveExpenseTypes() {
        Expense_Settings__mdt settings = getSettings();

        List<Expense_Type__mdt> expenseTypes =
            ExpenseTypeRepository.getActiveExpenseTypes();

        for (Expense_Type__mdt expenseType : expenseTypes) {
            ExpensePolicyValidator.validate(
                expenseType,
                settings
            );
        }

        return expenseTypes;
    }

    /**
     * Applies the selected Expense Type policy to an Expense Item.
     *
     * The item is modified in memory. No DML is performed.
     *
     * @param item Expense Item to modify.
     * @param expenseTypeDeveloperName Developer Name of the selected Expense Type.
     * @return The same Expense Item with policy snapshot fields populated.
     */
    public static Expense_Item__c applyPolicy(
        Expense_Item__c item,
        String expenseTypeDeveloperName
    ) {
        requireItem(item);

        Expense_Type__mdt expenseType =
            getExpenseType(expenseTypeDeveloperName);

        return applyPolicy(
            item,
            expenseType,
            getSettings()
        );
    }

    /**
     * Calculates the reimbursement amount for a distance-based expense.
     *
     * @param distance Distance being claimed.
     * @param rate Configured reimbursement rate per distance unit.
     * @return Amount rounded to two decimal places using HALF_UP rounding.
     */
    public static Decimal calculateDistanceAmount(
        Decimal distance,
        Decimal rate
    ) {
        if (distance == null || distance <= 0) {
            throw new ExpensePolicyException(
                'Distance must be greater than zero.'
            );
        }

        if (rate == null || rate <= 0) {
            throw new ExpensePolicyException(
                'The configured distance rate must be greater than zero.'
            );
        }

        return (distance * rate).setScale(
            2,
            System.RoundingMode.HALF_UP
        );
    }

    /**
     * Applies supplied policy configuration to an Expense Item.
     *
     * This overload allows unit tests to use in-memory Custom Metadata
     * configuration rather than changing deployed package configuration.
     *
     * @param item Expense Item to modify.
     * @param expenseType Expense Type configuration.
     * @param settings Global Expense Claim settings.
     * @return The same Expense Item with policy applied.
     */
    @TestVisible
    private static Expense_Item__c applyPolicy(
        Expense_Item__c item,
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        requireItem(item);

        ExpensePolicyValidator.validate(
            expenseType,
            settings
        );

        applyCommonSnapshot(
            item,
            expenseType
        );

        if (
            expenseType.Calculation_Method__c ==
            METHOD_DISTANCE
        ) {
            applyDistancePolicy(
                item,
                expenseType,
                settings
            );
        } else {
            applyAmountPolicy(item);
        }

        return item;
    }

    /**
     * Applies fields common to all Expense Type calculation methods.
     *
     * @param item Expense Item being updated.
     * @param expenseType Expense Type configuration being applied.
     */
    private static void applyCommonSnapshot(
        Expense_Item__c item,
        Expense_Type__mdt expenseType
    ) {
        item.Expense_Type_Code__c =
            expenseType.DeveloperName;

        item.Expense_Type_Label__c =
            resolveExpenseTypeLabel(expenseType);

        item.Calculation_Method__c =
            expenseType.Calculation_Method__c;

        item.Receipt_Required__c =
            expenseType.Receipt_Required__c;
    }

    /**
     * Applies distance-specific policy and calculates the claimed amount.
     *
     * @param item Expense Item being updated.
     * @param expenseType Distance-based Expense Type configuration.
     * @param settings Global Expense Claim settings.
     */
    private static void applyDistancePolicy(
        Expense_Item__c item,
        Expense_Type__mdt expenseType,
        Expense_Settings__mdt settings
    ) {
        item.Unit_Rate__c =
            expenseType.Rate__c;

        item.Distance_Unit__c =
            ExpensePolicyValidator.resolveDistanceUnit(
                expenseType,
                settings
            );

        if (item.Distance__c == null) {
            item.Claimed_Amount__c = null;
            return;
        }

        item.Claimed_Amount__c =
            calculateDistanceAmount(
                item.Distance__c,
                expenseType.Rate__c
            );
    }

    /**
     * Clears distance-specific values for an amount-based expense.
     *
     * Claimed Amount is intentionally preserved because it is entered
     * directly by the claimant for amount-based Expense Types.
     *
     * @param item Expense Item being updated.
     */
    private static void applyAmountPolicy(
        Expense_Item__c item
    ) {
        item.Distance__c = null;
        item.Distance_Unit__c = null;
        item.Unit_Rate__c = null;
    }

    /**
     * Resolves a display label for the Expense Type.
     *
     * @param expenseType Expense Type configuration.
     * @return Master Label when available, otherwise Developer Name.
     */
    private static String resolveExpenseTypeLabel(
        Expense_Type__mdt expenseType
    ) {
        return String.isBlank(expenseType.MasterLabel)
            ? expenseType.DeveloperName
            : expenseType.MasterLabel;
    }

    /**
     * Ensures an Expense Item was supplied.
     *
     * @param item Expense Item supplied by the caller.
     */
    private static void requireItem(
        Expense_Item__c item
    ) {
        if (item == null) {
            throw new ExpensePolicyException(
                'An Expense Item must be provided.'
            );
        }
    }
}