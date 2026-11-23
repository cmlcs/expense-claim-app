/**
 * Manages email verification and short-lived access for unauthenticated
 * Expense Claim users.
 *
 * Guest users never receive direct access to Expense_Claim_Access__c.
 * All access to verification state is mediated through this service.
 */
public without sharing class ExpenseClaimGuestAccessService {

    private static final String STATUS_PENDING =
        'Pending';

    private static final String STATUS_VERIFIED =
        'Verified';

    private static final String STATUS_USED =
        'Used';

    private static final String STATUS_LOCKED =
        'Locked';

    private static final Integer CODE_EXPIRY_MINUTES =
        10;

    private static final Integer ACCESS_EXPIRY_MINUTES =
        30;

    private static final Integer RESEND_COOLDOWN_SECONDS =
        60;

    private static final Integer MAX_VERIFICATION_ATTEMPTS =
        5;

    private static final Integer MAX_CODE_SENDS =
        5;

    /**
     * Exception representing an invalid or expired guest access operation.
     */
    public class GuestAccessException extends Exception {
    }

    /**
     * Contains validated guest-access identity.
     */
    public class AccessContext {

        /**
         * Expense Claim Access record ID.
         */
        public Id accessId { get; private set; }

        /**
         * Contact verified for this guest session.
         */
        public Id contactId { get; private set; }

        /**
         * Name of the verified claimant.
         */
        public String claimantName { get; private set; }

        /**
         * Email address of the verified claimant.
         */
        public String claimantEmail { get; private set; }

        /**
         * Creates a validated guest access context.
         *
         * @param accessRecord Verified Expense Claim Access record.
         */
        private AccessContext(
            Expense_Claim_Access__c accessRecord
        ) {
            this.accessId =
                accessRecord.Id;

            this.contactId =
                accessRecord.Contact__c;

            this.claimantName =
                accessRecord.Contact__r.Name;

            this.claimantEmail =
                accessRecord.Contact__r.Email;
        }
    }

    /**
     * Holds a newly generated verification code after its hashed
     * representation has been persisted.
     */
    private class VerificationCodeResult {

        /**
         * Clear-text verification code retained only for email delivery.
         */
        private String code;

        /**
         * Creates a verification-code result.
         *
         * @param code Clear-text code retained only for email delivery.
         */
        private VerificationCodeResult(
            String code
        ) {
            this.code =
                code;
        }
    }

    /**
     * Requests a verification code for an email address.
     *
     * No indication is returned about whether the email matched a Contact.
     * The guest-facing controller should always return the same generic
     * response to prevent Contact enumeration.
     *
     * @param email Email address supplied by the claimant.
     */
    public static void requestVerification(
        String email
    ) {
        String normalizedEmail =
            ExpenseClaimGuestSecurity.normalizeEmail(
                email
            );

        if (String.isBlank(normalizedEmail)) {
            return;
        }

        List<Contact> contacts =
            ExpenseClaimGuestAccessRepository.findContacts(
                normalizedEmail
            );

        if (contacts.size() != 1) {
            return;
        }

        Contact contact =
            contacts[0];

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                normalizedEmail
            );

        Expense_Claim_Access__c accessRecord =
            ExpenseClaimGuestAccessRepository.findReusableAccess(
                emailHash
            );

        if (
            accessRecord != null &&
            accessRecord.Status__c == STATUS_LOCKED
        ) {
            return;
        }

        if (
            accessRecord != null &&
            shouldThrottleRequest(
                accessRecord
            )
        ) {
            return;
        }

        if (accessRecord == null) {
            accessRecord =
                createPendingAccess(
                    contact,
                    emailHash
                );
        } else {
            accessRecord.Contact__c =
                contact.Id;
        }

        if (
            hasReachedMaximumSends(
                accessRecord
            )
        ) {
            lockAccess(
                accessRecord
            );

            return;
        }

        VerificationCodeResult codeResult =
            issueVerificationCode(
                accessRecord
            );

        sendVerificationEmail(
            contact.Email,
            codeResult.code
        );
    }

    /**
     * Verifies an emailed code and issues a short-lived access token.
     *
     * @param email Email address originally used to request verification.
     * @param verificationCode Six-digit verification code.
     * @return High-entropy access token. Only its hash is stored.
     */
    public static String verifyCode(
        String email,
        String verificationCode
    ) {
        String normalizedEmail =
            ExpenseClaimGuestSecurity.normalizeEmail(
                email
            );

        String normalizedCode =
            ExpenseClaimGuestSecurity.normalizeVerificationCode(
                verificationCode
            );

        if (
            String.isBlank(normalizedEmail) ||
            String.isBlank(normalizedCode)
        ) {
            throw invalidVerificationException();
        }

        String emailHash =
            ExpenseClaimGuestSecurity.hashValue(
                normalizedEmail
            );

        Expense_Claim_Access__c accessRecord =
            ExpenseClaimGuestAccessRepository.findPendingAccess(
                emailHash,
                MAX_VERIFICATION_ATTEMPTS
            );

        if (accessRecord == null) {
            throw invalidVerificationException();
        }

        String expectedHash =
            ExpenseClaimGuestSecurity.hashVerificationCode(
                normalizedCode,
                accessRecord.Verification_Salt__c
            );

        if (
            expectedHash !=
            accessRecord.Verification_Code_Hash__c
        ) {
            registerFailedAttempt(
                accessRecord
            );

            throw invalidVerificationException();
        }

        return grantAccess(
            accessRecord
        );
    }

    /**
     * Validates a previously issued guest access token.
     *
     * @param accessToken Browser-held guest access token.
     * @return Validated server-side identity context.
     */
    public static AccessContext validateAccessToken(
        String accessToken
    ) {
        String normalizedToken =
            ExpenseClaimGuestSecurity.normalizeAccessToken(
                accessToken
            );

        if (String.isBlank(normalizedToken)) {
            throw invalidAccessException();
        }

        String tokenHash =
            ExpenseClaimGuestSecurity.hashValue(
                normalizedToken
            );

        Expense_Claim_Access__c accessRecord =
            ExpenseClaimGuestAccessRepository.findVerifiedAccess(
                tokenHash
            );

        if (accessRecord == null) {
            throw invalidAccessException();
        }

        return new AccessContext(
            accessRecord
        );
    }

    /**
     * Marks a successfully consumed guest session as used.
     *
     * @param accessId Expense Claim Access record ID.
     */
    public static void markUsed(
        Id accessId
    ) {
        if (accessId == null) {
            throw invalidAccessException();
        }

        Expense_Claim_Access__c accessRecord =
            ExpenseClaimGuestAccessRepository.findVerifiedAccessById(
                accessId
            );

        if (accessRecord == null) {
            throw invalidAccessException();
        }

        accessRecord.Status__c =
            STATUS_USED;

        accessRecord.Access_Token_Hash__c =
            null;

        accessRecord.Access_Expires_At__c =
            null;

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );
    }

    /**
     * Creates a new pending guest access request.
     *
     * @param contact Matching Contact.
     * @param emailHash Hash of the normalized email.
     * @return New unsaved access record.
     */
    private static Expense_Claim_Access__c createPendingAccess(
        Contact contact,
        String emailHash
    ) {
        return new Expense_Claim_Access__c(
            Contact__c =
                contact.Id,
            Email_Hash__c =
                emailHash,
            Status__c =
                STATUS_PENDING,
            Verification_Attempts__c =
                0,
            Code_Send_Count__c =
                0
        );
    }

    /**
     * Determines whether another verification-code request should
     * currently be throttled.
     *
     * @param accessRecord Existing pending access request.
     * @return True when the resend cooldown is still active.
     */
    private static Boolean shouldThrottleRequest(
        Expense_Claim_Access__c accessRecord
    ) {
        if (
            accessRecord.Last_Code_Sent_At__c == null
        ) {
            return false;
        }

        Datetime resendAllowedAt =
            accessRecord.Last_Code_Sent_At__c.addSeconds(
                RESEND_COOLDOWN_SECONDS
            );

        return System.now() <
            resendAllowedAt;
    }

    /**
     * Determines whether the maximum number of codes has been issued.
     *
     * @param accessRecord Pending access request.
     * @return True when no further codes should be issued.
     */
    private static Boolean hasReachedMaximumSends(
        Expense_Claim_Access__c accessRecord
    ) {
        Integer sendCount =
            ExpenseClaimGuestSecurity.integerValue(
                accessRecord.Code_Send_Count__c
            );

        return sendCount >=
            MAX_CODE_SENDS;
    }

    /**
     * Locks an access request after its code-send limit is reached.
     *
     * @param accessRecord Access request to lock.
     */
    private static void lockAccess(
        Expense_Claim_Access__c accessRecord
    ) {
        accessRecord.Status__c =
            STATUS_LOCKED;

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );
    }

    /**
     * Generates and persists a new verification code and salt.
     *
     * Only the salted hash is persisted. The clear-text code is returned
     * in a private wrapper solely so it can be sent in the same transaction.
     *
     * @param accessRecord Pending access request.
     * @return Newly generated clear-text verification code wrapper.
     */
    private static VerificationCodeResult issueVerificationCode(
        Expense_Claim_Access__c accessRecord
    ) {
        String verificationCode =
            ExpenseClaimGuestSecurity.generateVerificationCode();

        String salt =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        accessRecord.Verification_Salt__c =
            salt;

        accessRecord.Verification_Code_Hash__c =
            ExpenseClaimGuestSecurity.hashVerificationCode(
                verificationCode,
                salt
            );

        accessRecord.Verification_Expires_At__c =
            System.now().addMinutes(
                CODE_EXPIRY_MINUTES
            );

        accessRecord.Verification_Attempts__c =
            0;

        accessRecord.Last_Code_Sent_At__c =
            System.now();

        accessRecord.Code_Send_Count__c =
            ExpenseClaimGuestSecurity.integerValue(
                accessRecord.Code_Send_Count__c
            ) + 1;

        accessRecord.Status__c =
            STATUS_PENDING;

        accessRecord.Access_Token_Hash__c =
            null;

        accessRecord.Access_Expires_At__c =
            null;

        accessRecord.Verified_At__c =
            null;

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        return new VerificationCodeResult(
            verificationCode
        );
    }

    /**
     * Grants verified guest access and invalidates the one-time code.
     *
     * @param accessRecord Successfully verified access request.
     * @return Browser-held high-entropy access token.
     */
    private static String grantAccess(
        Expense_Claim_Access__c accessRecord
    ) {
        String accessToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        accessRecord.Access_Token_Hash__c =
            ExpenseClaimGuestSecurity.hashValue(
                accessToken
            );

        accessRecord.Access_Expires_At__c =
            System.now().addMinutes(
                ACCESS_EXPIRY_MINUTES
            );

        accessRecord.Verified_At__c =
            System.now();

        accessRecord.Status__c =
            STATUS_VERIFIED;

        accessRecord.Verification_Code_Hash__c =
            null;

        accessRecord.Verification_Salt__c =
            null;

        accessRecord.Verification_Expires_At__c =
            null;

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        return accessToken;
    }

    /**
     * Registers an invalid verification-code attempt.
     *
     * @param accessRecord Pending access request.
     */
    private static void registerFailedAttempt(
        Expense_Claim_Access__c accessRecord
    ) {
        Integer attempts =
            ExpenseClaimGuestSecurity.integerValue(
                accessRecord.Verification_Attempts__c
            ) + 1;

        accessRecord.Verification_Attempts__c =
            attempts;

        if (
            attempts >= MAX_VERIFICATION_ATTEMPTS
        ) {
            accessRecord.Status__c =
                STATUS_LOCKED;
        }

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );
    }

    /**
     * Sends a verification code to the matched Contact.
     *
     * @param email Recipient email address.
     * @param verificationCode Clear-text one-time verification code.
     */
    private static void sendVerificationEmail(
        String email,
        String verificationCode
    ) {
        Messaging.SingleEmailMessage message =
            new Messaging.SingleEmailMessage();

        message.setToAddresses(
            new List<String>{
                email
            }
        );

        message.setSubject(
            'Your Expense Claim verification code'
        );

        message.setPlainTextBody(
            'Your Expense Claim verification code is ' +
            verificationCode +
            '.\n\n' +
            'This code expires in ' +
            String.valueOf(
                CODE_EXPIRY_MINUTES
            ) +
            ' minutes.\n\n' +
            'If you did not request this code, you can ignore this email.'
        );

        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{
                message
            }
        );
    }

    /**
     * Creates the generic verification failure exception.
     *
     * @return Guest access exception.
     */
    private static GuestAccessException invalidVerificationException() {
        return new GuestAccessException(
            'The verification code is invalid or has expired.'
        );
    }

    /**
     * Creates the generic invalid-session exception.
     *
     * @return Guest access exception.
     */
    private static GuestAccessException invalidAccessException() {
        return new GuestAccessException(
            'The guest access session is invalid or has expired.'
        );
    }
}