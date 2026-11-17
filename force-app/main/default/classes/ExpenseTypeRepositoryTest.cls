@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseTypeRepositoryTest {

    @IsTest
    static void repositoryReturnsConfiguredActiveTypes() {
        List<Expense_Type__mdt> expenseTypes =
            ExpenseTypeRepository.getActiveExpenseTypes();

        for (
            Expense_Type__mdt expenseType :
            expenseTypes
        ) {
            System.assertEquals(
                true,
                expenseType.Active__c,
                'Repository must only return active Expense Types.'
            );
        }
    }

    @IsTest
    static void inactiveTypesAreFilteredOut() {
        Expense_Type__mdt active =
            ExpensePolicyTestFactory.createAmountType(
                'ActiveType'
            );

        Expense_Type__mdt inactive =
            ExpensePolicyTestFactory.createAmountType(
                'InactiveType'
            );

        inactive.Active__c =
            false;

        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                new List<Expense_Type__mdt>{
                    inactive,
                    active
                }
            );

        System.assertEquals(
            1,
            results.size()
        );

        System.assertEquals(
            'ActiveType',
            results[0].DeveloperName
        );
    }

    @IsTest
    static void typesAreSortedBySortOrder() {
        Expense_Type__mdt first =
            ExpensePolicyTestFactory.createAmountType(
                'First'
            );

        first.Sort_Order__c =
            Decimal.valueOf('10');

        Expense_Type__mdt second =
            ExpensePolicyTestFactory.createAmountType(
                'Second'
            );

        second.Sort_Order__c =
            Decimal.valueOf('20');

        Expense_Type__mdt third =
            ExpensePolicyTestFactory.createAmountType(
                'Third'
            );

        third.Sort_Order__c =
            Decimal.valueOf('30');

        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                new List<Expense_Type__mdt>{
                    third,
                    first,
                    second
                }
            );

        System.assertEquals(
            3,
            results.size()
        );

        System.assertEquals(
            'First',
            results[0].DeveloperName
        );

        System.assertEquals(
            'Second',
            results[1].DeveloperName
        );

        System.assertEquals(
            'Third',
            results[2].DeveloperName
        );
    }

    @IsTest
    static void nullSortOrderIsPlacedLast() {
        Expense_Type__mdt sorted =
            ExpensePolicyTestFactory.createAmountType(
                'Sorted'
            );

        sorted.Sort_Order__c =
            Decimal.valueOf('10');

        Expense_Type__mdt unsorted =
            ExpensePolicyTestFactory.createAmountType(
                'Unsorted'
            );

        unsorted.Sort_Order__c =
            null;

        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                new List<Expense_Type__mdt>{
                    unsorted,
                    sorted
                }
            );

        System.assertEquals(
            'Sorted',
            results[0].DeveloperName
        );

        System.assertEquals(
            'Unsorted',
            results[1].DeveloperName
        );
    }

    @IsTest
    static void equalSortOrderUsesNameAsTieBreaker() {
        Expense_Type__mdt beta =
            ExpensePolicyTestFactory.createAmountType(
                'Beta'
            );

        beta.Sort_Order__c =
            Decimal.valueOf('10');

        Expense_Type__mdt alpha =
            ExpensePolicyTestFactory.createAmountType(
                'Alpha'
            );

        alpha.Sort_Order__c =
            Decimal.valueOf('10');

        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                new List<Expense_Type__mdt>{
                    beta,
                    alpha
                }
            );

        System.assertEquals(
            'Alpha',
            results[0].DeveloperName
        );

        System.assertEquals(
            'Beta',
            results[1].DeveloperName
        );
    }

    @IsTest
    static void emptyConfigurationReturnsEmptyList() {
        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                new List<Expense_Type__mdt>()
            );

        System.assertEquals(
            0,
            results.size()
        );
    }

    @IsTest
    static void nullConfigurationReturnsEmptyList() {
        List<Expense_Type__mdt> results =
            ExpenseTypeRepository.filterAndSort(
                null
            );

        System.assertEquals(
            0,
            results.size()
        );
    }
}