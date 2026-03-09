#!/bin/bash
# ============================================================
# AI Coding Agent ベンチマーク ランナー
#
# 各言語ディレクトリ内のコードをビルド→起動→テスト→結果記録
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test/test_api.sh"
RESULTS_DIR="$SCRIPT_DIR/results"
PORT=8080
WAIT_SEC=5         # サーバー起動待ち秒数
TIMEOUT_SEC=30     # ビルドタイムアウト

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 使い方
usage() {
    echo "Usage: $0 <language> <run-number>"
    echo "  language:   typescript | python | rust | ruby"
    echo "  run-number: 1-5"
    echo ""
    echo "Example: $0 typescript 1"
    exit 1
}

[ $# -ne 2 ] && usage

LANG=$1
RUN=$2
RUN_DIR="$RESULTS_DIR/$LANG/run-$RUN"

if [ ! -d "$RUN_DIR" ]; then
    echo "Error: $RUN_DIR does not exist"
    exit 1
fi

echo -e "${YELLOW}=== Benchmark: $LANG run-$RUN ===${NC}"
echo ""

# 既存のポート8080プロセスを停止
kill_port() {
    lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 1
}

# クリーンアップ
cleanup() {
    kill_port
    rm -f "$RUN_DIR/todos.db"
}
trap cleanup EXIT

kill_port

# 結果記録用変数
BUILD_SUCCESS=false
RUN_SUCCESS=false
TEST_PASS=0
TEST_FAIL=0
TEST_TOTAL=7
BUILD_TIME=0
ERRORS=""

cd "$RUN_DIR"

# ------ ビルド & 起動 ------
START_TIME=$(date +%s)

case $LANG in
    typescript)
        echo ">> npm install & run..."
        if npm install --silent 2>"$RUN_DIR/build_error.log"; then
            BUILD_SUCCESS=true
            npx tsx app.ts &>"$RUN_DIR/server.log" &
            SERVER_PID=$!
        else
            ERRORS=$(cat "$RUN_DIR/build_error.log")
        fi
        ;;
    python)
        echo ">> pip install & run..."
        # venv を作成して依存関係をインストール
        if python3 -m venv .venv 2>"$RUN_DIR/build_error.log" && \
           .venv/bin/pip install -q -r requirements.txt 2>>"$RUN_DIR/build_error.log"; then
            BUILD_SUCCESS=true
            .venv/bin/python app.py &>"$RUN_DIR/server.log" &
            SERVER_PID=$!
        else
            ERRORS=$(cat "$RUN_DIR/build_error.log")
        fi
        ;;
    rust)
        echo ">> cargo build & run..."
        if cargo build --release 2>"$RUN_DIR/build_error.log"; then
            BUILD_SUCCESS=true
            cargo run --release &>"$RUN_DIR/server.log" &
            SERVER_PID=$!
        else
            ERRORS=$(cat "$RUN_DIR/build_error.log")
        fi
        ;;
    ruby)
        echo ">> bundle install & run..."
        if bundle install --quiet 2>"$RUN_DIR/build_error.log"; then
            BUILD_SUCCESS=true
            bundle exec ruby app.rb &>"$RUN_DIR/server.log" &
            SERVER_PID=$!
        else
            ERRORS=$(cat "$RUN_DIR/build_error.log")
        fi
        ;;
    *)
        echo "Unknown language: $LANG"
        exit 1
        ;;
esac

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - START_TIME))

if [ "$BUILD_SUCCESS" = true ]; then
    echo -e "${GREEN}>> Build OK (${BUILD_TIME}s)${NC}"

    # サーバー起動待ち
    echo ">> Waiting ${WAIT_SEC}s for server..."
    sleep $WAIT_SEC

    # ポートが開いているか確認
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/todos" 2>/dev/null | grep -q "200\|404\|500"; then
        RUN_SUCCESS=true
        echo -e "${GREEN}>> Server is running${NC}"

        # テスト実行
        echo ">> Running tests..."
        TEST_OUTPUT=$(bash "$TEST_SCRIPT" 2>&1) || true
        echo "$TEST_OUTPUT"

        # テスト結果をパース
        JSON_LINE=$(echo "$TEST_OUTPUT" | grep '{"pass"' | tail -1)
        if [ -n "$JSON_LINE" ]; then
            TEST_PASS=$(echo "$JSON_LINE" | python3 -c "import sys,json; print(json.load(sys.stdin)['pass'])")
            TEST_FAIL=$(echo "$JSON_LINE" | python3 -c "import sys,json; print(json.load(sys.stdin)['fail'])")
        fi
    else
        echo -e "${RED}>> Server failed to start${NC}"
        ERRORS="Server did not respond on port $PORT"
        [ -f "$RUN_DIR/server.log" ] && ERRORS="$ERRORS\n$(tail -20 "$RUN_DIR/server.log")"
    fi
else
    echo -e "${RED}>> Build FAILED${NC}"
fi

# ------ 結果JSON出力 ------
RESULT_FILE="$RUN_DIR/result.json"
cat > "$RESULT_FILE" <<ENDJSON
{
  "language": "$LANG",
  "run": $RUN,
  "build_success": $BUILD_SUCCESS,
  "server_start_success": $RUN_SUCCESS,
  "build_time_sec": $BUILD_TIME,
  "test_pass": $TEST_PASS,
  "test_fail": $TEST_FAIL,
  "test_total": $TEST_TOTAL,
  "all_tests_passed": $([ "$TEST_FAIL" -eq 0 ] && [ "$RUN_SUCCESS" = true ] && echo true || echo false)
}
ENDJSON

echo ""
echo -e "${YELLOW}>> Result saved to $RESULT_FILE${NC}"
cat "$RESULT_FILE"
