#!/usr/bin/env sh
set -eu

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mock_bin="$test_root/bin"
state_home="$test_root/state"
active_file="$test_root/active"
invocation_file="$test_root/systemd-run.args"
mkdir -p "$mock_bin" "$test_root/home/Downloads"

cat > "$mock_bin/systemctl" <<'EOF'
#!/usr/bin/env sh
if [ -f "$BOOTABLE_TEST_ACTIVE_FILE" ]; then
  exit 0
fi
exit 3
EOF

cat > "$mock_bin/systemd-run" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "$@" > "$BOOTABLE_TEST_INVOCATION_FILE"
: > "$BOOTABLE_TEST_ACTIVE_FILE"
EOF

cat > "$mock_bin/bootable" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

chmod 755 "$mock_bin/systemctl" "$mock_bin/systemd-run" "$mock_bin/bootable"

export HOME="$test_root/home"
export XDG_STATE_HOME="$state_home"
export BOOTABLE_TEST_ACTIVE_FILE="$active_file"
export BOOTABLE_TEST_INVOCATION_FILE="$invocation_file"
export PATH="$mock_bin:/usr/bin:/bin"

initial=$(./bootable-download-session status)
printf '%s' "$initial" | grep -q '"active":false'

destination="$HOME/Downloads/test.iso"
./bootable-download-session start omarchy 0 "$destination"
active=$(./bootable-download-session status)
printf '%s' "$active" | grep -q '"active":true'
printf '%s' "$active" | grep -q '"destination":".*/Downloads/test.iso"'
grep -q -- '--json-progress' "$invocation_file"

printf '%s\n' '{"event":"progress","data":{"phase":"Downloading","completed":25,"total":100,"message":"25%"}}' \
  > "$state_home/omarchy-bootable/download/events.ndjson"
progress=$(./bootable-download-session status)
printf '%s' "$progress" | grep -q '"completed":25'

rm "$active_file"
printf '%s\n' '{"event":"finished","data":{"path":"test.iso"}}' \
  >> "$state_home/omarchy-bootable/download/events.ndjson"
finished=$(./bootable-download-session status)
printf '%s' "$finished" | grep -q '"active":false'
printf '%s' "$finished" | grep -q '"event":"finished"'

./bootable-download-session clear
cleared=$(./bootable-download-session status)
printf '%s' "$cleared" | grep -q '"event":null'
