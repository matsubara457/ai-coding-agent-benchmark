#!/bin/bash
# ============================================================
# Todo API 自動テストスクリプト
# ポート8080で起動済みのAPIに対してテストを実行する
#
# 使い方: ./test_api.sh
# 戻り値: 0=全テスト合格, 1=失敗あり
# 出力:   JSON形式の結果サマリー
# ============================================================

BASE_URL="http://localhost:8080"
PASS=0
FAIL=0
TOTAL=7
DETAILS=""

# テストヘルパー関数
run_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if echo "$actual" | grep -q "$expected"; then
        PASS=$((PASS + 1))
        DETAILS="${DETAILS}  PASS: ${test_name}\n"
    else
        FAIL=$((FAIL + 1))
        DETAILS="${DETAILS}  FAIL: ${test_name} (expected: ${expected}, got: ${actual})\n"
    fi
}

echo "=== Todo API Test Suite ==="
echo ""

# --- Test 1: GET /todos (空のリスト) ---
RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/todos" 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
run_test "GET /todos returns 200" "200" "$HTTP_CODE"
run_test "GET /todos returns array" "\[" "$BODY"

# --- Test 2: POST /todos ---
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/todos" \
    -H "Content-Type: application/json" \
    -d '{"title":"テスト買い物"}' 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
run_test "POST /todos returns 201" "201" "$HTTP_CODE"
run_test "POST /todos returns todo with title" "テスト買い物" "$BODY"

# --- Test 3: GET /todos (1件取得) ---
RESPONSE=$(curl -s "$BASE_URL/todos" 2>/dev/null)
run_test "GET /todos after POST has item" "テスト買い物" "$RESPONSE"

# --- Test 4: PUT /todos/1 ---
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/todos/1" \
    -H "Content-Type: application/json" \
    -d '{"title":"更新済み","completed":true}' 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
run_test "PUT /todos/1 returns updated todo" "更新済み" "$BODY"

# --- Test 5: DELETE /todos/1 ---
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/todos/1" 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
run_test "DELETE /todos/1 returns deleted message" "deleted" "$BODY"

# --- 結果出力 ---
echo ""
echo -e "$DETAILS"
echo "==========================="
echo "Result: ${PASS}/${TOTAL} passed, ${FAIL}/${TOTAL} failed"
echo ""

# JSON結果出力（集計用）
echo "{\"pass\":${PASS},\"fail\":${FAIL},\"total\":${TOTAL}}"

if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    exit 1
fi
