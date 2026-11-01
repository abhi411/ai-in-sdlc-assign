#!/usr/bin/env bash
# Run inside a clone of your real GitHub repo with the gh CLI logged in (gh auth login).
set -euo pipefail
gh pr list --state merged --limit 200 --json number,createdAt,mergedAt,title > prs.json
gh run list --limit 200 --json databaseId,conclusion,createdAt,headBranch,event,name > runs.json
git log --pretty=format:"%h|%aI|%s" > git-log.txt
python3 - <<PY
import json, statistics as st
from datetime import datetime
p=lambda s: datetime.fromisoformat(s.replace("Z","+00:00"))
prs=json.load(open("prs.json"))
lt=[(p(x["mergedAt"])-p(x["createdAt"])).total_seconds()/3600 for x in prs if x.get("mergedAt")]
print("merged PRs:",len(lt),"median lead time (h):",round(st.median(lt),2) if lt else "n/a")
runs=json.load(open("runs.json"))
done=[r for r in runs if r["conclusion"] in ("success","failure")]
fail=[r for r in done if r["conclusion"]=="failure"]
print("CI runs:",len(done),"failures:",len(fail),"rate:",round(len(fail)/len(done),3) if done else "n/a")
PY
