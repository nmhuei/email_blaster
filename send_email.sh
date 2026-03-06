#!/usr/bin/env bash
# =============================================================================
#  📧  EMAIL BLASTER - Gửi email tự động hàng loạt
#  Bash + curl + SendGrid | HTML | Đính kèm | Log màu sắc
# =============================================================================

set -euo pipefail

# ─── CẤU HÌNH ────────────────────────────────────────────────────────────────

SENDGRID_API_KEY="SG.xxxxxxxxxxxxxxxxxxxx"   # ← Thay bằng API key SendGrid
SENDER_EMAIL="you@example.com"               # ← Email đã verify trên SendGrid
SENDER_NAME="Tên của bạn"

RECIPIENTS_FILE="recipients.txt"
ATTACHMENT_FILE=""
EMAIL_SUBJECT="Thông báo quan trọng từ ${SENDER_NAME}"
DELAY_SECONDS=1
LOG_FILE="email_log_$(date +%Y%m%d_%H%M%S).txt"

# ─── PALETTE MÀU SẮC ─────────────────────────────────────────────────────────

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
ORANGE='\033[38;5;214m'
PINK='\033[38;5;213m'
LIME='\033[38;5;154m'
SKY='\033[38;5;81m'
GOLD='\033[38;5;220m'
CORAL='\033[38;5;203m'
PURPLE='\033[38;5;141m'

BG_GREEN='\033[48;5;22m'
BG_RED='\033[48;5;88m'
BG_BLUE='\033[48;5;19m'

BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
RESET='\033[0m'

# ─── ASCII BANNER ─────────────────────────────────────────────────────────────

print_banner() {
  echo -e "${RESET}"
  echo -e "${SKY}  ███████╗███╗   ███╗ █████╗ ██╗██╗     ${RESET}"
  echo -e "${SKY}  ██╔════╝████╗ ████║██╔══██╗██║██║     ${RESET}"
  echo -e "${PINK}  █████╗  ██╔████╔██║███████║██║██║     ${RESET}"
  echo -e "${PINK}  ██╔══╝  ██║╚██╔╝██║██╔══██║██║██║     ${RESET}"
  echo -e "${CORAL}  ███████╗██║ ╚═╝ ██║██║  ██║██║███████╗${RESET}"
  echo -e "${CORAL}  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚══════╝${RESET}"
  echo -e "${GOLD}        ██████╗ ██╗      █████╗ ███████╗████████╗███████╗██████╗ ${RESET}"
  echo -e "${GOLD}        ██╔══██╗██║     ██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗${RESET}"
  echo -e "${LIME}        ██████╔╝██║     ███████║███████╗   ██║   █████╗  ██████╔╝${RESET}"
  echo -e "${LIME}        ██╔══██╗██║     ██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗${RESET}"
  echo -e "${ORANGE}        ██████╔╝███████╗██║  ██║███████║   ██║   ███████╗██║  ██║${RESET}"
  echo -e "${ORANGE}        ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝${RESET}"
  echo ""
  echo -e "  ${DIM}${W}v1.0  •  Bash + SendGrid  •  Made with ${R}♥${W} in Vietnam${RESET}"
  echo ""
}

# ─── DIVIDERS ─────────────────────────────────────────────────────────────────

divider()      { echo -e "${DIM}${SKY}  ════════════════════════════════════════════════════════${RESET}"; }
thin_divider() { echo -e "${DIM}  ────────────────────────────────────────────────────────${RESET}"; }

# ─── SPINNER ──────────────────────────────────────────────────────────────────

SPINNER_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_COLORS=("$SKY" "$PINK" "$LIME" "$GOLD" "$ORANGE" "$CORAL" "$PURPLE")
_spinner_pid=""

start_spinner() {
  local msg="${1:-Đang xử lý...}"
  ( local i=0 c=0
    while true; do
      local color="${SPINNER_COLORS[$((c % ${#SPINNER_COLORS[@]}))]}"
      printf "\r  ${color}${SPINNER_CHARS[$((i % 10))]}${RESET}  ${W}${msg}${RESET}   "
      sleep 0.08
      (( i++ )) || true; (( c++ )) || true
    done
  ) &
  _spinner_pid=$!
}

stop_spinner() {
  if [[ -n "${_spinner_pid}" ]]; then
    kill "${_spinner_pid}" 2>/dev/null || true
    wait "${_spinner_pid}" 2>/dev/null || true
    _spinner_pid=""
    printf "\r\033[K"
  fi
}

