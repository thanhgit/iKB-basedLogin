#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

QUESTIONS_FILE="${QUESTIONS_FILE:-$SCRIPT_DIR/questions.json}"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.json}"

command -v jq >/dev/null || {
    echo "ERROR: jq is required"
    exit 1
}

command -v gum >/dev/null || {
    echo "ERROR: gum is required"
    exit 1
}

command -v shuf >/dev/null || {
    echo "ERROR: shuf is required"
    exit 1
}

LOG_FILE=$(jq -r '.logging.file // "./unlock.log"' "$CONFIG_FILE")

mkdir -p "$(dirname "$LOG_FILE")"

# --------------------------------------------------
# Logging
# --------------------------------------------------

log_event() {
    local event="$1"
    local questions="$2"
    local correct="$3"
    local result="$4"

    printf '%s event=%s questions=%s correct=%s result=%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
        "$event" \
        "$questions" \
        "$correct" \
        "$result" \
        >> "$LOG_FILE"
}

# --------------------------------------------------
# Determine current schedule
# --------------------------------------------------

DAY_NUMBER=$(date '+%u')

case "$DAY_NUMBER" in
    1) DAY="monday" ;;
    2) DAY="tuesday" ;;
    3) DAY="wednesday" ;;
    4) DAY="thursday" ;;
    5) DAY="friday" ;;
    6) DAY="saturday" ;;
    7) DAY="sunday" ;;
esac

QUESTION_COUNT=$(
    jq -r \
        --arg day "$DAY" \
        --arg time "$(date '+%H:%M')" '
        .rules[]
        | select(
            (.days | index($day)) != null
            and $time >= .time_from
            and $time <= .time_to
        )
        | .questions
    ' "$CONFIG_FILE" |
    head -n 1
)


if [[ -z "$QUESTION_COUNT" ]]; then
    QUESTION_COUNT=$(jq -r '.default_questions // 3' "$CONFIG_FILE")
fi

# --------------------------------------------------
# Validate question count
# --------------------------------------------------

TOTAL_QUESTIONS=$(jq '.questions | length' "$QUESTIONS_FILE")

if (( QUESTION_COUNT > TOTAL_QUESTIONS )); then
    echo "ERROR: config requests $QUESTION_COUNT questions,"
    echo "but only $TOTAL_QUESTIONS questions exist."
    exit 1
fi

# --------------------------------------------------
# Select random questions
# --------------------------------------------------

mapfile -t QUESTION_IDS < <(
    jq -r '.questions[].id' "$QUESTIONS_FILE" |
        shuf |
        head -n "$QUESTION_COUNT"
)

correct=0
answered=0

CURRENT_TIME=$(date +"%A %d/%m/%Y %H:%M")
gum style \
    --border double \
    --border-foreground 212 \
    --padding "1 2" \
    "DevOps Knowledge Check" \
    "Hiện tại là: $CURRENT_TIME" \
    "=> $QUESTION_COUNT câu hỏi được chọn ngẫu nhiên"

# --------------------------------------------------
# Ask questions
# --------------------------------------------------

for id in "${QUESTION_IDS[@]}"; do

    question=$(jq -c \
        --argjson id "$id" \
        '.questions[] | select(.id == $id)' \
        "$QUESTIONS_FILE")

    text=$(jq -r '.question' <<< "$question")

    mapfile -t options < <(
        jq -r '.options[]' <<< "$question"
    )

    expected=$(jq -r '.answer' <<< "$question")

    echo

    gum style \
        --foreground 212 \
        --bold \
        "$text"

    answer=$(gum choose "${options[@]}")

    ((answered+=1))

    if [[ "$answer" == "$expected" ]]; then
        ((correct+=1))

        gum style \
            --foreground 82 \
            "✓ Chính xác"
    else
        gum style \
            --foreground 196 \
            "✗ Không chính xác"
    fi
done

# --------------------------------------------------
# Authentication result
# --------------------------------------------------

if (( correct == QUESTION_COUNT )); then

    log_event \
        "knowledge_check" \
        "$QUESTION_COUNT" \
        "$correct" \
        "success"

    gum style \
        --border rounded \
        --border-foreground 82 \
        --padding "1 2" \
        "✓ Knowledge check passed"

    exec "${SHELL:-/bin/bash}" -l
fi

# --------------------------------------------------
# Password fallback
# --------------------------------------------------

log_event \
    "knowledge_check" \
    "$QUESTION_COUNT" \
    "$correct" \
    "fallback"

echo

gum style \
    --foreground 214 \
    "Knowledge check chưa hoàn thành."
    
password=$(gum input \
    --password \
    --prompt "Password: ")

# TODO:
# Thay bằng PAM / SSO / Vault / IAM.
#
# Ví dụ prototype:
#
# if authenticate "$password"; then
#     ...
# fi

verify_password() {
    local password="$1"
    local expected="$2"
    local actual

    actual=$(
        printf '%s\n' "$password" |
        openssl passwd -6 -stdin -salt "$(
            printf '%s' "$expected" |
            cut -d '$' -f 3
        )"
    )

    [[ "$actual" == "$expected" ]]
}

PASSWORD_HASH=$(jq -r '.authentication.password_hash' "$CONFIG_FILE")

if verify_password "$password" "$PASSWORD_HASH"; then

    log_event \
        "password_fallback" \
        "$QUESTION_COUNT" \
        "$correct" \
        "success"

    gum style \
        --foreground 82 \
        "✓ Authentication successful"

    # exec "${SHELL:-/bin/bash}" -l
else

    log_event \
        "password_fallback" \
        "$QUESTION_COUNT" \
        "$correct" \
        "failed"

    gum style \
        --foreground 196 \
        "✗ Authentication failed"

    exit 1
fi
