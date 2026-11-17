/**
 * Provides access to configured Expense Type custom metadata.
 */
public inherited sharing class ExpenseTypeRepository {

    /**
     * Returns active Expense Types ordered by Sort Order.
     *
     * @return Active Expense Types in configured display order.
     */
    public static List<Expense_Type__mdt> getActiveExpenseTypes() {
        return filterAndSort(
            Expense_Type__mdt.getAll().values()
        );
    }

    /**
     * Filters inactive Expense Types and applies configured ordering.
     *
     * Exposed to tests so repository behavior can be tested without
     * depending on mutable subscriber configuration.
     *
     * @param expenseTypes Expense Types to process.
     * @return Active Expense Types in configured display order.
     */
    @TestVisible
    private static List<Expense_Type__mdt> filterAndSort(
        List<Expense_Type__mdt> expenseTypes
    ) {
        List<Expense_Type__mdt> activeTypes =
            new List<Expense_Type__mdt>();

        if (expenseTypes == null) {
            return activeTypes;
        }

        for (Expense_Type__mdt expenseType : expenseTypes) {
            if (expenseType.Active__c == true) {
                activeTypes.add(expenseType);
            }
        }

        sortBySortOrder(activeTypes);

        return activeTypes;
    }

    /**
     * Sorts Expense Types by configured Sort Order.
     *
     * @param expenseTypes Expense Types to sort.
     */
    private static void sortBySortOrder(
        List<Expense_Type__mdt> expenseTypes
    ) {
        for (Integer i = 1; i < expenseTypes.size(); i++) {
            Expense_Type__mdt current =
                expenseTypes[i];

            Integer position =
                i - 1;

            while (
                position >= 0 &&
                comesBefore(
                    current,
                    expenseTypes[position]
                )
            ) {
                expenseTypes[position + 1] =
                    expenseTypes[position];

                position--;
            }

            expenseTypes[position + 1] =
                current;
        }
    }

    /**
     * Determines whether one Expense Type should appear before another.
     *
     * @param left Candidate Expense Type.
     * @param right Existing Expense Type.
     * @return True when left should appear first.
     */
    private static Boolean comesBefore(
        Expense_Type__mdt left,
        Expense_Type__mdt right
    ) {
        Decimal leftOrder =
            sortValue(left);

        Decimal rightOrder =
            sortValue(right);

        if (leftOrder != rightOrder) {
            return leftOrder < rightOrder;
        }

        return sortName(left).compareTo(
            sortName(right)
        ) < 0;
    }

    /**
     * Returns a sortable numeric value, placing null values last.
     *
     * @param expenseType Expense Type.
     * @return Numeric sort value.
     */
    private static Decimal sortValue(
        Expense_Type__mdt expenseType
    ) {
        return expenseType.Sort_Order__c == null
            ? Decimal.valueOf('99999')
            : expenseType.Sort_Order__c;
    }

    /**
     * Returns a deterministic secondary sort key.
     *
     * @param expenseType Expense Type.
     * @return Lowercase label or Developer Name.
     */
    private static String sortName(
        Expense_Type__mdt expenseType
    ) {
        String value =
            String.isBlank(expenseType.MasterLabel)
                ? expenseType.DeveloperName
                : expenseType.MasterLabel;

        return value.toLowerCase();
    }
}