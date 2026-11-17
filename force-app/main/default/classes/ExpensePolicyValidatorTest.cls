@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpensePolicyValidatorTest {

    @IsTest
    static void validAmountConfigurationPasses() {
        Expense_Type__mdt expenseType =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        Expense_Settings__mdt settings =
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            );

        Test.startTest();

        ExpensePolicyValidator.validate(
            expenseType,
            settings
        );

        Test.stopTest();

        System.assert(
            true,
            'Valid amount configuration should not throw an exception.'
        );
    }

    @IsTest
    static void validDistanceConfigurationPasses() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                'Kilometres'
            );

        Test.startTest();

        ExpensePolicyValidator.validate(
            mileage,
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            )
        );

        Test.stopTest();

        System.assert(
            true,
            'Valid distance configuration should not throw an exception.'
        );
    }

    @IsTest
    static void missingExpenseTypeConfigurationIsRejected() {
        try {
            ExpensePolicyValidator.validate(
                null,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'Expense type configuration is missing'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void missingSettingsConfigurationIsRejected() {
        Expense_Type__mdt meals =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        try {
            ExpensePolicyValidator.validate(
                meals,
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
                    'Expense settings configuration is missing'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void inactiveExpenseTypeIsRejected() {
        Expense_Type__mdt meals =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        meals.Active__c = false;

        try {
            ExpensePolicyValidator.validate(
                meals,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'is inactive'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void missingCalculationMethodIsRejected() {
        Expense_Type__mdt expenseType =
            ExpensePolicyTestFactory.createAmountType(
                'InvalidType'
            );

        expenseType.Calculation_Method__c = null;

        try {
            ExpensePolicyValidator.validate(
                expenseType,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'does not have a calculation method'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void unsupportedCalculationMethodIsRejected() {
        Expense_Type__mdt expenseType =
            ExpensePolicyTestFactory.createAmountType(
                'InvalidType'
            );

        expenseType.Calculation_Method__c =
            'Unsupported';

        try {
            ExpensePolicyValidator.validate(
                expenseType,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'unsupported calculation method'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void negativeMaximumAmountIsRejected() {
        Expense_Type__mdt meals =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        meals.Maximum_Amount__c =
            Decimal.valueOf('-1');

        try {
            ExpensePolicyValidator.validate(
                meals,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'invalid maximum amount'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void zeroMaximumAmountIsAllowed() {
        Expense_Type__mdt meals =
            ExpensePolicyTestFactory.createAmountType(
                'Meals'
            );

        meals.Maximum_Amount__c =
            Decimal.valueOf('0');

        Test.startTest();

        ExpensePolicyValidator.validate(
            meals,
            ExpensePolicyTestFactory.createSettings(
                'Kilometres'
            )
        );

        Test.stopTest();

        System.assert(
            true,
            'Zero maximum amount is not invalid configuration.'
        );
    }

    @IsTest
    static void distanceTypeRequiresPositiveRate() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                null,
                'Kilometres'
            );

        try {
            ExpensePolicyValidator.validate(
                mileage,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'requires a distance rate greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void distanceTypeRejectsZeroRate() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0'),
                'Kilometres'
            );

        try {
            ExpensePolicyValidator.validate(
                mileage,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
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
                    'requires a distance rate greater than zero'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void distanceTypeUsesOwnDistanceUnit() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                'Miles'
            );

        String unit =
            ExpensePolicyValidator.resolveDistanceUnit(
                mileage,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
            );

        System.assertEquals(
            'Miles',
            unit
        );
    }

    @IsTest
    static void distanceTypeFallsBackToDefaultUnit() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                null
            );

        String unit =
            ExpensePolicyValidator.resolveDistanceUnit(
                mileage,
                ExpensePolicyTestFactory.createSettings(
                    'Kilometres'
                )
            );

        System.assertEquals(
            'Kilometres',
            unit
        );
    }

    @IsTest
    static void distanceTypeRequiresDistanceUnit() {
        Expense_Type__mdt mileage =
            ExpensePolicyTestFactory.createDistanceType(
                'Mileage',
                Decimal.valueOf('0.28'),
                null
            );

        try {
            ExpensePolicyValidator.validate(
                mileage,
                ExpensePolicyTestFactory.createSettings(
                    null
                )
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
                    'No distance unit is configured'
                ),
                exceptionValue.getMessage()
            );
        }
    }
}