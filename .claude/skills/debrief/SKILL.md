---
name: debrief
description: Logs the final outcome of a swing trade, diagnoses why it won or lost, and updates the playbook.
context: fork
allowed-tools:
  - Bash
  - Read
  - Write
---

Conduct a forensic review on trade $ARGUMENTS:
1. Load the original thesis from `trades/`.
2. Check actual price action: Did it hit Target 1/2 or the Stop Loss?
3. Answer:
   - Was the failure caused by bad technical timing, macro/market-wide drop, or an unexpected headline?
   - Did the Bear Agent fail to spot an obvious warning sign?
4. Append the trade outcome to `trades/history.csv`.
5. If the trade failed due to a repeatable blindspot, update `memory/playbook.md` under "Confirmed Negative Edge".