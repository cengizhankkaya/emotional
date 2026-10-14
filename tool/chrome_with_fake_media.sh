#!/bin/sh
# Chrome with a fake camera and microphone that are allowed without a prompt,
# for the media tests that open real devices:
#
#   CHROME_EXECUTABLE=tool/chrome_with_fake_media.sh flutter test --platform chrome ...
#
# Set REAL_CHROME if Chrome lives somewhere else.
REAL_CHROME="${REAL_CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
exec "$REAL_CHROME" \
  --use-fake-ui-for-media-stream \
  --use-fake-device-for-media-stream \
  --autoplay-policy=no-user-gesture-required \
  "$@"
