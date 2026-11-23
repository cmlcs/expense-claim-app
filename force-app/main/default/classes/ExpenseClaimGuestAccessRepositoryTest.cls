@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimGuestAccessRepositoryTest {

    @IsTest
    static void findContactsReturnsMatchingContact() {
        Contact claimant =
            createContact(
                'repository@example.com'
            );

        List<Contact> contacts =
            ExpenseClaimGuestAccessRepository.findContacts(
                'repository@example.com'
            );

        System.assertEquals(
            1,
            contacts.size()
        );

        System.assertEquals(
            claimant.Id,
            contacts[0].Id
        );

        System.assertEquals(
            'repository@example.com',
            contacts[0].Email
        );
    }

    @IsTest
    static void saveInsertsAndUpdatesAccessRecord() {
        Contact claimant =
            createContact(
                'save@example.com'
            );

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        claimant.Email
                    ),
                Status__c =
                    'Pending',
                Verification_Attempts__c =
                    0,
                Code_Send_Count__c =
                    0
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        System.assertNotEquals(
            null,
            accessRecord.Id
        );

        accessRecord.Code_Send_Count__c =
            1;

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c persistedRecord = [
            SELECT
                Code_Send_Count__c
            FROM Expense_Claim_Access__c
            WHERE Id = :accessRecord.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            Decimal.valueOf('1'),
            persistedRecord.Code_Send_Count__c
        );
    }

    @IsTest
    static void findReusableAccessReturnsPendingRecord() {
        Contact claimant =
            createContact(
                'pending@example.com'
            );

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                claimant.Email
            );

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    emailHash,
                Status__c =
                    'Pending',
                Verification_Attempts__c =
                    0,
                Code_Send_Count__c =
                    1
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c result =
            ExpenseClaimGuestAccessRepository.findReusableAccess(
                emailHash
            );

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            accessRecord.Id,
            result.Id
        );

        System.assertEquals(
            'Pending',
            result.Status__c
        );
    }

    @IsTest
    static void findReusableAccessReturnsLockedRecord() {
        Contact claimant =
            createContact(
                'locked@example.com'
            );

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                claimant.Email
            );

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    emailHash,
                Status__c =
                    'Locked',
                Verification_Attempts__c =
                    5,
                Code_Send_Count__c =
                    5
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c result =
            ExpenseClaimGuestAccessRepository.findReusableAccess(
                emailHash
            );

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            accessRecord.Id,
            result.Id
        );

        System.assertEquals(
            'Locked',
            result.Status__c
        );
    }

    @IsTest
    static void findPendingAccessRequiresUsableVerificationState() {
        Contact claimant =
            createContact(
                'verify@example.com'
            );

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                claimant.Email
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                emailHash,
                '123456'
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c result =
            ExpenseClaimGuestAccessRepository.findPendingAccess(
                emailHash,
                5
            );

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            accessRecord.Id,
            result.Id
        );
    }

    @IsTest
    static void findPendingAccessRejectsExpiredVerification() {
        Contact claimant =
            createContact(
                'expired@example.com'
            );

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                claimant.Email
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                emailHash,
                '123456'
            );

        accessRecord.Verification_Expires_At__c =
            System.now().addMinutes(
                -1
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c result =
            ExpenseClaimGuestAccessRepository.findPendingAccess(
                emailHash,
                5
            );

        System.assertEquals(
            null,
            result
        );
    }

    @IsTest
    static void findVerifiedAccessReturnsActiveSession() {
        Contact claimant =
            createContact(
                'active@example.com'
            );

        String token =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        claimant.Email
                    ),
                Status__c =
                    'Verified',
                Access_Token_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        token
                    ),
                Access_Expires_At__c =
                    System.now().addMinutes(
                        30
                    ),
                Verified_At__c =
                    System.now()
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c byToken =
            ExpenseClaimGuestAccessRepository.findVerifiedAccess(
                ExpenseClaimGuestSecurity.hashValue(
                    token
                )
            );

        Expense_Claim_Access__c byId =
            ExpenseClaimGuestAccessRepository.findVerifiedAccessById(
                accessRecord.Id
            );

        System.assertNotEquals(
            null,
            byToken
        );

        System.assertEquals(
            accessRecord.Id,
            byToken.Id
        );

        System.assertEquals(
            claimant.Id,
            byToken.Contact__c
        );

        System.assertEquals(
            claimant.Name,
            byToken.Contact__r.Name
        );

        System.assertEquals(
            claimant.Email,
            byToken.Contact__r.Email
        );

        System.assertNotEquals(
            null,
            byId
        );

        System.assertEquals(
            accessRecord.Id,
            byId.Id
        );
    }

    @IsTest
    static void findVerifiedAccessRejectsExpiredSession() {
        Contact claimant =
            createContact(
                'expired-session@example.com'
            );

        String token =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        claimant.Email
                    ),
                Status__c =
                    'Verified',
                Access_Token_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        token
                    ),
                Access_Expires_At__c =
                    System.now().addMinutes(
                        -1
                    ),
                Verified_At__c =
                    System.now().addMinutes(
                        -30
                    )
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Expense_Claim_Access__c result =
            ExpenseClaimGuestAccessRepository.findVerifiedAccess(
                ExpenseClaimGuestSecurity.hashValue(
                    token
                )
            );

        System.assertEquals(
            null,
            result
        );
    }

    private static Contact createContact(
        String email
    ) {
        Contact claimant =
            new Contact(
                FirstName =
                    'Test',
                LastName =
                    'Volunteer',
                Email =
                    email
            );

        insert claimant;

        return [
            SELECT
                Id,
                Name,
                Email
            FROM Contact
            WHERE Id = :claimant.Id
            LIMIT 1
        ];
    }

    private static Expense_Claim_Access__c createPendingAccess(
        Contact claimant,
        String emailHash,
        String verificationCode
    ) {
        String salt =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        return new Expense_Claim_Access__c(
            Contact__c =
                claimant.Id,
            Email_Hash__c =
                emailHash,
            Status__c =
                'Pending',
            Verification_Code_Hash__c =
                ExpenseClaimGuestSecurity.hashVerificationCode(
                    verificationCode,
                    salt
                ),
            Verification_Salt__c =
                salt,
            Verification_Expires_At__c =
                System.now().addMinutes(
                    10
                ),
            Verification_Attempts__c =
                0,
            Code_Send_Count__c =
                1,
            Last_Code_Sent_At__c =
                System.now()
        );
    }
}