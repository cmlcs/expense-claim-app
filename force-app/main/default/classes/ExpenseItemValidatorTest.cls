@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseItemValidatorTest {

    private class ValidationCase {
        Expense_Item__c item;
        Expense_Type__mdt expenseType;
        Expense_Settings__mdt settings;
    }

    @IsTest
    static void missingExpenseTypeConfigurationIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today()
                )
            );

        validationCase.expenseType = null;

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Expense Type configuration is missing'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void missingExpenseDateIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    null
                )
            );

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Expense Date is required'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void futureExpenseDateIsRejectedByDefault() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today().addDays(1)
                )
            );

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Future expense dates are not allowed'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void futureExpenseDateCanBeAllowed() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today().addDays(1)
                )
            );

        validationCase.settings.Allow_Future_Expense_Dates__c =
            true;

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            Date.today().addDays(1),
            validationCase.item.Expense_Date__c,
            'Allowed future date should remain unchanged.'
        );
    }

    @IsTest
    static void expenseOlderThanMaximumAgeIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today().addDays(-31)
                )
            );

        validationCase.settings.Maximum_Expense_Age_Days__c =
            Decimal.valueOf('30');

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'maximum allowed age'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void expenseAtMaximumAgeIsAllowed() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today().addDays(-30)
                )
            );

        validationCase.settings.Maximum_Expense_Age_Days__c =
            Decimal.valueOf('30');

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            Date.today().addDays(-30),
            validationCase.item.Expense_Date__c,
            'Expense exactly at the maximum age should be accepted.'
        );
    }

    @IsTest
    static void expenseWithoutMaximumAgeIsAllowed() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today().addDays(-365)
                )
            );

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            Date.today().addDays(-365),
            validationCase.item.Expense_Date__c,
            'No age restriction should apply when none is configured.'
        );
    }

    @IsTest
    static void missingClaimedAmountIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    null,
                    Date.today()
                )
            );

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Claimed Amount must be greater than zero'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void zeroClaimedAmountIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('0'),
                    Date.today()
                )
            );

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Claimed Amount must be greater than zero'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void negativeClaimedAmountIsRejected() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('-1'),
                    Date.today()
                )
            );

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Claimed Amount must be greater than zero'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void maximumAmountIsEnforced() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('50.01'),
                    Date.today()
                )
            );

        validationCase.expenseType.Maximum_Amount__c =
            Decimal.valueOf('50');

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'exceeds the maximum allowed'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void amountAtMaximumIsAllowed() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('50'),
                    Date.today()
                )
            );

        validationCase.expenseType.Maximum_Amount__c =
            Decimal.valueOf('50');

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            Decimal.valueOf('50'),
            validationCase.item.Claimed_Amount__c,
            'Amount equal to the configured maximum should be accepted.'
        );
    }

    @IsTest
    static void globalDescriptionRequirementIsEnforced() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today()
                )
            );

        validationCase.item.Description__c = null;
        validationCase.settings.Require_Description__c = true;

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Description is required'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void expenseTypeDescriptionRequirementIsEnforced() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today()
                )
            );

        validationCase.item.Description__c = null;
        validationCase.expenseType.Description_Required__c = true;

        ExpenseClaimService.ExpenseClaimException exceptionValue =
            captureFailure(validationCase);

        System.assert(
            exceptionValue.getMessage().contains(
                'Description is required'
            ),
            exceptionValue.getMessage()
        );
    }

    @IsTest
    static void descriptionIsOptionalWhenNotRequired() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('20'),
                    Date.today()
                )
            );

        validationCase.item.Description__c = null;

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            null,
            validationCase.item.Description__c,
            'Optional blank description should remain valid.'
        );
    }

    @IsTest
    static void validPreparedItemPassesValidation() {
        ValidationCase validationCase =
            createValidationCase(
                createAmountItem(
                    Decimal.valueOf('25'),
                    Date.today()
                )
            );

        ExpenseItemValidator.validatePreparedItem(
            validationCase.item,
            validationCase.expenseType,
            validationCase.settings
        );

        System.assertEquals(
            Decimal.valueOf('25'),
            validationCase.item.Claimed_Amount__c,
            'Valid item should pass without modification.'
        );
    }

    private static ValidationCase createValidationCase(
        Expense_Item__c item
    ) {
        ValidationCase validationCase =
            new ValidationCase();

        validationCase.item =
            item;

        validationCase.expenseType =
            createAmountType();

        validationCase.settings =
            createSettings();

        return validationCase;
    }

    private static ExpenseClaimService.ExpenseClaimException captureFailure(
        ValidationCase validationCase
    ) {
        try {
            ExpenseItemValidator.validatePreparedItem(
                validationCase.item,
                validationCase.expenseType,
                validationCase.settings
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );

            return null;
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            return exceptionValue;
        }
    }

    private static Expense_Item__c createAmountItem(
        Decimal amount,
        Date expenseDate
    ) {
        return ExpenseClaimTestFactory.createAmountItem(
            'Meals',
            amount,
            expenseDate
        );
    }

    private static Expense_Type__mdt createAmountType() {
        return ExpensePolicyTestFactory.createAmountType(
            'Meals'
        );
    }

    private static Expense_Settings__mdt createSettings() {
        return ExpensePolicyTestFactory.createSettings(
            'Kilometres'
        );
    }
}