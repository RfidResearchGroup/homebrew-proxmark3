#!/bin/bash
set -euo pipefail

toolchain=rfidresearchgroup/proxmark3/arm-none-eabi-gcc
current_tap=$(printf '%s' "$TAP_NAME" | tr '[:upper:]' '[:lower:]')
if [[ "$current_tap" != rfidresearchgroup/proxmark3 ]]; then
  # Fork users depend on the RRG compiler. Testing the fork's unused mirror in
  # the same prefix would replace that dependency with a conflicting tap owner.
  # The all-tap syntax/audit step still checks the mirrored formula.
  mirror="$current_tap/arm-none-eabi-gcc"
  TESTING_FORMULAE=$(printf '%s' "$TESTING_FORMULAE" | tr ',' '\n' | awk -v name="$mirror" '$0 != name' | paste -sd, -)
  ADDED_FORMULAE=$(printf '%s' "$ADDED_FORMULAE" | tr ',' '\n' | awk -v name="$mirror" '$0 != name' | paste -sd, -)
  DELETED_FORMULAE=$(printf '%s' "$DELETED_FORMULAE" | tr ',' '\n' | awk -v name="$mirror" '$0 != name' | paste -sd, -)
fi

if [[ "$TESTING_FORMULAE" == *proxmark-firmware-* ]] &&
   ! brew ruby -e 'exit(Formula[ARGV.fetch(0)].bottle_specification.tag?(Utils::Bottles.tag, no_older_versions: true) ? 0 : 1)' "$toolchain"
then
  if [[ "$current_tap" == rfidresearchgroup/proxmark3 ]]; then
    # The owning tap builds and publishes its compiler before the firmware.
    # Never inject runner-local bottle URLs into the tap being published.
    if [[ ",$TESTING_FORMULAE," != *",$toolchain,"* ]]; then
      TESTING_FORMULAE="$toolchain,$TESTING_FORMULAE"
    fi
  else
    # A fork cannot publish bottles for another tap. Bootstrap its external
    # dependency outside this tap's uploaded artifacts and disposable checkout.
    bottle_dir="$RUNNER_TEMP/proxmark-toolchain-bottle"
    mkdir -p "$bottle_dir"
    brew install --build-bottle "$toolchain"
    (
      cd "$bottle_dir"
      brew bottle --json --root-url="file://$bottle_dir" "$toolchain"
      brew ruby -e '
        require "json"
        require "fileutils"
        Dir["*.bottle.json"].each do |path|
          JSON.parse(File.read(path)).each_value do |formula|
            formula.fetch("bottle").fetch("tags").each_value do |tag|
              FileUtils.ln_sf(tag.fetch("local_filename"), tag.fetch("filename"))
            end
          end
        end
      '
      brew bottle --merge --write --no-commit ./*.bottle.json
      brew fetch --force-bottle "$toolchain"
    )
  fi
fi

{
  echo "testing_formulae=$TESTING_FORMULAE"
  echo "added_formulae=$ADDED_FORMULAE"
  echo "deleted_formulae=$DELETED_FORMULAE"
} >> "$GITHUB_OUTPUT"
