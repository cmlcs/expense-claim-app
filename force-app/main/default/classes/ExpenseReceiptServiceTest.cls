/**
 * Tests receipt upload correlation, validation, and linking.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ExpenseReceiptServiceTest {
    @IsTest
    static void createUploadKeyReturnsRandom64CharacterKey() {
        String firstKey =
            ExpenseReceiptService.createUploadKey();

        String secondKey =
            ExpenseReceiptService.createUploadKey();

        System.assertEquals(
            64,
            firstKey.length(),
            'The upload key should contain 64 hexadecimal characters.'
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                firstKey
            ),
            'The upload key should contain only hexadecimal characters.'
        );

        System.assertNotEquals(
            firstKey,
            secondKey,
            'Separate upload keys should not be identical.'
        );
    }

    @IsTest
    static void validateReceiptsAllowsRequiredReceiptWhenUploaded() {
        String uploadKey =
            ExpenseReceiptService.createUploadKey();

        createReceipt(
            uploadKey,
            'required-receipt.pdf'
        );

        ExpenseItemDto requestItem =
            createRequestItem(
                uploadKey
            );

        Expense_Item__c preparedItem =
            createPreparedItem(
                true
            );

        Test.startTest();

        ExpenseReceiptService.validateReceipts(
                new List<ExpenseItemDto>{
                    requestItem
                },
                new List<Expense_Item__c>{
                    preparedItem
                }
            );

        Test.stopTest();

        System.assertEquals(
            uploadKey,
            requestItem.receiptUploadKey,
            'Receipt validation should not modify the request DTO.'
        );
    }

    @IsTest
    static void validateReceiptsRejectsRequiredReceiptWithoutKey() {
        ExpenseItemDto requestItem =
            createRequestItem(
                null
            );

        Expense_Item__c preparedItem =
            createPreparedItem(
                true
            );

        try {
            Test.startTest();

            ExpenseReceiptService.validateReceipts(
                    new List<ExpenseItemDto>{
                        requestItem
                    },
                    new List<Expense_Item__c>{
                        preparedItem
                    }
                );

            Test.stopTest();

            System.assert(
                false,
                'Expected receipt validation to fail.'
            );
        } catch (
            ExpenseReceiptService.ExpenseReceiptException exceptionValue
        ) {
            System.assertEquals(
                'A receipt is required for expense 1.',
                exceptionValue.getMessage(),
                'The claimant should receive a clear missing-receipt message.'
            );
        }
    }

    @IsTest
    static void validateReceiptsRejectsUnknownUploadKey() {
        String uploadKey =
            ExpenseReceiptService.createUploadKey();

        ExpenseItemDto requestItem =
            createRequestItem(
                uploadKey
            );

        Expense_Item__c preparedItem =
            createPreparedItem(
                true
            );

        try {
            Test.startTest();

            ExpenseReceiptService.validateReceipts(
                    new List<ExpenseItemDto>{
                        requestItem
                    },
                    new List<Expense_Item__c>{
                        preparedItem
                    }
                );

            Test.stopTest();

            System.assert(
                false,
                'Expected receipt validation to fail.'
            );
        } catch (
            ExpenseReceiptService.ExpenseReceiptException exceptionValue
        ) {
            System.assertEquals(
                'A receipt is required for expense 1.',
                exceptionValue.getMessage(),
                'An unknown correlation key should not satisfy the receipt requirement.'
            );
        }
    }

    @IsTest
    static void validateReceiptsAllowsOptionalExpenseWithoutReceipt() {
        ExpenseItemDto requestItem =
            createRequestItem(
                null
            );

        Expense_Item__c preparedItem =
            createPreparedItem(
                false
            );

        Test.startTest();

        ExpenseReceiptService.validateReceipts(
                new List<ExpenseItemDto>{
                    requestItem
                },
                new List<Expense_Item__c>{
                    preparedItem
                }
            );

        Test.stopTest();

        System.assertEquals(
            false,
            preparedItem.Receipt_Required__c,
            'Optional expenses should not require a receipt upload.'
        );
    }

    @IsTest
    static void validateReceiptsRejectsMalformedUploadKey() {
        ExpenseItemDto requestItem =
            createRequestItem(
                'not-a-valid-upload-key'
            );

        Expense_Item__c preparedItem =
            createPreparedItem(
                false
            );

        try {
            Test.startTest();

            ExpenseReceiptService.validateReceipts(
                    new List<ExpenseItemDto>{
                        requestItem
                    },
                    new List<Expense_Item__c>{
                        preparedItem
                    }
                );

            Test.stopTest();

            System.assert(
                false,
                'Expected malformed receipt upload key to be rejected.'
            );
        } catch (
            ExpenseReceiptService.ExpenseReceiptException exceptionValue
        ) {
            System.assertEquals(
                'Invalid receipt upload key for expense 1.',
                exceptionValue.getMessage(),
                'Malformed receipt keys should be rejected even when the receipt is optional.'
            );
        }
    }

    @IsTest
    static void linkReceiptsLinksAllFilesAndConsumesUploadKey() {
        String uploadKey =
            ExpenseReceiptService.createUploadKey();

        ContentVersion firstVersion =
            createReceipt(
                uploadKey,
                'receipt-one.pdf'
            );

        ContentVersion secondVersion =
            createReceipt(
                uploadKey,
                'receipt-two.jpg'
            );

        Expense_Item__c insertedItem =
            createPersistedExpenseItem();

        ExpenseItemDto requestItem =
            createRequestItem(
                uploadKey
            );

        Test.startTest();

        ExpenseReceiptService.linkReceipts(
                new List<ExpenseItemDto>{
                    requestItem
                },
                new List<Expense_Item__c>{
                    insertedItem
                }
            );

        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT
                ContentDocumentId,
                LinkedEntityId,
                ShareType,
                Visibility
            FROM ContentDocumentLink
            WHERE
                LinkedEntityId =
                    :insertedItem.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            2,
            links.size(),
            'Both uploaded receipts should be linked to the expense item.'
        );

        Set<Id> linkedDocumentIds =
            new Set<Id>();

        for (
            ContentDocumentLink link :
            links
        ) {
            linkedDocumentIds.add(
                link.ContentDocumentId
            );

            System.assertEquals(
                insertedItem.Id,
                link.LinkedEntityId,
                'The receipt should be linked to the persisted expense item.'
            );

            System.assertEquals(
                'V',
                link.ShareType,
                'The expense item should receive viewer access to the file.'
            );

            System.assertEquals(
                'AllUsers',
                link.Visibility,
                'Receipt visibility should support internal and external users.'
            );
        }

        System.assert(
            linkedDocumentIds.contains(
                firstVersion.ContentDocumentId
            ),
            'The first receipt should be linked.'
        );

        System.assert(
            linkedDocumentIds.contains(
                secondVersion.ContentDocumentId
            ),
            'The second receipt should be linked.'
        );

        List<ContentVersion> consumedVersions = [
            SELECT
                Expense_Receipt_Key_fileupload__c
            FROM ContentVersion
            WHERE
                Id IN :new Set<Id>{
                    firstVersion.Id,
                    secondVersion.Id
                }
            WITH SYSTEM_MODE
        ];

        for (
            ContentVersion version :
            consumedVersions
        ) {
            System.assertEquals(
                null,
                version.Expense_Receipt_Key_fileupload__c,
                'The correlation key should be cleared after successful linking.'
            );
        }
    }

    @IsTest
    static void linkReceiptsRejectsKeyReusedAcrossExpenseLines() {
        String uploadKey =
            ExpenseReceiptService.createUploadKey();

        ExpenseItemDto firstRequest =
            createRequestItem(
                uploadKey
            );

        ExpenseItemDto secondRequest =
            createRequestItem(
                uploadKey
            );

        Expense_Item__c firstItem =
            createPersistedExpenseItem();

        Expense_Item__c secondItem =
            createPersistedExpenseItem();

        try {
            Test.startTest();

            ExpenseReceiptService.linkReceipts(
                    new List<ExpenseItemDto>{
                        firstRequest,
                        secondRequest
                    },
                    new List<Expense_Item__c>{
                        firstItem,
                        secondItem
                    }
                );

            Test.stopTest();

            System.assert(
                false,
                'Expected duplicate receipt upload key to be rejected.'
            );
        } catch (
            ExpenseReceiptService.ExpenseReceiptException exceptionValue
        ) {
            System.assertEquals(
                'A receipt upload key cannot be reused across expense lines.',
                exceptionValue.getMessage(),
                'One upload key must belong to exactly one expense line.'
            );
        }
    }

    private static ExpenseItemDto createRequestItem(
        String uploadKey
    ) {
        ExpenseItemDto item =
            new ExpenseItemDto();

        item.receiptUploadKey =
            uploadKey;

        return item;
    }

    private static Expense_Item__c createPreparedItem(
        Boolean receiptRequired
    ) {
        return new Expense_Item__c(
            Receipt_Required__c =
                receiptRequired
        );
    }

    private static ContentVersion createReceipt(
        String uploadKey,
        String fileName
    ) {
        ContentVersion version =
            new ContentVersion(
                Title = fileName,
                PathOnClient =
                    fileName,
                VersionData =
                    Blob.valueOf(
                        'Test receipt content'
                    ),
                Expense_Receipt_Key_fileupload__c =
                    uploadKey
            );

        insert version;

        return [
            SELECT
                Id,
                ContentDocumentId,
                Expense_Receipt_Key_fileupload__c
            FROM ContentVersion
            WHERE
                Id = :version.Id
            WITH SYSTEM_MODE
        ];
    }

    private static Expense_Item__c createPersistedExpenseItem() {
        Expense_Claim__c claim =
            new Expense_Claim__c(
                Status__c = 'Draft'
            );

        insert claim;

        Expense_Item__c item =
            new Expense_Item__c(
                Expense_Claim__c =
                    claim.Id,
                Expense_Date__c =
                    Date.today(),
                Expense_Type_Code__c =
                    'Test',
                Expense_Type_Label__c =
                    'Test',
                Calculation_Method__c =
                    'Amount',
                Claimed_Amount__c =
                    Decimal.valueOf('10.00'),
                Receipt_Required__c =
                    true
            );

        insert item;

        return item;
    }
}