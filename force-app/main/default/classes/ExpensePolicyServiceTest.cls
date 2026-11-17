@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpensePolicyServiceTest {

    @IsTest
    static void getSettingsReturnsPackagedDefault() {
        Expense_Settings__mdt settings =
            ExpensePolicyService.getSettings();

        System.assertNotEquals(
            null,
            settings,
            'The package must contain the Default settings record.'
        );

        System.assertEquals(
            'Default',
            settings.DeveloperName
        );
    }

    @IsTest
    static void getExpenseTypeRejectsBlankName() {
        try {
            ExpensePolicyService.getExpenseType(null);

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'must be specified'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void getMissingExpenseTypeThrowsException() {
        try {
            ExpensePolicyService.getExpenseType(
                'ThisExpenseTypeDoesNotExist'
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'was not found'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void getActiveExpenseTypesReturnsSortedTypes() {
        List<Expense_Type__mdt> expenseTypes =
            ExpensePolicyService.getActiveExpenseTypes();

        System.assert(
            !expenseTypes.isEmpty(),
            'Expected active packaged Expense Types.'
        );

        Decimal previousSortOrder = null;

        for (
            Expense_Type__mdt expenseType :
            expenseTypes
        ) {
            System.assertEquals(
                true,
                expenseType.Active__c,
                'Only active Expense Types should be returned.'
            );

            if (
                previousSortOrder != null &&
                expenseType.Sort_Order__c != null
            ) {
                System.assert(
                    expenseType.Sort_Order__c >=
                    previousSortOrder,
                    'Expense Types must be returned in configured order.'
                );
            }

            if (expenseType.Sort_Order__c != null) {
                previousSortOrder =
                    expenseType.Sort_Order__c;
            }
        }
    }

    @IsTest
    static void calculateDistanceAmountReturnsExpectedAmount() {
        Decimal result =
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('125.50'),
                Decimal.valueOf('0.28')
            );

        System.assertEquals(
            Decimal.valueOf('35.14'),
            result
        );
    }

    @IsTest
    static void calculateDistanceAmountUsesHalfUpRounding() {
        Decimal result =
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('10.005'),
                Decimal.valueOf('1')
            );

        System.assertEquals(
            Decimal.valueOf('10.01'),
            result
        );
    }

    @IsTest
    static void calculateDistanceAmountRejectsZeroDistance() {
        try {
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('0'),
                Decimal.valueOf('0.28')
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Distance must be greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void calculateDistanceAmountRejectsNegativeDistance() {
        try {
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('-10'),
                Decimal.valueOf('0.28')
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Distance must be greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void calculateDistanceAmountRejectsMissingRate() {
        try {
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('50'),
                null
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'rate must be greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void calculateDistanceAmountRejectsZeroRate() {
        try {
            ExpensePolicyService.calculateDistanceAmount(
                Decimal.valueOf('50'),
                Decimal.valueOf('0')
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'rate must be greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void applyPolicyRejectsNullItem() {
        try {
            ExpensePolicyService.applyPolicy(
                null,
                'Meals'
            );

            System.assert(
                false,
                'Expected an ExpensePolicyException.'
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
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
    static void publicAmountPolicyPathWorks() {
        Expense_Item__c item =
            new Expense_Item__c(
                Claimed_Amount__c =
                    Decimal.valueOf('25.50')
            );

        Expense_Item__c result =
            ExpensePolicyService.applyPolicy(
                item,
                'Meals'
            );

        System.assertEquals(
            'Meals',
            result.Expense_Type_Code__c
        );

        System.assertEquals(
            'Amount',
            result.Calculation_Method__c
        );

        System.assertEquals(
            Decimal.valueOf('25.50'),
            result.Claimed_Amount__c,
            'Amount-based policy must preserve the claimant amount.'
        );

        System.assertEquals(
            null,
            result.Distance__c
        );

        System.assertEquals(
            null,
            result.Distance_Unit__c
        );

        System.assertEquals(
            null,
            result.Unit_Rate__c
        );
    }

    @IsTest
    static void applyDistancePolicySnapshotsConfiguration() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                null
            );

        Expense_Settings__mdt settings =
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            );

        Expense_Item__c item =
            new Expense_Item__c(
                Distance__c =
                    Decimal.valueOf('50')
            );

        ExpensePolicyService.applyPolicy(
            item,
            mileage,
            settings
        );

        System.assertEquals(
            'Mileage',
            item.Expense_Type_Code__c
        );

        System.assertEquals(
            'Mileage',
            item.Expense_Type_Label__c
        );

        System.assertEquals(
            'Distance',
            item.Calculation_Method__c
        );

        System.assertEquals(
            Decimal.valueOf('0.28'),
            item.Unit_Rate__c
        );

        System.assertEquals(
            'Kilometres',
            item.Distance_Unit__c
        );

        System.assertEquals(
            Decimal.valueOf('14.00'),
            item.Claimed_Amount__c
        );

        System.assertEquals(
            false,
            item.Receipt_Required__c
        );
    }

    @IsTest
    static void expenseTypeDistanceUnitOverridesDefault() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.50'),
                'Miles'
            );

        Expense_Settings__mdt settings =
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            );

        Expense_Item__c item =
            new Expense_Item__c(
                Distance__c =
                    Decimal.valueOf('10')
            );

        ExpensePolicyService.applyPolicy(
            item,
            mileage,
            settings
        );

        System.assertEquals(
            'Miles',
            item.Distance_Unit__c
        );

        System.assertEquals(
            Decimal.valueOf('5.00'),
            item.Claimed_Amount__c
        );
    }

    @IsTest
    static void amountPolicyPreservesEnteredAmountAndClearsDistance() {
        Expense_Type__mdt meals =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        Expense_Settings__mdt settings =
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            );

        Expense_Item__c item =
            new Expense_Item__c(
                Claimed_Amount__c =
                    Decimal.valueOf('42.75'),
                Distance__c =
                    Decimal.valueOf('25'),
                Distance_Unit__c =
                    'Kilometres',
                Unit_Rate__c =
                    Decimal.valueOf('0.28')
            );

        ExpensePolicyService.applyPolicy(
            item,
            meals,
            settings
        );

        System.assertEquals(
            'Amount',
            item.Calculation_Method__c
        );

        System.assertEquals(
            Decimal.valueOf('42.75'),
            item.Claimed_Amount__c
        );

        System.assertEquals(
            null,
            item.Distance__c
        );

        System.assertEquals(
            null,
            item.Distance_Unit__c
        );

        System.assertEquals(
            null,
            item.Unit_Rate__c
        );
    }

    @IsTest
    static void distancePolicyWithoutDistanceLeavesAmountBlank() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                'Kilometres'
            );

        Expense_Item__c item =
            new Expense_Item__c();

        ExpensePolicyService.applyPolicy(
            item,
            mileage,
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            )
        );

        System.assertEquals(
            null,
            item.Claimed_Amount__c
        );

        System.assertEquals(
            Decimal.valueOf('0.28'),
            item.Unit_Rate__c
        );

        System.assertEquals(
            'Kilometres',
            item.Distance_Unit__c
        );
    }
}