#!/usr/bin/env bash
set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

source "$(\dirname "${BASH_SOURCE[0]}")/utils/domain_validator.sh"
source "$(\dirname "${BASH_SOURCE[0]}")/utils/generate_password.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils/wrapper_manager.sh"

TEST_MAIL_LOGIN='testsupportmail'
MAIL_DESCRIPTION='throwaway mail for troubleshooting purposes. You may delete it at will.'
MAIL_PASSWORD_LENGTH='15'

get_mail_password() {
    if [[ $# -ne 1 ]]; then
        printf "Error: Too many or no arguments provided\n" 1>&2
        exit 1
    fi
    local domain="$1"
    if ! is_valid_domain "$domain"; then
        printf "Error: Invalid input\n" 1>&2
        exit 1
    fi
    /usr/local/psa/admin/bin/mail_auth_view | grep -F "${TEST_MAIL_LOGIN}@${domain}" | tr -d '[:space:]' | cut -d '|' -f4- || true
}

create_testmail() {
    if [[ $# -ne 2 ]]; then
        printf "Error: Too many or no arguments provided\n" 1>&2
        exit 1
    fi
    local domain="$1"
    local password="$2"
    if ! is_valid_domain "$domain"; then
        printf "Error: Invalid input\n" 1>&2
        exit 1
    fi
    plesk bin mail --create "${TEST_MAIL_LOGIN}@${domain}" -passwd "${password}" -mailbox true -description "$MAIL_DESCRIPTION"
}

plesk_get_testmail_credentials() {
    require_wrapper_execution

    if [[ $# -ne 1 ]]; then
        printf "Error: Too many or no arguments provided\n" 1>&2
        exit 1
    fi
    local domain="$1"
    if ! is_valid_domain "$domain"; then
        printf "Error: Invalid input\n" 1>&2
        exit 1
    fi
    local password
    local login_link="https://webmail.${domain}/roundcube/index.php?_user=${TEST_MAIL_LOGIN}%40${domain}"
    local new_email_created=false

    local existing_password
    existing_password="$(get_mail_password "$domain")"
    if [[ -z "$existing_password" ]]; then
        local generated_password
        generated_password="$(generate_password "$MAIL_PASSWORD_LENGTH")"
        create_testmail "$domain" "$generated_password"
        new_email_created=true
        password="$generated_password"
    else
        password="$existing_password"
    fi

    printf '{"login_link": "%s", "password": "%s", "new_email_created": %s}\n' "$login_link" "$password" "$new_email_created"
}

plesk_get_testmail_credentials "$@"
