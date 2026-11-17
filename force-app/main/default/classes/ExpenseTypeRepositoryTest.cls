@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseTypeRepositoryTest {

    @IsTest
    static void returnsOnlyActiveExpenseTypes() {
        List<Expense_Type__mdt> expenseTypes =
            ExpenseTypeRepository.getActiveExpenseTypes();

        System.assert(
            !expenseTypes.isEmpty(),
            'Expected active packaged Expense Types.'
        );

        for (
            Expense_Type__mdt expenseType :
            expenseTypes
        ) {
            System.assertEquals(
                true,
                expenseType.Active__c,
                'Repository must not return inactive Expense Types.'
            );
        }
    }

    @IsTest
    static void returnsExpenseTypesInSortOrder() {
        List<Expense_Type__mdt> expenseTypes =
            ExpenseTypeRepository.getActiveExpenseTypes();

        Decimal previousSortOrder = null;

        for (
            Expense_Type__mdt expenseType :
            expenseTypes
        ) {
            if (
                previousSortOrder != null &&
                expenseType.Sort_Order__c != null
            ) {
                System.assert(
                    expenseType.Sort_Order__c >=
                    previousSortOrder,
                    'Expense Types must be ordered by Sort Order.'
                );
            }

            if (expenseType.Sort_Order__c != null) {
                previousSortOrder =
                    expenseType.Sort_Order__c;
            }
        }
    }

    @IsTest
    static void packagedStarterTypesAreAvailable() {
        List<Expense_Type__mdt> expenseTypes =
            ExpenseTypeRepository.getActiveExpenseTypes();

        Set<String> developerNames =
            new Set<String>();

        for (
            Expense_Type__mdt expenseType :
            expenseTypes
        ) {
            developerNames.add(
                expenseType.DeveloperName
            );
        }

        System.assert(
            developerNames.contains('Meals'),
            'Meals should be an active packaged starter Expense Type.'
        );

        System.assert(
            developerNames.contains('Accommodation'),
            'Accommodation should be an active packaged starter Expense Type.'
        );

        System.assert(
            developerNames.contains('Taxi'),
            'Taxi should be an active packaged starter Expense Type.'
        );

        System.assertEquals(
            false,
            developerNames.contains('Mileage'),
            'Mileage should remain inactive until a subscriber configures a rate.'
        );
    }
}