# ─── PROGRESS BAR ─────────────────────────────────────────────────────────────

draw_progress() {
  local current="$1" total="$2"
  local width=42
  local pct=$(( current * 100 / total ))
  local filled=$(( current * width / total ))

  local bar_color
  if   (( pct < 34 )); then bar_color="${CORAL}"
  elif (( pct < 67 )); then bar_color="${GOLD}"
  else                       bar_color="${LIME}"; fi

  local bar_filled="" bar_empty=""
  for (( i=0; i<filled; i++ )); do bar_filled+="█"; done
  for (( i=filled; i<width; i++ )); do bar_empty+="░"; done

  printf "\r  ${DIM}[${RESET}${bar_color}${bar_filled}${RESET}${DIM}${bar_empty}]${RESET}"
  printf " ${BOLD}${W}%3d%%${RESET} ${DIM}(%d/%d)${RESET}" "${pct}" "${current}" "${total}"
}

# ─── LOGGING ──────────────────────────────────────────────────────────────────

log_to_file() { echo "$(date '+%Y-%m-%d %H:%M:%S')  [$1]  ${*:2}" >> "${LOG_FILE}"; }

log_ok()      { echo -e "    ${BG_GREEN}${W} ✔ OK ${RESET}  ${LIME}${BOLD}$*${RESET}";   log_to_file "OK"   "$*"; }
log_fail()    { echo -e "    ${BG_RED}${W} ✘ FAIL ${RESET}  ${CORAL}${BOLD}$*${RESET}"; log_to_file "FAIL" "$*"; }
log_info()    { echo -e "  ${SKY}ℹ${RESET}  ${W}$*${RESET}";                             log_to_file "INFO" "$*"; }
log_warn()    { echo -e "  ${GOLD}⚠${RESET}  ${Y}$*${RESET}";                            log_to_file "WARN" "$*"; }

log_section() {
  echo ""
  echo -e "  ${PINK}◆${RESET} ${BOLD}${W}$*${RESET}"
  thin_divider
}

# ─── HTML EMAIL ───────────────────────────────────────────────────────────────

