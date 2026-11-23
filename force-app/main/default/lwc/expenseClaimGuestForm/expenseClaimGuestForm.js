import { LightningElement } from 'lwc';

import requestVerification from
    '@salesforce/apex/ExpenseClaimGuestController.requestVerification';

import verifyCode from
    '@salesforce/apex/ExpenseClaimGuestController.verifyCode';

const STEP_EMAIL = 'email';
const STEP_CODE = 'code';
const STEP_CLAIM = 'claim';

export default class ExpenseClaimGuestForm extends LightningElement {
    email = '';
    verificationCode = '';
    accessToken;

    step = STEP_EMAIL;

    isRequestingCode = false;
    isVerifyingCode = false;

    requestMessage;
    errorMessage;

    get showEmailStep() {
        return this.step === STEP_EMAIL;
    }

    get showCodeStep() {
        return this.step === STEP_CODE;
    }

    get showClaimStep() {
        return this.step === STEP_CLAIM;
    }

    get requestButtonDisabled() {
        return this.isRequestingCode;
    }

    get verifyButtonDisabled() {
        return (
            this.isVerifyingCode ||
            !this.verificationCode ||
            this.verificationCode.length !== 6
        );
    }

    get requestButtonLabel() {
        return this.isRequestingCode
            ? 'Sending...'
            : 'Send verification code';
    }

    get verifyButtonLabel() {
        return this.isVerifyingCode
            ? 'Verifying...'
            : 'Verify';
    }

    handleEmailChange(event) {
        this.email = event.target.value;
        this.errorMessage = undefined;
    }

    handleCodeChange(event) {
        this.verificationCode =
            (event.target.value || '')
                .replace(/\D/g, '')
                .slice(0, 6);

        this.errorMessage = undefined;
    }

    async handleRequestCode() {
        const emailInput =
            this.template.querySelector(
                '[data-id="email"]'
            );

        if (
            emailInput &&
            !emailInput.reportValidity()
        ) {
            return;
        }

        this.isRequestingCode = true;
        this.errorMessage = undefined;
        this.requestMessage = undefined;

        try {
            this.requestMessage =
                await requestVerification({
                    email: this.email
                });

            this.verificationCode = '';
            this.step = STEP_CODE;
        } catch (error) {
            /*
             * The Apex controller normally returns the same generic
             * message even when verification can't be initiated.
             * This handles transport-level failures.
             */
            this.errorMessage =
                this.getErrorMessage(
                    error,
                    'Unable to request a verification code.'
                );
        } finally {
            this.isRequestingCode = false;
        }
    }

    async handleVerifyCode() {
        const codeInput =
            this.template.querySelector(
                '[data-id="verification-code"]'
            );

        if (
            codeInput &&
            !codeInput.reportValidity()
        ) {
            return;
        }

        this.isVerifyingCode = true;
        this.errorMessage = undefined;

        try {
            this.accessToken =
                await verifyCode({
                    email: this.email,
                    code: this.verificationCode
                });

            this.verificationCode = '';
            this.requestMessage = undefined;
            this.step = STEP_CLAIM;
        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(
                    error,
                    'The verification code could not be validated.'
                );
        } finally {
            this.isVerifyingCode = false;
        }
    }

    async handleResendCode() {
        await this.handleRequestCode();
    }

    handleChangeEmail() {
        this.resetVerification();
    }

    handleReauthenticate() {
        this.resetVerification();
    }

    resetVerification() {
        this.accessToken = undefined;
        this.verificationCode = '';
        this.requestMessage = undefined;
        this.errorMessage = undefined;
        this.step = STEP_EMAIL;
    }

    getErrorMessage(
        error,
        fallbackMessage
    ) {
        return (
            error?.body?.message ||
            error?.message ||
            fallbackMessage
        );
    }
}