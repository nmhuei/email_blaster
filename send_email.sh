#!/usr/bin/env bash
# =============================================================================
#  📧 EMAIL BLASTER - SendGrid bulk mailer (Bash)
#  Features: .env support, CLI args, retries, dry-run, attachment, colored logs
# =============================================================================

set -euo pipefail

# ─── Defaults (can be overridden by .env or CLI) ────────────────────────────
SENDGRID_API_KEY="${SENDGRID_API_KEY:-SG.xxxxxxxxxxxxxxxxxxxx}"
SENDER_EMAIL="${SENDER_EMAIL:-you@example.com}"
SENDER_NAME="${SENDER_NAME:-Tên của bạn}"
RECIPIENTS_FILE="${RECIPIENTS_FILE:-recipients.txt}"
ATTACHMENT_FILE="${ATTACHMENT_FILE:-}"
EMAIL_SUBJECT="${EMAIL_SUBJECT:-Thông báo quan trọng từ ${SENDER_NAME}}"
DELAY_SECONDS="${DELAY_SECONDS:-1}"
MAX_RETRIES="${MAX_RETRIES:-2}"
DRY_RUN=false
TEMPLATE_FILE="${TEMPLATE_FILE:-}"
TEXT_TEMPLATE_FILE="${TEXT_TEMPLATE_FILE:-}"

LOG_FILE="email_log_$(date +%Y%m%d_%H%M%S).txt"

# ─── Colors ──────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; DIM='\033[2m'
RESET='\033[0m'; BOLD='\033[1m'

# ─── Helpers ─────────────────────────────────────────────────────────────────
log_to_file() { echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] ${*:2}" >> "${LOG_FILE}"; }
info()  { echo -e "${C}ℹ${RESET}  $*"; log_to_file INFO "$*"; }
ok()    { echo -e "${G}✔${RESET}  $*"; log_to_file OK "$*"; }
warn()  { echo -e "${Y}⚠${RESET}  $*"; log_to_file WARN "$*"; }
fail()  { echo -e "${R}✘${RESET}  $*"; log_to_file FAIL "$*"; }

usage() {
  cat <<'EOF'
Usage: ./send_email.sh [options]

Options:
  --env FILE               Load variables from env file (default: .env if exists)
  --recipients FILE        Recipients file (default: recipients.txt)
  --subject TEXT           Email subject
  --attachment FILE        Attachment path
  --delay N                Delay seconds between sends (default: 1)
  --retries N              Max retries per recipient (default: 2)
  --sender-email EMAIL     Sender email (verified on SendGrid)
  --sender-name NAME       Sender display name
  --template FILE          HTML template file (supports placeholders)
  --text-template FILE     Plain text template fallback (supports placeholders)
  --dry-run                Do not send, only simulate/log
  -h, --help               Show help
EOF
}

load_env_file() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  info "Loading env: $env_file"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

parse_args() {
  local env_file=".env"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env) env_file="$2"; shift 2 ;;
      --recipients) RECIPIENTS_FILE="$2"; shift 2 ;;
      --subject) EMAIL_SUBJECT="$2"; shift 2 ;;
      --attachment) ATTACHMENT_FILE="$2"; shift 2 ;;
      --delay) DELAY_SECONDS="$2"; shift 2 ;;
      --retries) MAX_RETRIES="$2"; shift 2 ;;
      --sender-email) SENDER_EMAIL="$2"; shift 2 ;;
      --sender-name) SENDER_NAME="$2"; shift 2 ;;
      --template) TEMPLATE_FILE="$2"; shift 2 ;;
      --text-template) TEXT_TEMPLATE_FILE="$2"; shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) fail "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  # Allow overriding defaults from env file after parsing --env
  load_env_file "$env_file"

  # Re-apply CLI overrides from original command line is unnecessary here since
  # we parse linearly; env file should be early via --env for custom behavior.
}

