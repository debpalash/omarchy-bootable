#!/usr/bin/env sh
set -eu

assert_plain_text_sink() {
  sink=$1
  if ! grep -F -A 4 "$sink" Panel.qml | grep -Fq 'textFormat: Text.PlainText'; then
    printf 'external QML text sink is not plain text: %s\n' "$sink" >&2
    exit 1
  fi
}

assert_plain_text_sink 'text: bootable.selectedDistribution'
assert_plain_text_sink 'text: bootable.catalogResultText'
assert_plain_text_sink 'text: cardContent.parent.title'
assert_plain_text_sink 'text: cardContent.parent.detail'
assert_plain_text_sink 'text: bootable.removableStatusText'
assert_plain_text_sink 'text: bootable.deviceName(device)'
assert_plain_text_sink 'text: String(device.path || "")'
assert_plain_text_sink 'text: bootable.eligibility(device)'
assert_plain_text_sink 'text: actionRow.title'
assert_plain_text_sink 'text: actionRow.detail'
