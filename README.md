# Nocturne Camera

A standalone macOS vampire camera for a Halloween Teams call. Native SwiftUI, AVFoundation, Vision, Core Image, and a bundled Core Media I/O camera extension. No OBS, web server, Python runtime, or downloaded ML model is needed at runtime.

## Project layout

```text
App/                 Camera capture, compositor, controls, global shortcuts
CameraExtension/     The virtual webcam and its in-memory input stream
Shared/              Fixed video format and device identifiers
Resources/           Generated castle background, bundled with the app
Tests/               Compositor and effect behavior checks
scripts/             Xcode project generation, build/package, test
Nocturne.xcodeproj/   Open this in Xcode
build/               Ignored build products, logs, and test renders
dist/                Ignored installable app and ZIP
```

## Use

1. Copy `dist/Nocturne.app` to `/Applications` and open it.
2. Click **Enable Teams camera**. Approve Nocturne in **System Settings → General → Login Items & Extensions → Camera Extensions** when macOS requests it. Older macOS versions show the approval under Privacy & Security.
3. After the first successful extension activation, quit and reopen Nocturne so it discovers the new camera. Click **Start camera** and allow camera access. The status beneath the preview should say **Sending to Nocturne Camera**.
4. In Teams, select **Nocturne Camera** as your camera. Reopen Teams if it was running during installation. Turn off Teams' own background effects so they do not cut out the castle/bats.
5. Keep Nocturne open. Use your normal microphone in Teams; Nocturne does not capture audio.

The app opens with an animated scene preview and the physical camera off. Closing its last window quits the app. The camera extension shows a dark frame when the app stops sending frames, rather than holding a stale image of you.

The first build chooses the built-in camera when present, otherwise the first external camera. Output is 1280×720 at a nominal 24 fps; actual rendering speed depends on the Mac and scene.

**Verified on 2026-10-26:** the live vampire/castle feed works in Microsoft Teams' meeting preview in Safari on this Mac. If Teams lists Nocturne but shows a dark frame, first check that Nocturne says **Sending to Nocturne Camera**, then switch Teams to another camera and back. The extension deliberately sends a dark standby frame while it has no fresh video from the app.

## Effects and shortcuts

All shortcuts are **Control–Option**, and work while Teams has focus. They use registered hotkeys, not keylogging or Accessibility permissions.

| Key | Action |
| --- | --- |
| L | Lightning cue |
| B | Bat swarm |
| G | Vanish for three seconds with bats |
| V | Toggle vampire makeup |
| N | Toggle normal, unfiltered camera |

Theatrical makeup uses softly blended, color-selective pale grading across the face, forehead, ears, jaw, and neck, sunken eye sockets, subtle branching veins and softly shaded cheek hollows, crimson eyes, burgundy lips, and long curved fangs at the upper canines. The **Blood trails** toggle adds subtle, asymmetric animated blood at the mouth corners. The fangs protrude below the lips and stay visible with a closed mouth; their placement and angle follow the full mouth contour. It follows the largest detected face. This is a lightweight face-landmark effect, not a generative identity transformation. Profiles, glasses, occlusion, and very dim lighting can reduce tracking quality.

The **Distance** slider below the preview scales you, your makeup, and your costume together from 100% down to 55% size. Move it toward **Farther** to reveal more of the generated outfit; **Reset** restores the original framing. It requires Castle & person cutout and is bypassed by Normal camera. It cannot recover real body parts outside the camera frame. With attire off, the cutout stays anchored to the bottom to avoid a floating crop edge.

Person segmentation replaces the room with the castle. No green screen is needed. Even lighting and a plain wall help hair and shoulder edges. If segmentation fails, the app displays the castle and an error status rather than exposing the room. **Normal camera** deliberately shows the original room and bypasses all effects.

**Hair** offers Natural, Black + silver temples (default), Silver-gray, and Deep black, with a separate strength slider. It recolors the camera image while keeping the real hair texture and silhouette. Face landmarks, person segmentation, and color selection estimate the regions; this is not a dedicated hair-segmentation model. Strong shadows, bright highlights, profile views, and unusual lighting can reduce precision. Selecting Natural turns hair coloring off; Normal camera bypasses everything.

**Vampire attire** uses a generated photographic costume texture: black brocade, satin lapels, a swept collar, black silk cravat, ruby clasps, and thin crimson trim. Its position and scale are smoothed using face and shoulder tracking. The cape sits behind the person; its front replaces the shirt while preserving the detected jaw/head silhouette. This is a 2D garment overlay: it cannot reconstruct arms, handle extreme turns, or deform like a 3D costume. The asset is `Resources/vampire-attire.png`; its built-in image-generation prompt is recorded in `Resources/asset-prompts.json`.

**Fog amount** adds slowly rising, cool-gray fog in front of the person and castle. It is thickest at the bottom, thins upward, and disappears around two-thirds of the frame height. The slider runs from Off to Thick; default strength is 55%. Reduce Motion keeps the fog still.

Automatic lightning clusters run roughly every 3.2 seconds with varied positions, branching shapes, brightness, and width. The manual lightning cue triggers three staggered bolts. Automatic lightning can be switched off. System Reduce Motion initially disables automatic lightning and ambient bats and freezes blood animation; manual cues remain available.

## Remove after the party

Click **Remove camera extension…**, confirm removal, and follow any macOS approval/restart instruction. Then quit Nocturne and move `/Applications/Nocturne.app` to the Trash. macOS may retain ordinary application preference/window-state files, but Nocturne creates no recordings, model caches, or background login items.

## Build

Requires Xcode, macOS 14+, and an Apple Developer team capable of provisioning a system-extension host app. The generated project currently uses Gil's team ID `7WP2X25KFL`; no private key or credential is stored in this repository. Update the team and bundle identifiers before distributing under a different account.

```sh
./scripts/build.sh
./scripts/test.sh
```

The build script generates the Xcode project, allows Xcode to create/update provisioning profiles and register the build Mac if necessary, builds a locally installable development-signed app, verifies its signatures and the camera's App Group/Mach service contract, and creates `dist/Nocturne-macOS.zip`. Signing uses the macOS keychain/Xcode account. This is **not a notarized public release**; broader distribution needs Developer ID signing, suitable provisioning, and notarization.

The compositor tests run without opening the webcam. They check dimensions, lightning/fade, bats, vanish timing, normal-camera pixel preservation, empty-input cutout behavior, sample timing, storm variation and stable fading geometry, costume anchoring, blood toggling/animation/reduced motion, full makeup coverage, hair tones, forehead protection, and room isolation. Real-person tracking and a Teams call require an interactive camera test.

## Privacy and architecture

Frames stay on the Mac. The host sends BGRA sample buffers into the camera extension's sink stream; the extension exposes its source stream to Teams. There are no network calls or frame files. The generated castle and costume artwork are the only bundled image assets. No microphone entitlement is requested.

The project uses Apple's camera-extension APIs and local Vision person/face detection. The castle image was generated for this project. All application source is in this repository; no third-party runtime packages are used.