is_valid_email() {
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

build_html_body() {
  local name="$1" email="$2" company="$3" year
  year=$(date +%Y)

  if [[ -n "$TEMPLATE_FILE" ]]; then
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
      fail "Template file not found: $TEMPLATE_FILE"
      return 1
    fi
    local tpl
    tpl="$(cat "$TEMPLATE_FILE")"
    tpl="${tpl//\{\{name\}\}/$name}"
    tpl="${tpl//\{\{email\}\}/$email}"
    tpl="${tpl//\{\{company\}\}/$company}"
    tpl="${tpl//\{\{sender_name\}\}/$SENDER_NAME}"
    tpl="${tpl//\{\{year\}\}/$year}"
    printf '%s' "$tpl"
    return 0
  fi

  cat <<HTML
<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;color:#222;line-height:1.6;">
  <h2>Xin chào ${name},</h2>
  <p>Đây là email từ <strong>${SENDER_NAME}</strong>.</p>
  <p>Thông tin công ty của bạn: <strong>${company}</strong>.</p>
  <p>Nội dung chính của bạn viết ở đây...</p>
  <hr/>
  <small>Gửi tới ${email} • © ${year} ${SENDER_NAME}</small>
</body></html>
HTML
}

build_text_body() {
  local name="$1" email="$2" company="$3" year
  year=$(date +%Y)

  if [[ -n "$TEXT_TEMPLATE_FILE" ]]; then
    if [[ ! -f "$TEXT_TEMPLATE_FILE" ]]; then
      fail "Text template file not found: $TEXT_TEMPLATE_FILE"
      return 1
    fi
    local tpl
    tpl="$(cat "$TEXT_TEMPLATE_FILE")"
    tpl="${tpl//\{\{name\}\}/$name}"
    tpl="${tpl//\{\{email\}\}/$email}"
    tpl="${tpl//\{\{company\}\}/$company}"
    tpl="${tpl//\{\{sender_name\}\}/$SENDER_NAME}"
    tpl="${tpl//\{\{year\}\}/$year}"
    printf '%s' "$tpl"
    return 0
  fi

  cat <<TEXT
Xin chào ${name},

Đây là email từ ${SENDER_NAME}.
Thông tin công ty: ${company}
Nội dung chính của bạn viết ở đây...

Gửi tới ${email}
© ${year} ${SENDER_NAME}
TEXT
}

build_attachment_json() {
  local file="$1"
  if [[ -z "$file" ]]; then echo "[]"; return; fi
  if [[ ! -f "$file" ]]; then warn "Attachment not found: $file"; echo "[]"; return; fi
  local filename mime b64
  filename=$(basename "$file")
  mime=$(file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream")
  b64=$(base64 -w 0 "$file")
  echo "[{\"content\":\"${b64}\",\"filename\":\"${filename}\",\"type\":\"${mime}\",\"disposition\":\"attachment\"}]"
}

send_email() {
  local name="$1" email="$2" company="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] ${name} <${email}> [${company}]"
    return 0
  fi

  local html_body text_body attachments html_escaped text_escaped payload
  html_body=$(build_html_body "$name" "$email" "$company")
  text_body=$(build_text_body "$name" "$email" "$company")
  attachments=$(build_attachment_json "$ATTACHMENT_FILE")
  html_escaped=$(printf '%s' "$html_body" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
  text_escaped=$(printf '%s' "$text_body" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

  payload="{
    \"personalizations\":[{\"to\":[{\"email\":\"${email}\",\"name\":\"${name}\"}]}],
    \"from\":{\"email\":\"${SENDER_EMAIL}\",\"name\":\"${SENDER_NAME}\"},
    \"subject\":\"${EMAIL_SUBJECT}\",
    \"content\":[{\"type\":\"text/plain\",\"value\":${text_escaped}},{\"type\":\"text/html\",\"value\":${html_escaped}}],
    \"attachments\":${attachments}
  }"

  local attempt=0 code
  while (( attempt <= MAX_RETRIES )); do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
      --request POST \
      --url "https://api.sendgrid.com/v3/mail/send" \
      --header "Authorization: Bearer ${SENDGRID_API_KEY}" \
      --header "Content-Type: application/json" \
      --data "$payload")

    if [[ "$code" == "202" ]]; then
      return 0
    fi

    (( attempt++ )) || true
    if (( attempt <= MAX_RETRIES )); then
      warn "Retry ${attempt}/${MAX_RETRIES} for ${email} (HTTP ${code})"
      sleep 1
    fi
  done

  warn "Final HTTP code for ${email}: ${code}"
  return 1
}

check_requirements() {
  command -v curl >/dev/null || { fail "curl missing"; exit 1; }
  command -v python3 >/dev/null || { fail "python3 missing"; exit 1; }

  [[ -f "$RECIPIENTS_FILE" ]] || { fail "Recipients file not found: $RECIPIENTS_FILE"; exit 1; }

  if [[ "$DRY_RUN" != "true" ]]; then
    [[ "$SENDGRID_API_KEY" == SG.* ]] || { fail "Invalid SENDGRID_API_KEY"; exit 1; }
    [[ "$SENDGRID_API_KEY" != SG.x* ]] || { fail "SENDGRID_API_KEY placeholder detected"; exit 1; }
    is_valid_email "$SENDER_EMAIL" || { fail "Invalid SENDER_EMAIL: $SENDER_EMAIL"; exit 1; }
  fi
}

main() {
  parse_args "$@"
  check_requirements

  info "Sender: ${SENDER_NAME} <${SENDER_EMAIL}>"
  info "Recipients: ${RECIPIENTS_FILE}"
  info "Subject: ${EMAIL_SUBJECT}"
  info "Delay: ${DELAY_SECONDS}s | Retries: ${MAX_RETRIES} | Dry-run: ${DRY_RUN}"
  [[ -n "$TEMPLATE_FILE" ]] && info "Template HTML: ${TEMPLATE_FILE}"
  [[ -n "$TEXT_TEMPLATE_FILE" ]] && info "Template text: ${TEXT_TEMPLATE_FILE}"

  local total=0 success=0 failed=0 skipped=0
  local start_ts end_ts
  start_ts=$(date +%s)

  while IFS='|' read -r name email company || [[ -n "${name:-}" ]]; do
    [[ -z "${name// }" || "${name}" == \#* ]] && continue

    name="$(echo "${name}" | xargs)"
    email="$(echo "${email:-}" | xargs)"
    company="$(echo "${company:-N/A}" | xargs)"

    (( total++ )) || true

    if ! is_valid_email "$email"; then
      warn "Skip invalid email: ${email:-<empty>} (${name})"
      (( skipped++ )) || true
      continue
    fi

    if send_email "$name" "$email" "$company"; then
      ok "Sent → ${email}"
      (( success++ )) || true
    else
      fail "Failed → ${email}"
      (( failed++ )) || true
    fi

    sleep "$DELAY_SECONDS"
  done < "$RECIPIENTS_FILE"

  end_ts=$(date +%s)
  echo
  info "Done in $((end_ts - start_ts))s"
  echo -e "${BOLD}${W}Total:${RESET} ${total} | ${G}OK:${success}${RESET} | ${R}Fail:${failed}${RESET} | ${Y}Skipped:${skipped}${RESET}"
  info "Log: ${LOG_FILE}"

  [[ "$failed" -eq 0 ]]
}

main "$@"
