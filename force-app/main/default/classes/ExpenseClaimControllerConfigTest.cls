@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimControllerConfigTest {

    @IsTest
    static void configurationContainsCurrentClaimant() {
        ExpenseClaimConfigurationDto configuration =
            ExpenseClaimController.getConfiguration();

        System.assertEquals(
            UserInfo.getName(),
            configuration.claimantName
        );

        System.assertEquals(
            UserInfo.getUserEmail(),
            configuration.claimantEmail
        );

        System.assertNotEquals(
            null,
            configuration.expenseTypes
        );
    }

    @IsTest
    static void configurationContainsOnlyActiveExpenseTypes() {
        ExpenseClaimConfigurationDto configuration =
            ExpenseClaimController.getConfiguration();

        System.assert(
            !configuration.expenseTypes.isEmpty(),
            'Expected at least one active Expense Type.'
        );

        Set<String> returnedCodes =
            new Set<String>();

        for (ExpenseTypeDto expenseType : configuration.expenseTypes) {
            returnedCodes.add(
                expenseType.developerName
            );
        }

        for (
            Expense_Type__mdt expenseType :
            ExpenseTypeRepository.getActiveExpenseTypes()
        ) {
            System.assert(
                returnedCodes.contains(
                    expenseType.DeveloperName
                ),
                'Expected active Expense Type in controller configuration.'
            );
        }
    }

    @IsTest
    static void applyPolicyReturnsServerDerivedValues() {
        String expenseTypeCode = ExpenseClaimControllerTestFactory.findActiveAmountTypeCode();

        System.assertNotEquals(
            null,
            expenseTypeCode,
            'Test requires an active amount-based Expense Type.'
        );

        ExpenseItemDto item =
            ExpenseClaimControllerTestFactory.createAmountItem(
                expenseTypeCode,
                Decimal.valueOf('25.50')
            );

        item.expenseTypeLabel =
            'Spoofed Label';

        item.calculationMethod =
            'Distance';

        item.unitRate =
            Decimal.valueOf('999');

        item.receiptRequired =
            true;

        ExpenseItemDto result =
            ExpenseClaimController.applyPolicy(
                item
            );

        System.assertEquals(
            expenseTypeCode,
            result.expenseTypeCode
        );

        System.assertEquals(
            'Amount',
            result.calculationMethod
        );

        System.assertEquals(
            Decimal.valueOf('25.50'),
            result.claimedAmount
        );

        System.assertNotEquals(
            'Spoofed Label',
            result.expenseTypeLabel
        );

        System.assertEquals(
            null,
            result.unitRate
        );
    }

    @IsTest
    static void createReceiptUploadKeyReturnsOpaqueKey() {
        Test.startTest();

        String uploadKey =
            ExpenseClaimController.createReceiptUploadKey();

        Test.stopTest();

        System.assertEquals(
            64,
            uploadKey.length(),
            'The receipt upload key should contain 64 characters.'
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                uploadKey
            ),
            'The receipt upload key should contain only hexadecimal characters.'
        );
    }

    @IsTest
    static void applyPolicyRejectsNullItem() {
        AuraHandledException exceptionValue;

        try {
            ExpenseClaimController.applyPolicy(
                null
            );
        } catch (AuraHandledException caughtException) {
            exceptionValue =
                caughtException;
        }

        System.assertNotEquals(
            null,
            exceptionValue,
            'Expected a handled client exception.'
        );
    }
}