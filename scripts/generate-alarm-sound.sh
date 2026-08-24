#!/bin/bash
#
# Regenerates App/Resources/salus_alarm.caf — the custom sound a medication-dose
# reminder rings with on the iOS 17-25 fallback path (spec's 2026-08-23 AlarmKit
# note, case 2), and the sound AlarmKit is given on iOS 26+.
#
# THIS IS A PLACEHOLDER. It is a plain synthesized beep pattern, committed so the
# path through the code is real and testable end to end; a designed alarm sound
# replaces it before release. The file is committed rather than generated at build
# time so CI needs neither perl nor afconvert.
#
# Two hard constraints, both checked below because iOS enforces neither loudly:
#
#   * 30 seconds maximum. A longer custom sound is IGNORED and the system default
#     is played instead — silently, with nothing in the log.
#   * CAF/AIFF/WAV with Linear PCM, µ-law or a-law. The bundled file has to sit at
#     the bundle root, which is where Xcode copies App/Resources/* to.
#
# The tone is synthesized with perl rather than `say` so the result is an alarm
# pattern instead of speech, and so re-running this script produces the same bytes.
#
# Usage:
#     scripts/generate-alarm-sound.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/App/Resources/salus_alarm.caf"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RATE=44100
# Six 0.4 s beeps separated by 0.6 s of silence: 6 s total, well inside the 30 s
# ceiling and long enough to be heard once from another room.
BEEPS=6
BEEP_MS=400
GAP_MS=600

echo "==> synthesizing ${BEEPS} beeps (${BEEP_MS}ms on / ${GAP_MS}ms off) at ${RATE} Hz"
perl - "$WORK/tone.wav" "$RATE" "$BEEPS" "$BEEP_MS" "$GAP_MS" <<'PERL'
use strict;
use warnings;

my ($path, $rate, $beeps, $beep_ms, $gap_ms) = @ARGV;

my $beep_samples = int($rate * $beep_ms / 1000);
my $gap_samples  = int($rate * $gap_ms / 1000);
# Two tones an octave apart, alternating, so the pattern reads as an alarm rather
# than as a notification chime.
my @freqs = (880.0, 1174.7);
# 5 ms of fade at each edge; a square-edged sine clicks.
my $fade = int($rate * 0.005);

my $pcm = '';
for my $i (0 .. $beeps - 1) {
    my $freq = $freqs[$i % scalar(@freqs)];
    for my $n (0 .. $beep_samples - 1) {
        my $envelope = 1.0;
        $envelope = $n / $fade if $n < $fade;
        my $tail = $beep_samples - 1 - $n;
        $envelope = $tail / $fade if $tail < $fade;
        my $value = 0.6 * $envelope * sin(2 * 3.14159265358979 * $freq * $n / $rate);
        $pcm .= pack('s<', int($value * 32767));
    }
    $pcm .= pack('s<', 0) x $gap_samples;
}

my $data_size = length($pcm);
open(my $fh, '>:raw', $path) or die "cannot write $path: $!";
print $fh 'RIFF', pack('V', 36 + $data_size), 'WAVE';
print $fh 'fmt ', pack('V', 16), pack('v', 1), pack('v', 1),
    pack('V', $rate), pack('V', $rate * 2), pack('v', 2), pack('v', 16);
print $fh 'data', pack('V', $data_size), $pcm;
close($fh);
PERL

# IMA4 (a.k.a. MA4) is one of the four formats iOS accepts for a notification
# sound, and it is a quarter the size of the linear PCM it comes from — this file
# is committed, so that matters more than the fidelity of a placeholder beep.
echo "==> afconvert -> CAF (IMA4)"
afconvert -f caff -d ima4 "$WORK/tone.wav" "$OUT"

DURATION=$(afinfo "$OUT" | awk -F': *' '/estimated duration/ { print $2 }' | awk '{ print $1 }')
echo "==> duration: ${DURATION}s"
awk -v d="$DURATION" 'BEGIN { if (d <= 0 || d > 30) { exit 1 } }' || {
    echo "FAIL: $OUT is ${DURATION}s; iOS ignores a custom sound longer than 30s." >&2
    exit 1
}

echo "==> wrote $OUT"
