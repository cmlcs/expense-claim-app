@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimGuestAccessServiceTest {

    private static final String VERIFICATION_CODE =
        '123456';

    @IsTest
    static void requestVerificationCreatesPendingAccess() {
        Contact claimant =
            createContact(
                'volunteer@example.com'
            );

        Test.startTest();

        ExpenseClaimGuestAccessService.requestVerification(
            '  Volunteer@Example.com  '
        );

        Integer emailInvocations =
            Limits.getEmailInvocations();

        Test.stopTest();

        Expense_Claim_Access__c accessRecord = [
            SELECT
                Contact__c,
                Email_Hash__c,
                Verification_Code_Hash__c,
                Verification_Salt__c,
                Verification_Expires_At__c,
                Verification_Attempts__c,
                Last_Code_Sent_At__c,
                Code_Send_Count__c,
                Status__c
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            claimant.Id,
            accessRecord.Contact__c
        );

        System.assertEquals(
            ExpenseClaimGuestSecurity.hashValue(
                'volunteer@example.com'
            ),
            accessRecord.Email_Hash__c
        );

        System.assertEquals(
            'Pending',
            accessRecord.Status__c
        );

        System.assertNotEquals(
            null,
            accessRecord.Verification_Code_Hash__c
        );

        System.assertEquals(
            64,
            accessRecord.Verification_Code_Hash__c.length()
        );

        System.assertNotEquals(
            null,
            accessRecord.Verification_Salt__c
        );

        System.assertNotEquals(
            null,
            accessRecord.Verification_Expires_At__c
        );

        System.assertEquals(
            Decimal.valueOf('0'),
            accessRecord.Verification_Attempts__c
        );

        System.assertEquals(
            Decimal.valueOf('1'),
            accessRecord.Code_Send_Count__c
        );

        System.assertNotEquals(
            null,
            accessRecord.Last_Code_Sent_At__c
        );

        System.assertEquals(
            1,
            emailInvocations,
            'Exactly one verification email should be requested.'
        );
    }

    @IsTest
    static void requestVerificationForUnknownEmailCreatesNothing() {
        Test.startTest();

        ExpenseClaimGuestAccessService.requestVerification(
            'unknown@example.com'
        );

        Integer emailInvocations =
            Limits.getEmailInvocations();

        Test.stopTest();

        Integer accessCount = [
            SELECT COUNT()
            FROM Expense_Claim_Access__c
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            0,
            accessCount
        );

        System.assertEquals(
            0,
            emailInvocations
        );
    }

    @IsTest
    static void repeatedVerificationRequestIsThrottled() {
        Contact claimant =
            createContact(
                'throttle@example.com'
            );

        Test.startTest();

        ExpenseClaimGuestAccessService.requestVerification(
            claimant.Email
        );

        ExpenseClaimGuestAccessService.requestVerification(
            claimant.Email
        );

        Integer emailInvocations =
            Limits.getEmailInvocations();

        Test.stopTest();

        Expense_Claim_Access__c accessRecord = [
            SELECT
                Code_Send_Count__c,
                Status__c
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            Decimal.valueOf('1'),
            accessRecord.Code_Send_Count__c,
            'A throttled request must not issue another code.'
        );

        System.assertEquals(
            'Pending',
            accessRecord.Status__c
        );

        System.assertEquals(
            1,
            emailInvocations,
            'A throttled request must not send another email.'
        );
    }

    @IsTest
    static void lockedRequestDoesNotCreateReplacementAccess() {
        Contact claimant =
            createContact(
                'locked-request@example.com'
            );

        Expense_Claim_Access__c lockedAccess =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        claimant.Email
                    ),
                Status__c =
                    'Locked',
                Verification_Attempts__c =
                    5,
                Code_Send_Count__c =
                    5
            );

        ExpenseClaimGuestAccessRepository.save(
            lockedAccess
        );

        Test.startTest();

        ExpenseClaimGuestAccessService.requestVerification(
            claimant.Email
        );

        Integer emailInvocations =
            Limits.getEmailInvocations();

        Test.stopTest();

        Integer accessCount = [
            SELECT COUNT()
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            accessCount,
            'Locked access must not be bypassed by creating a replacement record.'
        );

        System.assertEquals(
            0,
            emailInvocations
        );
    }

    @IsTest
    static void verifyCodeGrantsAndValidatesAccess() {
        Contact claimant =
            createContact(
                'verified@example.com'
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                VERIFICATION_CODE,
                0
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        Test.startTest();

        String accessToken =
            ExpenseClaimGuestAccessService.verifyCode(
                claimant.Email,
                VERIFICATION_CODE
            );

        ExpenseClaimGuestAccessService.AccessContext context =
            ExpenseClaimGuestAccessService.validateAccessToken(
                accessToken
            );

        Test.stopTest();

        System.assertEquals(
            64,
            accessToken.length()
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                accessToken
            ),
            'Access token should contain 64 hexadecimal characters.'
        );

        System.assertEquals(
            accessRecord.Id,
            context.accessId
        );

        System.assertEquals(
            claimant.Id,
            context.contactId
        );

        System.assertEquals(
            claimant.Name,
            context.claimantName
        );

        System.assertEquals(
            claimant.Email,
            context.claimantEmail
        );

        Expense_Claim_Access__c verifiedRecord = [
            SELECT
                Status__c,
                Access_Token_Hash__c,
                Access_Expires_At__c,
                Verified_At__c,
                Verification_Code_Hash__c,
                Verification_Salt__c,
                Verification_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE Id = :accessRecord.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Verified',
            verifiedRecord.Status__c
        );

        System.assertEquals(
            ExpenseClaimGuestSecurity.hashValue(
                accessToken
            ),
            verifiedRecord.Access_Token_Hash__c
        );

        System.assertNotEquals(
            null,
            verifiedRecord.Access_Expires_At__c
        );

        System.assertNotEquals(
            null,
            verifiedRecord.Verified_At__c
        );

        System.assertEquals(
            null,
            verifiedRecord.Verification_Code_Hash__c
        );

        System.assertEquals(
            null,
            verifiedRecord.Verification_Salt__c
        );

        System.assertEquals(
            null,
            verifiedRecord.Verification_Expires_At__c
        );
    }

    @IsTest
    static void wrongCodeIncrementsVerificationAttempts() {
        Contact claimant =
            createContact(
                'wrong-code@example.com'
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                VERIFICATION_CODE,
                0
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        try {
            ExpenseClaimGuestAccessService.verifyCode(
                claimant.Email,
                '654321'
            );

            System.assert(
                false,
                'Expected a GuestAccessException.'
            );
        } catch (
            ExpenseClaimGuestAccessService.GuestAccessException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'invalid or has expired'
                ),
                exceptionValue.getMessage()
            );
        }

        accessRecord = [
            SELECT
                Verification_Attempts__c,
                Status__c
            FROM Expense_Claim_Access__c
            WHERE Id = :accessRecord.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            Decimal.valueOf('1'),
            accessRecord.Verification_Attempts__c
        );

        System.assertEquals(
            'Pending',
            accessRecord.Status__c
        );
    }

    @IsTest
    static void finalFailedAttemptLocksAccess() {
        Contact claimant =
            createContact(
                'lock@example.com'
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                VERIFICATION_CODE,
                4
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        try {
            ExpenseClaimGuestAccessService.verifyCode(
                claimant.Email,
                '654321'
            );

            System.assert(
                false,
                'Expected a GuestAccessException.'
            );
        } catch (
            ExpenseClaimGuestAccessService.GuestAccessException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'invalid or has expired'
                ),
                exceptionValue.getMessage()
            );
        }

        accessRecord = [
            SELECT
                Verification_Attempts__c,
                Status__c
            FROM Expense_Claim_Access__c
            WHERE Id = :accessRecord.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            Decimal.valueOf('5'),
            accessRecord.Verification_Attempts__c
        );

        System.assertEquals(
            'Locked',
            accessRecord.Status__c
        );
    }

    @IsTest
    static void invalidAccessTokenIsRejected() {
        try {
            ExpenseClaimGuestAccessService.validateAccessToken(
                'not-a-token'
            );

            System.assert(
                false,
                'Expected a GuestAccessException.'
            );
        } catch (
            ExpenseClaimGuestAccessService.GuestAccessException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'invalid or has expired'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void markUsedInvalidatesAccessToken() {
        Contact claimant =
            createContact(
                'used@example.com'
            );

        Expense_Claim_Access__c accessRecord =
            createPendingAccess(
                claimant,
                VERIFICATION_CODE,
                0
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        String accessToken =
            ExpenseClaimGuestAccessService.verifyCode(
                claimant.Email,
                VERIFICATION_CODE
            );

        ExpenseClaimGuestAccessService.AccessContext context =
            ExpenseClaimGuestAccessService.validateAccessToken(
                accessToken
            );

        ExpenseClaimGuestAccessService.markUsed(
            context.accessId
        );

        Expense_Claim_Access__c usedRecord = [
            SELECT
                Status__c,
                Access_Token_Hash__c,
                Access_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE Id = :accessRecord.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Used',
            usedRecord.Status__c
        );

        System.assertEquals(
            null,
            usedRecord.Access_Token_Hash__c
        );

        System.assertEquals(
            null,
            usedRecord.Access_Expires_At__c
        );

        try {
            ExpenseClaimGuestAccessService.validateAccessToken(
                accessToken
            );

            System.assert(
                false,
                'Used access tokens must no longer be valid.'
            );
        } catch (
            ExpenseClaimGuestAccessService.GuestAccessException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'invalid or has expired'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    private static Contact createContact(
        String email
    ) {
        Contact claimant =
            new Contact(
                FirstName =
                    'Guest',
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
        String verificationCode,
        Integer attempts
    ) {
        String normalizedEmail =
            ExpenseClaimGuestSecurity.normalizeEmail(
                claimant.Email
            );

        String salt =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        return new Expense_Claim_Access__c(
            Contact__c =
                claimant.Id,
            Email_Hash__c =
                ExpenseClaimGuestSecurity.hashValue(
                    normalizedEmail
                ),
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
                attempts,
            Last_Code_Sent_At__c =
                System.now(),
            Code_Send_Count__c =
                1,
            Status__c =
                'Pending'
        );
    }
}