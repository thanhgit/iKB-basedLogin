#!/usr/bin/env bash

set -euo pipefail

QUESTIONS_FILE="${QUESTIONS_FILE:-./questions.json}"

# Password fallback.
# Production: lấy từ secret manager, không hard-code vào script.
PASSWORD="${DEVOPS_BYPASS_PASSWORD:-123456}"

if ! command -v gum >/dev/null 2>&1; then
    echo "ERROR: gum chưa được cài đặt."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq chưa được cài đặt."
    exit 1
fi

if [[ ! -f "$QUESTIONS_FILE" ]]; then
    echo "ERROR: Không tìm thấy $QUESTIONS_FILE"
    exit 1
fi

gum style \
    --border double \
    --border-foreground 212 \
    --padding "1 2" \
    --margin "1 0" \
    "DevOps Access Check" \
    "Trả lời các câu hỏi về quy trình nội bộ."

total=$(jq '.questions | length' "$QUESTIONS_FILE")
correct=0

for ((i=0; i<total; i++)); do
    question=$(jq -r ".questions[$i].question" "$QUESTIONS_FILE")

    mapfile -t options < <(
        jq -r ".questions[$i].options[]" "$QUESTIONS_FILE"
    )

    expected=$(jq -r ".questions[$i].answer" "$QUESTIONS_FILE")

    echo
    gum style \
        --foreground 212 \
        --bold \
        "[$((i + 1))/$total] $question"

    answer=$(gum choose \
        --height "${#options[@]}" \
        "${options[@]}")

    if [[ "$answer" == "$expected" ]]; then
        ((correct+=1))
        gum style --foreground 82 "✓ Đúng"
    else
        gum style --foreground 196 "✗ Không khớp"
    fi
done

echo

if [[ "$correct" -eq "$total" ]]; then
    gum style \
        --border rounded \
        --border-foreground 82 \
        --padding "1 2" \
        "✓ Đã xác minh qua quy trình nội bộ" \
        "Bạn có thể tiếp tục vào shell."

    exec "${SHELL:-/bin/bash}" -l
fi

gum style \
    --border rounded \
    --border-foreground 214 \
    --padding "1 2" \
    "Knowledge check không hoàn thành" \
    "Có thể sử dụng phương thức xác thực dự phòng."

echo

if [[ -z "$PASSWORD" ]]; then
    gum style --foreground 196 \
        "Password fallback chưa được cấu hình."
    exit 1
fi

entered_password=$(gum input \
    --password \
    --placeholder "Nhập password để tiếp tục" \
    --prompt "Password: ")

if [[ "$entered_password" == "$PASSWORD" ]]; then
    gum style --foreground 82 \
        "✓ Password hợp lệ. Đang mở shell..."

    exec "${SHELL:-/bin/bash}" -l
else
    gum style --foreground 196 \
        "✗ Authentication failed."
    exit 1
fi