build_html_body() {
  local name="$1" email="$2" company="$3"
  local year; year=$(date +%Y)
  cat <<HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body{font-family:Arial,sans-serif;color:#333;line-height:1.7;margin:0;background:#f0f4ff}
    .wrap{max-width:600px;margin:32px auto;border-radius:12px;overflow:hidden;
          box-shadow:0 8px 32px rgba(0,0,0,.15)}
    .hdr{background:linear-gradient(135deg,#1d4ed8,#7c3aed);color:#fff;padding:32px;text-align:center}
    .hdr h2{margin:0 0 6px;font-size:24px}
    .hdr p{margin:0;opacity:.85;font-size:14px}
    .body{background:#fff;padding:32px}
    .body p{margin:0 0 16px}
    .highlight{background:#eff6ff;border-left:4px solid #3b82f6;padding:12px 16px;
               border-radius:0 8px 8px 0;margin:16px 0;font-style:italic}
    .btn{display:inline-block;background:linear-gradient(135deg,#1d4ed8,#7c3aed);
         color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;
         font-weight:bold;margin-top:8px}
    .ftr{background:#f8fafc;padding:16px 32px;font-size:12px;color:#94a3b8;
         text-align:center;border-top:1px solid #e2e8f0}
    .tag{display:inline-block;background:#eff6ff;color:#3b82f6;padding:2px 10px;
         border-radius:20px;font-size:12px;font-weight:bold;margin:0 4px}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hdr">
      <h2>📧 Xin chào, ${name}!</h2>
      <p>Đây là tin nhắn từ <strong>${SENDER_NAME}</strong></p>
    </div>
    <div class="body">
      <p>Kính gửi <strong>${name}</strong>,</p>
      <p>Cảm ơn bạn đã quan tâm đến chúng tôi.</p>
      <div class="highlight">
        Công ty <strong>${company}</strong> của bạn đã được ghi nhận thành công trong hệ thống.
      </div>
      <!-- ✏️  CHỈNH SỬA NỘI DUNG EMAIL TẠI ĐÂY -->
      <p>Nội dung chính của bạn viết ở đây...</p>
      <p>
        <span class="tag">📌 Quan trọng</span>
        <span class="tag">✅ Đã xác nhận</span>
      </p>
      <a class="btn" href="https://example.com">🚀 Tìm hiểu thêm</a>
    </div>
    <div class="ftr">
      Email gửi đến: <em>${email}</em> &nbsp;|&nbsp; © ${year} ${SENDER_NAME}
    </div>
  </div>
</body>
</html>
HTML
}

# ─── ĐÍNH KÈM FILE ────────────────────────────────────────────────────────────

build_attachment_json() {
  local file="$1"
  if [[ -z "${file}" || ! -f "${file}" ]]; then echo "[]"; return; fi
  local filename; filename=$(basename "${file}")
  local mime; mime=$(file --mime-type -b "${file}" 2>/dev/null || echo "application/octet-stream")
  local b64; b64=$(base64 -w 0 "${file}")
  echo "[{\"content\":\"${b64}\",\"filename\":\"${filename}\",\"type\":\"${mime}\",\"disposition\":\"attachment\"}]"
}

# ─── GỬI EMAIL QUA SENDGRID ───────────────────────────────────────────────────

send_email() {
  local name="$1" email="$2" company="$3"
  local html_body; html_body=$(build_html_body "${name}" "${email}" "${company}")
  local attachments; attachments=$(build_attachment_json "${ATTACHMENT_FILE}")
  local html_escaped; html_escaped=$(printf '%s' "${html_body}" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))')

  local payload="{
    \"personalizations\":[{\"to\":[{\"email\":\"${email}\",\"name\":\"${name}\"}]}],
    \"from\":{\"email\":\"${SENDER_EMAIL}\",\"name\":\"${SENDER_NAME}\"},
    \"subject\":\"${EMAIL_SUBJECT}\",
    \"content\":[{\"type\":\"text/html\",\"value\":${html_escaped}}],
    \"attachments\":${attachments}
  }"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --request POST \
    --url "https://api.sendgrid.com/v3/mail/send" \
    --header "Authorization: Bearer ${SENDGRID_API_KEY}" \
    --header "Content-Type: application/json" \
    --data "${payload}")

  [[ "${http_code}" == "202" ]]
}

# ─── KIỂM TRA MÔI TRƯỜNG ─────────────────────────────────────────────────────

check_requirements() {
  log_section "Kiểm tra môi trường"
  local ok=true

  if command -v curl &>/dev/null; then
    log_ok "curl    $(curl --version | head -1 | awk '{print $2}')"
  else
    log_fail "curl chưa cài — sudo apt install curl"; ok=false
  fi

  if command -v python3 &>/dev/null; then
    log_ok "python3 $(python3 --version | awk '{print $2}')"
  else
    log_fail "python3 chưa cài — sudo apt install python3"; ok=false
  fi

  if [[ -f "${RECIPIENTS_FILE}" ]]; then
    local count; count=$(grep -vc '^[[:space:]]*#\|^[[:space:]]*$' "${RECIPIENTS_FILE}" 2>/dev/null || echo 0)
    log_ok "Danh sách: ${RECIPIENTS_FILE} ${DIM}(${count} người nhận)${RESET}"
  else
    log_fail "Không tìm thấy: ${RECIPIENTS_FILE}"; ok=false
  fi

  if [[ "${SENDGRID_API_KEY}" == SG.xxx* ]]; then
    log_fail "SENDGRID_API_KEY chưa cấu hình!"; ok=false
  else
    log_ok "SendGrid API Key ${DIM}${SENDGRID_API_KEY:0:12}...${RESET}"
  fi

  if [[ -n "${ATTACHMENT_FILE}" ]]; then
    if [[ -f "${ATTACHMENT_FILE}" ]]; then
      local size; size=$(du -h "${ATTACHMENT_FILE}" | cut -f1)
      log_ok "Đính kèm: $(basename "${ATTACHMENT_FILE}") ${DIM}(${size})${RESET}"
    else
      log_warn "File đính kèm không tồn tại: ${ATTACHMENT_FILE}"
    fi
  else
    log_info "Không có file đính kèm"
  fi

  echo ""
  if [[ "${ok}" == "false" ]]; then
    echo -e "  ${CORAL}${BOLD}✘  Có lỗi cấu hình! Vui lòng kiểm tra lại.${RESET}"; exit 1
  fi
}

# ─── IN CẤU HÌNH ─────────────────────────────────────────────────────────────

print_config() {
  log_section "Cấu hình"
  echo -e "  ${DIM}Người gửi  :${RESET}  ${BOLD}${W}${SENDER_NAME}${RESET}  ${DIM}<${SENDER_EMAIL}>${RESET}"
  echo -e "  ${DIM}Tiêu đề    :${RESET}  ${ITALIC}${GOLD}${EMAIL_SUBJECT}${RESET}"
  echo -e "  ${DIM}Dịch vụ    :${RESET}  ${SKY}SendGrid API v3${RESET}"
  echo -e "  ${DIM}File log   :${RESET}  ${PURPLE}${LOG_FILE}${RESET}"
  echo -e "  ${DIM}Delay      :${RESET}  ${DELAY_SECONDS}s giữa các lần gửi"
  echo ""
}

# ─── TỔNG KẾT ─────────────────────────────────────────────────────────────────

print_summary() {
  local total="$1" success="$2" failed="$3" elapsed="$4"

  echo ""; divider
  echo ""
  echo -e "  ${BOLD}${W}📊  KẾT QUẢ CUỐI CÙNG${RESET}"
  echo ""
  echo -e "  ${DIM}Tổng số     :${RESET}  ${BOLD}${W}${total} email${RESET}"
  echo -e "  ${LIME}✔ Thành công:${RESET}  ${BOLD}${LIME}${success}${RESET}"
  if (( failed > 0 )); then
    echo -e "  ${CORAL}✘ Thất bại  :${RESET}  ${BOLD}${CORAL}${failed}${RESET}"
  else
    echo -e "  ${DIM}✘ Thất bại  :  0${RESET}"
  fi
  echo -e "  ${GOLD}⏱ Thời gian :${RESET}  ${elapsed}s"
  echo -e "  ${PURPLE}📄 Log file  :${RESET}  ${PURPLE}${LOG_FILE}${RESET}"
  echo ""

  if (( total > 0 )); then
    local rate=$(( success * 100 / total ))
    local width=44
    local filled=$(( rate * width / 100 ))
    local bar=""
    for (( i=0; i<width; i++ )); do
      if   (( i < filled && rate >= 80 )); then bar+="${LIME}█"
      elif (( i < filled && rate >= 50 )); then bar+="${GOLD}█"
      elif (( i < filled ));               then bar+="${CORAL}█"
      else                                      bar+="${DIM}░"; fi
    done
    echo -e "  ${DIM}Tỉ lệ thành công  ${RESET}${bar}${RESET}  ${BOLD}${rate}%${RESET}"
  fi

  echo ""; divider

  { echo "════════════════════════════════════"
    echo "KẾT QUẢ: Tổng=${total} | OK=${success} | Lỗi=${failed} | ${elapsed}s"
    echo "════════════════════════════════════"; } >> "${LOG_FILE}"
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────

main() {
  clear
  print_banner; divider; echo ""

  check_requirements
  print_config

  local total=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line// }" || "${line}" == \#* ]] && continue
    (( total++ )) || true
  done < "${RECIPIENTS_FILE}"

  if (( total == 0 )); then
    log_warn "Không có địa chỉ nào trong ${RECIPIENTS_FILE}!"; exit 1
  fi

  log_section "Bắt đầu gửi — ${BOLD}${GOLD}${total}${RESET}${W} người nhận"
  echo ""

  local success=0 failed=0 current=0
  local start_time; start_time=$(date +%s)

  while IFS='|' read -r name email company || [[ -n "${name}" ]]; do
    [[ -z "${name// }" || "${name}" == \#* ]] && continue

    name="$(echo "${name}" | xargs)"
    email="$(echo "${email}" | xargs)"
    company="$(echo "${company:-N/A}" | xargs)"
    (( current++ )) || true

    draw_progress "${current}" "${total}"; echo ""
    echo -e "  ${M}▶${RESET}  ${BOLD}${W}${name}${RESET}  ${DIM}${email}${RESET}  ${SKY}[${company}]${RESET}"

    start_spinner "Đang gửi tới ${email}..."
    if send_email "${name}" "${email}" "${company}"; then
      stop_spinner; log_ok "Gửi thành công → ${email}"
      (( success++ )) || true
    else
      stop_spinner; log_fail "Gửi thất bại  → ${email}"
      (( failed++ )) || true
    fi

    (( current < total )) && sleep "${DELAY_SECONDS}"
    echo ""
  done < "${RECIPIENTS_FILE}"

  draw_progress "${total}" "${total}"; echo ""

  local end_time; end_time=$(date +%s)
  print_summary "${total}" "${success}" "${failed}" "$(( end_time - start_time ))"

  (( failed == 0 ))
}

main "$@"
