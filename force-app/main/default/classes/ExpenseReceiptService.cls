/**
 * Manages receipt uploads associated with Expense Claim items.
 *
 * Receipt files can be uploaded before an Expense_Item__c record exists.
 * A cryptographically random key stored on ContentVersion correlates each
 * uploaded file with its eventual Expense Item.
 *
 * System-level file access is intentional so the same receipt mechanism can
 * support authenticated users and Experience Cloud guest users.
 */
public without sharing class ExpenseReceiptService {

    /**
     * Exception raised when receipt processing cannot be completed.
     */
    public class ExpenseReceiptException extends Exception {
    }

    /**
     * Holds state used while linking uploaded receipts to Expense Items.
     */
    private class ReceiptLinkContext {
        private Map<String, Id> itemIdByUploadKey;
        private List<ContentDocumentLink> links;
        private List<ContentVersion> consumedVersions;

        /**
         * Creates receipt-linking state.
         *
         * @param itemIdByUploadKey Expense Item IDs keyed by receipt upload key.
         */
        private ReceiptLinkContext(
            Map<String, Id> itemIdByUploadKey
        ) {
            this.itemIdByUploadKey =
                itemIdByUploadKey;

            this.links =
                new List<ContentDocumentLink>();

            this.consumedVersions =
                new List<ContentVersion>();
        }
    }

    /**
     * Creates an opaque receipt upload key suitable for storing on
     * ContentVersion.Expense_Receipt_Key_fileupload__c.
     *
     * @return A cryptographically random 64-character hexadecimal key.
     */
    public static String createUploadKey() {
        return EncodingUtil.convertToHex(
            Crypto.generateAesKey(256)
        );
    }

    /**
     * Validates that receipt requirements are satisfied after server-side
     * expense policy has been applied.
     *
     * @param requestItems Claimant-supplied expense item DTOs.
     * @param preparedItems Expense items after policy application.
     */
    public static void validateReceipts(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> preparedItems
    ) {
        ExpenseReceiptValidator.validate(
            requestItems,
            preparedItems
        );
    }

    /**
     * Links uploaded receipt files to persisted Expense Items.
     *
     * After successful linking, the receipt correlation key is cleared from
     * each matching ContentVersion so the key cannot be reused by another
     * Expense Claim submission.
     *
     * @param requestItems DTOs containing receipt upload keys.
     * @param insertedItems Persisted expense items in matching list order.
     */
    public static void linkReceipts(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> insertedItems
    ) {
        ExpenseReceiptValidator.validateForLinking(
                requestItems,
                insertedItems
            );

        Map<String, Id> itemIdByUploadKey =
            buildItemIdByUploadKey(
                requestItems,
                insertedItems
            );

        if (
            itemIdByUploadKey.isEmpty()
        ) {
            return;
        }

        List<ContentVersion> receiptVersions =
            findReceiptVersions(
                itemIdByUploadKey.keySet()
            );

        if (
            receiptVersions.isEmpty()
        ) {
            return;
        }

        linkAndConsumeReceipts(
            receiptVersions,
            itemIdByUploadKey
        );
    }

    private static Map<String, Id> buildItemIdByUploadKey(
        List<ExpenseItemDto> requestItems,
        List<Expense_Item__c> insertedItems
    ) {
        Map<String, Id> itemIdByUploadKey =
            new Map<String, Id>();

        for (
            Integer index = 0;
            index < requestItems.size();
            index++
        ) {
            String uploadKey =
                normalizeUploadKey(
                    requestItems[index]
                        .receiptUploadKey
                );

            if (String.isBlank(uploadKey)) {
                continue;
            }

            Id expenseItemId =
                insertedItems[index].Id;

            if (expenseItemId == null) {
                throw new ExpenseReceiptException(
                    'Receipt files cannot be linked before the expense item is saved.'
                );
            }

            if (
                itemIdByUploadKey.containsKey(
                    uploadKey
                )
            ) {
                throw new ExpenseReceiptException(
                    'A receipt upload key cannot be reused across expense lines.'
                );
            }

            itemIdByUploadKey.put(
                uploadKey,
                expenseItemId
            );
        }

        return itemIdByUploadKey;
    }

    private static List<ContentVersion> findReceiptVersions(
        Set<String> uploadKeys
    ) {
        return [
            SELECT
                Id,
                ContentDocumentId,
                Expense_Receipt_Key_fileupload__c
            FROM ContentVersion
            WHERE
                IsLatest = true
                AND Expense_Receipt_Key_fileupload__c
                    IN :uploadKeys
            WITH SYSTEM_MODE
        ];
    }

    private static void linkAndConsumeReceipts(
        List<ContentVersion> receiptVersions,
        Map<String, Id> itemIdByUploadKey
    ) {
        ReceiptLinkContext context =
            new ReceiptLinkContext(
                itemIdByUploadKey
            );

        for (
            ContentVersion version :
            receiptVersions
        ) {
            addReceiptLink(
                version,
                context
            );
        }

        persistReceiptLinks(
            context.links
        );

        consumeReceiptKeys(
            context.consumedVersions
        );
    }

    private static void addReceiptLink(
        ContentVersion version,
        ReceiptLinkContext context
    ) {
        String uploadKey =
            normalizeUploadKey(
                version.Expense_Receipt_Key_fileupload__c
            );

        Id expenseItemId =
            context.itemIdByUploadKey.get(
                uploadKey
            );

        if (expenseItemId == null) {
            return;
        }

        context.links.add(
            new ContentDocumentLink(
                ContentDocumentId =
                    version.ContentDocumentId,
                LinkedEntityId =
                    expenseItemId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            )
        );

        context.consumedVersions.add(
            new ContentVersion(
                Id = version.Id,
                Expense_Receipt_Key_fileupload__c =
                    null
            )
        );
    }

    private static void persistReceiptLinks(
        List<ContentDocumentLink> links
    ) {
        if (links.isEmpty()) {
            return;
        }

        Database.insert(
            links,
            AccessLevel.SYSTEM_MODE
        );
    }

    private static void consumeReceiptKeys(
        List<ContentVersion> consumedVersions
    ) {
        if (
            consumedVersions.isEmpty()
        ) {
            return;
        }

        Database.update(
            consumedVersions,
            AccessLevel.SYSTEM_MODE
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
}