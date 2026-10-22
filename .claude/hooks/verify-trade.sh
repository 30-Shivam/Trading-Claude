#!/usr/bin/env bash
# Deterministic gate: Ensures any trade generated in output meets mathematical constraints
# Exit 0 = Allow; Exit 2 = Block and send error back to Claude to fix

TRADE_FILE="trades/current_run.json"

if [ -f "$TRADE_FILE" ]; then
    # Verify R:R >= 2.0 via quick jq/python check
    RR=$(python3 -c "import json; data=json.load(open('$TRADE_FILE')); print(data.get('rr_ratio', 0))")
    if (( $(echo "$RR < 2.0" | bc -l) )); then
        echo "GATE REJECTION: Trade setup R:R is $RR, which is below the strict 2.0 minimum."
        exit 2
    fi
fi
exit 0