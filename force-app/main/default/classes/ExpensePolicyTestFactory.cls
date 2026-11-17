/**
 * Creates reusable in-memory Expense Claim configuration records for tests.
 */
@IsTest
public class ExpensePolicyTestFactory {

    /**
     * Creates an active distance-based Expense Type for unit tests.
     *
     * @param developerName Developer Name for the Expense Type.
     * @param rate Reimbursement rate per distance unit.
     * @param distanceUnit Distance unit configured for the type.
     * @return In-memory distance-based Expense Type configuration.
     */
    public static Expense_Type__mdt createDistanceType(
        String developerName,
        Decimal rate,
        String distanceUnit
    ) {
        Expense_Type__mdt expenseType =
            createBaseType(
                developerName,
                'Distance'
            );

        expenseType.Rate__c =
            rate;

        expenseType.Distance_Unit__c =
            distanceUnit;

        expenseType.Description_Required__c =
            true;

        expenseType.Sort_Order__c =
            Decimal.valueOf('10');

        return expenseType;
    }

    /**
     * Creates an active amount-based Expense Type for unit tests.
     *
     * @param developerName Developer Name for the Expense Type.
     * @return In-memory amount-based Expense Type configuration.
     */
    public static Expense_Type__mdt createAmountType(
        String developerName
    ) {
        Expense_Type__mdt expenseType =
            createBaseType(
                developerName,
                'Amount'
            );

        expenseType.Description_Required__c =
            false;

        expenseType.Sort_Order__c =
            Decimal.valueOf('20');

        return expenseType;
    }

    /**
     * Creates application-wide Expense Claim settings for unit tests.
     *
     * @param distanceUnit Default application distance unit.
     * @return In-memory Expense Settings configuration.
     */
    public static Expense_Settings__mdt createSettings(
        String distanceUnit
    ) {
        Expense_Settings__mdt settings =
            new Expense_Settings__mdt();

        settings.DeveloperName =
            'Default';

        settings.Default_Distance_Unit__c =
            distanceUnit;

        settings.Allow_Future_Expense_Dates__c =
            false;

        settings.Require_Description__c =
            false;

        settings.Allow_Edit_After_Submission__c =
            false;

        return settings;
    }

    /**
     * Creates fields common to all Expense Type test fixtures.
     *
     * @param developerName Developer Name for the Expense Type.
     * @param calculationMethod Calculation method for the Expense Type.
     * @return Partially populated in-memory Expense Type configuration.
     */
    private static Expense_Type__mdt createBaseType(
        String developerName,
        String calculationMethod
    ) {
        Expense_Type__mdt expenseType =
            new Expense_Type__mdt();

        expenseType.DeveloperName =
            developerName;

        expenseType.Active__c =
            true;

        expenseType.Calculation_Method__c =
            calculationMethod;

        expenseType.Receipt_Required__c =
            false;

        return expenseType;
    }
}