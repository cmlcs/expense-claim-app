/**
 * Validates Expense Claim receipt requirements and upload correlation.
 */
public inherited sharing class ExpenseReceiptValidator {
    private static final String UPLOAD_KEY_PATTERN =
        '^[0-9a-fA-F]{64}$';

    /**
     * Holds the values used to validate one expense line.
     */
    private class ReceiptValidationContext {
        private ExpenseItemDto requestItem;
        private Expense_Item__c preparedItem;
        private Integer index;

        /**
         * Creates a validation context for one expense line.
         *
         * @param requestItem Claimant-supplied expense item DTO.
         * @param preparedItem Expense item after policy application.
         * @param index Zero-based position of the expense line.
         */
        private ReceiptValidationContext(
            ExpenseItemDto requestItem,
            Expense_Item__c preparedItem,
            Integer index
        ) {
            this.requestItem = requestItem;
            this.preparedItem = preparedItem;
            this.index = index;
        }
    }

    /**
     * Validates receipt requirements before an Expense Claim is persisted.
     *
     * The server-applied Receipt_Required__c policy determines whether a
     * receipt must exist. Client-supplied receipt upload keys are also
     * validated before they are trusted for correlation.
     *
     * @param requestItems Claimant-supplied expense item DTOs.
     * @param preparedItems Expense items after policy application.
     */
    public static void validate(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> preparedItems
    ) {
        validateAlignedItems(
            requestItems,
            preparedItems
        );

        Set<String> requiredKeys =
            collectRequiredKeys(
                requestItems,
                preparedItems
            );

        if (requiredKeys.isEmpty()) {
            return;
        }

        Set<String> existingKeys =
            findExistingReceiptKeys(
                requiredKeys
            );

        validateRequiredKeysExist(
            requestItems,
            preparedItems,
            existingKeys
        );
    }

    /**
     * Validates receipt correlation data before uploaded files are linked to
     * persisted Expense Items.
     *
     * @param requestItems Claimant-supplied expense item DTOs.
     * @param insertedItems Persisted expense items in matching list order.
     */
    public static void validateForLinking(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> insertedItems
    ) {
        validateAlignedItems(
            requestItems,
            insertedItems
        );

        validateUploadKeys(
            requestItems
        );
    }

    private static void validateUploadKeys(
        List<ExpenseItemDto> requestItems
    ) {
        for (
            Integer index = 0;
            index < requestItems.size();
            index++
        ) {
            String uploadKey =
                normalizeUploadKey(
                    requestItems[index].receiptUploadKey
                );

            validateProvidedUploadKey(
                uploadKey,
                index
            );
        }
    }

    private static Set<String> collectRequiredKeys(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> preparedItems
    ) {
        Set<String> requiredKeys =
            new Set<String>();

        for (
            Integer index = 0;
            index < preparedItems.size();
            index++
        ) {
            ReceiptValidationContext context =
                new ReceiptValidationContext(
                    requestItems[index],
                    preparedItems[index],
                    index
                );

            String uploadKey =
                normalizeUploadKey(
                    context.requestItem.receiptUploadKey
                );

            validateProvidedUploadKey(
                uploadKey,
                context.index
            );

            addRequiredKey(
                requiredKeys,
                uploadKey,
                context
            );
        }

        return requiredKeys;
    }

    private static void addRequiredKey(
        Set<String> requiredKeys,
        String uploadKey,
        ReceiptValidationContext context
    ) {
        if (
            context.preparedItem.Receipt_Required__c !=
            true
        ) {
            return;
        }

        if (String.isBlank(uploadKey)) {
            throw new ExpenseReceiptService.ExpenseReceiptException(
                    requiredReceiptMessage(
                        context.index
                    )
                );
        }

        requiredKeys.add(
            uploadKey
        );
    }

    private static void validateRequiredKeysExist(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> preparedItems,
        Set<String> existingKeys
    ) {
        for (
            Integer index = 0;
            index < preparedItems.size();
            index++
        ) {
            ReceiptValidationContext context =
                new ReceiptValidationContext(
                    requestItems[index],
                    preparedItems[index],
                    index
                );

            validateRequiredKeyExists(
                context,
                existingKeys
            );
        }
    }

    private static void validateRequiredKeyExists(
        ReceiptValidationContext context,
        Set<String> existingKeys
    ) {
        if (
            context.preparedItem.Receipt_Required__c !=
            true
        ) {
            return;
        }

        String uploadKey =
            normalizeUploadKey(
                context.requestItem.receiptUploadKey
            );

        if (
            existingKeys.contains(
                uploadKey
            )
        ) {
            return;
        }

        throw new ExpenseReceiptService.ExpenseReceiptException(
                requiredReceiptMessage(
                    context.index
                )
            );
    }

    private static Set<String> findExistingReceiptKeys(
        Set<String> uploadKeys
    ) {
        Set<String> existingKeys =
            new Set<String>();

        for (
            ContentVersion version : [
                SELECT
                    Expense_Receipt_Key_fileupload__c
                FROM ContentVersion
                WHERE
                    IsLatest = true
                    AND Expense_Receipt_Key_fileupload__c
                        IN :uploadKeys
                WITH SYSTEM_MODE
            ]
        ) {
            existingKeys.add(
                normalizeUploadKey(
                    version.Expense_Receipt_Key_fileupload__c
                )
            );
        }

        return existingKeys;
    }

    private static void validateAlignedItems(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> expenseItems
    ) {
        if (
            requestItems == null ||
            expenseItems == null
        ) {
            throwMismatchException();
        }

        if (
            requestItems.size() !=
            expenseItems.size()
        ) {
            throwMismatchException();
        }

        validateItemsPresent(
            requestItems,
            expenseItems
        );
    }

    private static void validateItemsPresent(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> expenseItems
    ) {
        for (
            Integer index = 0;
            index < requestItems.size();
            index++
        ) {
            if (
                requestItems[index] ==
                    null ||
                expenseItems[index] ==
                    null
            ) {
                throw new ExpenseReceiptService.ExpenseReceiptException(
                        'Receipt processing could not be completed because an expense item is missing.'
                    );
            }
        }
    }

    private static void validateProvidedUploadKey(
        String uploadKey,
        Integer index
    ) {
        if (String.isBlank(uploadKey)) {
            return;
        }

        if (
            Pattern.matches(
                UPLOAD_KEY_PATTERN,
                uploadKey
            )
        ) {
            return;
        }

        throw new ExpenseReceiptService.ExpenseReceiptException(
                'Invalid receipt upload key for expense ' +
                String.valueOf(
                    index + 1
                ) +
                '.'
            );
    }

    private static String normalizeUploadKey(
        String uploadKey
    ) {
        if (String.isBlank(uploadKey)) {
            return null;
        }

        return uploadKey.trim();
    }

    private static String requiredReceiptMessage(
        Integer index
    ) {
        return (
            'A receipt is required for expense ' +
            String.valueOf(
                index + 1
            ) +
            '.'
        );
    }

    private static void throwMismatchException() {
        throw new ExpenseReceiptService.ExpenseReceiptException(
                'Receipt processing could not be completed because the expense items do not match.'
            );
    }
}