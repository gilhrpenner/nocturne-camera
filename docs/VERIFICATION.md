# Verification — Nocturne 0.9, 2026-10-26

## Current status

- Ten test suites pass: renderer, fangs, storm/makeup, head/hair treatment, fog, layered scene, tracking stability, actor/eye appearance, theatrical performances, and character transitions.
- Universal Release build, deep/strict signing checks, and the camera App Group/Mach service contract pass. Host version is 0.9.0 (build 11); the camera extension remains 0.1.1 (build 2).
- The camera extension is activated, and video delivery through the Teams meeting preview in Safari has been verified. The updated app's native controls and camera-off startup have been checked.
- The outfit stability regression reduced maximum frame-to-frame jumps from 10 to 0.37 pixels under stationary landmark noise, from 46.34 to 3.66 pixels on hip loss/reacquisition, and from 45.89 to 3.37 pixels on body loss/reacquisition. A sustained lean still moves the garment.
- Pixel tests verify removal of real shoulders, retention of the head and neck, collar depth, person-mask isolation, pupil alignment, blinking, white-hair strand contrast, and forehead protection under warm and neutral light.
- Visual replays were inspected locally. Personal reference images, replay outputs, build products, and signed app bundles are excluded from Git.
- Static UI audit reports zero findings; design lint reports zero errors and the existing advisory about `accent` instead of `primary`.
- Performance tests cover cue overlap/cancellation, automatic return, synchronized entrance lightning, real actor pixels in fragments, silhouette-only origins, moving fragment alignment, articulated transparent bat artwork, a completely empty interval, complete reassembly, and occasional window visits with motion/classic/bypass guards.
- Production-renderer filmstrips show the departing and returning transformation and the grand entrance. Enlarged castle-window replays verify the figure stays behind the existing glass and stone mullions. The dedicated photographic bat asset and its exact generation prompt are included in source.
- Two optimized 150-frame replays of the new alternating transformation averaged 37.3 ms per frame in each direction. Return as Batman: 58.9 ms at the 95th percentile, 66.6 ms maximum. Return as Vampire: 58.7 ms at the 95th percentile, 89.7 ms maximum. The app was closed, and the input was a local still camera reference. This is a renderer measurement, not a sustained Teams frame-rate guarantee.
- The installed native app shows all four cues and Haunted windows. Camera-off cue guards, Scene motion disabling Haunted windows, its toggle, Normal camera disabling every cue, and restoring the default settings were verified. Layout was inspected at the existing 1305-pixel window width; automated resize gestures did not change the window, so minimum-size layout remains a manual check.

- Character tests cover six repeated swaps, the switch at the start of gathering while the actor is hidden, duplicate-cue rejection, persistent identity, cancellation on either side of the switch, Grand entrance retaining identity, and preserved vampire preferences. Pixel tests cover registered eye/chin landmarks, transparent cowl apertures, hidden hair/torso, person-mask isolation, fresh incoming fragment textures, and exact Normal-camera bypass in Batman mode.
- Production-renderer filmstrips using the earlier unfiltered camera reference show Vampire → Batman → Vampire with natural eyes/mouth in Batman and restored vampire treatment afterward. The original cowl and suit are stylized native artwork; their face fit is affine, not a complete 3D head model. No new generated bitmap asset was added.
- The installed Character picker switches the heading and controls. Changing vampire intensity to 61%, selecting Batman, and returning preserved the value; the original 85% was restored after the check. Normal camera disables the picker and fit controls. The app was left on Vampire, camera off, with the other settings restored. Physical head movement and the live cue in Teams remain interactive checks.

Design reconciliation: the existing palette, typography, native controls and `ContentView.cue` owner are preserved. The native Character picker, alternating cue feedback, conditional look controls, four-button cue row, and Haunted windows are intentional additions documented in `DESIGN.md`; no token drift was introduced.

Long-duration call performance, physical global shortcuts while Teams has focus, and extension removal remain interactive checks. The app is development-signed for local installation; no notarized public binary is provided.

The sections below record earlier findings and their resolution. Statements about pending activation describe the initial build, not the current status.

---

## Initial build, 2026-10-26

