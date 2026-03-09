#!/bin/bash
# ============================================================
# 全言語フルベンチマーク テストランナー
#
# 使い方: ./run_full_benchmark.sh <model-dir>
# 例:     ./run_full_benchmark.sh sonnet-4.6
#
# 前提: 各 run ディレクトリにコードが生成済みであること
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test/test_api.sh"
MODEL_DIR="${1:?Usage: $0 <model-dir> (e.g. sonnet-4.6)}"
RESULTS_DIR="$SCRIPT_DIR/results/$MODEL_DIR"
PORT=8080

export PATH="/opt/homebrew/opt/ruby/bin:$(/opt/homebrew/opt/ruby/bin/gem environment gemdir 2>/dev/null)/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SUMMARY=""

kill_port() {
    lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 1
}

test_single_run() {
    local lang=$1 run=$2 start_cmd=$3 build_cmd=$4
    local dir="$RESULTS_DIR/$lang/run-$run"
    local build_success=true
    local server_success=false
    local test_pass=0 test_fail=7

    echo -e "${CYAN}=== $lang run-$run ===${NC}"

    if [ ! -d "$dir" ]; then
        echo -e "${RED}  Directory not found: $dir${NC}"
        SUMMARY="${SUMMARY}$lang run-$run: SKIP (no dir)\n"
        return
    fi

    kill_port
    cd "$dir"
    rm -f todos.db

    # Build
    if [ -n "$build_cmd" ]; then
        echo "  Building..."
        if ! eval "$build_cmd" > /tmp/build_${lang}_${run}.log 2>&1; then
            echo -e "${RED}  Build FAILED${NC}"
            build_success=false
            cat > "$dir/result.json" <<EOF
{"language":"$lang","run":$run,"build_success":false,"server_start_success":false,"test_pass":0,"test_fail":7,"test_total":7,"all_tests_passed":false,"error":"build failed"}
EOF
            SUMMARY="${SUMMARY}$lang run-$run: BUILD FAIL\n"
            return
        fi
    fi

    # Start server
    echo "  Starting server..."
    eval "nohup $start_cmd > /tmp/server_${lang}_${run}.log 2>&1 &"
    local wait_sec=4
    [ "$lang" = "ruby" ] && wait_sec=5
    sleep $wait_sec

    # Check server
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/todos" 2>/dev/null || echo "000")
    if [ "$http_code" = "000" ]; then
        echo -e "${RED}  Server failed to start${NC}"
        cat > "$dir/result.json" <<EOF
{"language":"$lang","run":$run,"build_success":$build_success,"server_start_success":false,"test_pass":0,"test_fail":7,"test_total":7,"all_tests_passed":false,"error":"server not responding"}
EOF
        SUMMARY="${SUMMARY}$lang run-$run: SERVER FAIL\n"
        kill_port
        return
    fi

    server_success=true

    # Run tests
    echo "  Running tests..."
    local test_output=$(bash "$TEST_SCRIPT" 2>&1) || true
    local json_line=$(echo "$test_output" | grep '{"pass"' | tail -1)
    if [ -n "$json_line" ]; then
        test_pass=$(echo "$json_line" | python3 -c "import sys,json; print(json.load(sys.stdin)['pass'])")
        test_fail=$(echo "$json_line" | python3 -c "import sys,json; print(json.load(sys.stdin)['fail'])")
    fi

    local all_passed=$([ "$test_fail" -eq 0 ] && echo true || echo false)

    cat > "$dir/result.json" <<EOF
{"language":"$lang","run":$run,"build_success":$build_success,"server_start_success":$server_success,"test_pass":$test_pass,"test_fail":$test_fail,"test_total":7,"all_tests_passed":$all_passed}
EOF

    if [ "$test_fail" -eq 0 ]; then
        echo -e "${GREEN}  PASSED: ${test_pass}/7${NC}"
        SUMMARY="${SUMMARY}$lang run-$run: PASS ${test_pass}/7\n"
    else
        echo -e "${RED}  FAILED: ${test_pass}/7 passed, ${test_fail}/7 failed${NC}"
        SUMMARY="${SUMMARY}$lang run-$run: FAIL ${test_pass}/7\n"
    fi

    kill_port
}

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}  Full Benchmark: $MODEL_DIR${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

# TypeScript
for run in 1 2 3 4 5; do
    dir="$RESULTS_DIR/typescript/run-$run"
    [ -f "$dir/app.ts" ] || continue
    # Install deps if needed
    if [ ! -d "$dir/node_modules" ]; then
        echo "  Installing TS deps for run-$run..."
        (cd "$dir" && npm install --silent 2>/dev/null)
    fi
    test_single_run "typescript" "$run" "npx tsx app.ts" ""
done

# Python
for run in 1 2 3 4 5; do
    dir="$RESULTS_DIR/python/run-$run"
    [ -f "$dir/app.py" ] || continue
    if [ ! -d "$dir/.venv" ]; then
        echo "  Setting up Python venv for run-$run..."
        (cd "$dir" && python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt 2>/dev/null)
    fi
    test_single_run "python" "$run" ".venv/bin/python app.py" ""
done

# Rust
for run in 1 2 3 4 5; do
    dir="$RESULTS_DIR/rust/run-$run"
    [ -f "$dir/Cargo.toml" ] || continue
    test_single_run "rust" "$run" "./target/release/todo-api" "cargo build --release"
done

# Ruby
for run in 1 2 3 4 5; do
    dir="$RESULTS_DIR/ruby/run-$run"
    [ -f "$dir/app.rb" ] || continue
    if [ ! -f "$dir/Gemfile.lock" ] || [ ! -d "$dir/vendor" ]; then
        echo "  Installing Ruby deps for run-$run..."
        (cd "$dir" && bundle install --quiet 2>/dev/null)
    fi
    test_single_run "ruby" "$run" "bundle exec ruby app.rb" ""
done

# Summary
echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}  SUMMARY: $MODEL_DIR${NC}"
echo -e "${YELLOW}============================================${NC}"
echo -e "$SUMMARY"

# Generate aggregate
echo -e "${CYAN}--- Aggregate ---${NC}"
for lang in typescript python rust ruby; do
    total_pass=0
    total_runs=0
    build_fails=0
    for run in 1 2 3 4 5; do
        f="$RESULTS_DIR/$lang/run-$run/result.json"
        [ -f "$f" ] || continue
        total_runs=$((total_runs + 1))
        pass=$(python3 -c "import json; print(json.load(open('$f'))['test_pass'])")
        bsuc=$(python3 -c "import json; print(json.load(open('$f'))['build_success'])")
        total_pass=$((total_pass + pass))
        [ "$bsuc" = "False" ] && build_fails=$((build_fails + 1))
    done
    if [ "$total_runs" -gt 0 ]; then
        echo "$lang: ${total_pass}/$((total_runs * 7)) tests passed, ${build_fails} build failures"
    fi
done
