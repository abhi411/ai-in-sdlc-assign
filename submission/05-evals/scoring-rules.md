# Scoring rules (write before running; do not edit after seeing results)

Source: ops/evals/README.md.
- Caught: the case has a defect and the review names the actual defect (right problem, right reason).
- Missed: defective case, defect not named.
- False alarm: clean case where the review asserts a defect that is not there. Style suggestions on clean cases are NOT false alarms.
- A vague note near the right line, or a right finding for the wrong reason, is NOT caught (be strict).
- Rates: caught = caught / defective cases; missed = missed / defective cases; false alarm = false-alarm cases / clean cases.
- Mark ambiguous cases separately and report rates with and without them.
- Procedure: fresh session per case; give only the diff and the review prompt; three full passes; then ONE change; three more passes.
