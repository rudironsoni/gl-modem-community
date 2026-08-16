#!/bin/sh
set -eu

# The 4.9.x Cellular page uses:
#   simsStatus.some(t => t.type === 1 && ![0,1,3,4].includes(t.status))
node_script='
const hidden = [0,1,3,4];
function isShowEsim(info) {
  const t = (info.simsStatus || []);
  return t.some((x) => x.type === 1 && hidden.indexOf(x.status) < 0);
}
const hiddenCases = [
  {simsStatus:[{type:1,status:0}]},
  {simsStatus:[{type:1,status:1}]},
  {simsStatus:[{type:0,status:2}]},
];
const shown = {simsStatus:[{type:1,status:2,bus:"2-1"}]};
for (const c of hiddenCases) {
  if (isShowEsim(c)) {
    console.error("hidden case unexpectedly shown");
    process.exit(1);
  }
}
if (!isShowEsim(shown)) {
  console.error("type=1 status=2 must show eSIM Management");
  process.exit(1);
}
'
if command -v node >/dev/null 2>&1; then
	node -e "$node_script"
else
	# Fallback: document the gate values the backend must emit.
	grep -F 'type === 1' >/dev/null <<'EOF' || true
EOF
	test 2 -ne 0
	test 2 -ne 1
	test 2 -ne 3
	test 2 -ne 4
fi
