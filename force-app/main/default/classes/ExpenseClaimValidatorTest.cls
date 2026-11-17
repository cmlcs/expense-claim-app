@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimValidatorTest {

    @IsTest
    static void nullClaimIsRejected() {
        try {
            ExpenseClaimValidator.validateDraft(
                null,
                createItemList()
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Expense Claim must be provided'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void nonDraftClaimIsRejected() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        claim.Status__c =
            'Submitted';

        try {
            ExpenseClaimValidator.validateDraft(
                claim,
                createItemList()
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Only a Draft'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void nullItemsAreRejected() {
        try {
            ExpenseClaimValidator.validateDraft(
                ExpenseClaimTestFactory.createDraftClaim(),
                null
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'At least one Expense Item'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void emptyItemsAreRejected() {
        try {
            ExpenseClaimValidator.validateDraft(
                ExpenseClaimTestFactory.createDraftClaim(),
                new List<Expense_Item__c>()
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'At least one Expense Item'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void validDraftPassesValidation() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        ExpenseClaimValidator.validateDraft(
            claim,
            createItemList()
        );

        System.assertEquals(
            'Draft',
            claim.Status__c,
            'Validation must not change claim status.'
        );
    }

    @IsTest
    static void nullSettingsAreRejected() {
        try {
            ExpenseClaimValidator.validateSettings(
                null
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'settings configuration is missing'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void negativeMaximumExpenseAgeIsRejected() {
        Expense_Settings__mdt settings =
            createSettings();

        settings.Maximum_Expense_Age_Days__c =
            Decimal.valueOf('-1');

        try {
            ExpenseClaimValidator.validateSettings(
                settings
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'cannot be negative'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void validSettingsPassValidation() {
        Expense_Settings__mdt settings =
            createSettings();

        settings.Maximum_Expense_Age_Days__c =
            Decimal.valueOf('30');

        ExpenseClaimValidator.validateSettings(
            settings
        );

        System.assertEquals(
            Decimal.valueOf('30'),
            settings.Maximum_Expense_Age_Days__c,
            'Validation must not modify configuration.'
        );
    }

    @IsTest
    static void nullItemReferenceIsRejected() {
        try {
            ExpenseClaimValidator.validateItemReference(
                null
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Expense Item must be provided'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void missingExpenseTypeReferenceIsRejected() {
        Expense_Item__c item =
            new Expense_Item__c();

        try {
            ExpenseClaimValidator.validateItemReference(
                item
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Expense Type must be selected'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void validItemReferencePassesValidation() {
        Expense_Item__c item =
            new Expense_Item__c(
                Expense_Type_Code__c = 'Meals'
            );

        ExpenseClaimValidator.validateItemReference(
            item
        );

        System.assertEquals(
            'Meals',
            item.Expense_Type_Code__c,
            'Validation must not modify the Expense Type.'
        );
    }

    private static List<Expense_Item__c> createItemList() {
        return new List<Expense_Item__c>{
            new Expense_Item__c()
        };
    }

    private static Expense_Settings__mdt createSettings() {
        return ExpensePolicyTestFactory.createSettings(
            'Kilometres'
        );
    }
}