## Passed

- Xcode Debug and optimized Release builds of the host app and bundled camera extension.
- App signing/provisioning under the configured Apple Developer team; deep/strict signature verification.
- Renderer tests: 1280×720 frames, lightning illumination/fade, bat cue changes, three-second vanish expiry, normal-mode bypass, pixel-preserving normal camera, empty-input cutout isolation, valid sample timing.
- Native window launch from `/Applications/Nocturne.app` and visual inspection of the animated castle preview, with the physical camera off.
- Static UI audit: zero findings. Design document lint: zero errors, one advisory warning about the palette's `accent` name instead of `primary`.

## Pending interactive testing

The user chose to test later. Camera-extension activation, webcam permission, real-person segmentation and face landmarks, global shortcut behavior while Teams has focus, Teams selection/output, long-running performance, and extension removal have **not** been verified end to end.

An automated key event did not toggle the global shortcut during the UI check. Carbon hotkey registration returned success, but actual physical shortcuts still need testing; use the on-screen controls if they do not respond.

Nocturne is installed and was left open with its camera off. The extension has not been approved/activated. The distributable ZIP is development-signed for local testing, not notarized for public distribution.

## First live test

1. Enable the camera extension in Nocturne and approve it in macOS.
2. Start the camera. Check face position, eye tracking, fangs with open/closed lips, hair edges, and lighting.
3. Select Nocturne Camera in a Teams preview; disable Teams background effects.
4. Try Control–Option–L/B/G/V/N while Teams is focused.
5. Stop Nocturne's camera and verify the virtual feed becomes dark within about a second.
6. After the party, remove the extension using Nocturne, then delete the app.

## Fang placement correction — 2026-10-26

The user's local camera preview works, but the initial fangs appeared on the lips/central teeth, were too small, and vanished with closed lips. The root cause was using Vision's narrow inner-lip contour as the full mouth width, sizing teeth by opening height, and clipping them to that opening.

Fangs now use the full outer-mouth width and mouth angle, attach below the interpolated upper seam at canine positions, and protrude beyond the lower lip even with a closed mouth. Curved, shaded fang bodies replace the tiny flat triangles. Diagnostic replay against both supplied screenshots was visually inspected. Personal screenshot diagnostics remain under ignored `build/diagnostics`, not in tracked source.

`./scripts/test-fangs.sh` failed on the old implementation and passes after the fix: canine spacing, large tooth length, roots below the lip, closed-mouth visibility, missing-landmark fallback, actual rendered pixels beyond the mouth, and head rotation. The full renderer suite, Release build, static UI audit, and installed signature verification also pass. Updated app installed and reopened; the user then started the camera for testing.

A separate issue was observed in the prior running app: **Camera extension: extension category returned error**. Virtual-camera activation is therefore known to need investigation; Teams is currently unavailable to the user. This fang correction does not claim to resolve extension activation.

## Camera activation and Safari delivery — resolved, 2026-10-26

The macOS log identified the registration failure: the extension's Mach service name was not prefixed by an App Group declared in its signed entitlements. Added the matching App Group to the generated extension entitlements and packaged version 0.1.1 (build 2). `scripts/check_camera_bundle.py` fails on the original installed bundle and passes on the corrected signed build; packaging now runs this check automatically.

Verified evidence:

- Release build and installed signed-bundle registration check pass.
- `systemextensionsctl list` reports Nocturne 0.1.1/2 as **activated enabled**.
- `xcrun swift scripts/inspect_camera.swift` finds **Nocturne Camera**, its source stream (direction 1), and its input/sink stream (direction 0).
- The already-running host initially retained its old camera discovery state. A fresh producer process connected successfully; restarting Nocturne then changed its status to **Sending to Nocturne Camera**. This first-activation restart is documented in the README.
- The user selected Nocturne in Teams/Safari, switched away and back, confirmed the video appears, and supplied a screenshot showing the vampire/castle feed in the Teams meeting preview.

Camera registration and frame delivery are now verified end to end through Safari/Teams preview. Joining a meeting, long-duration performance, global hotkeys while Teams has focus, and removal remain separate checks; no live meeting was joined by the agent.
