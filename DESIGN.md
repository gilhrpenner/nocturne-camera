---
version: alpha
name: Nocturne
description: A native Mac control room for a live vampire camera scene.
colors:
  background: "#111827"
  panel: "#1C2738"
  text: "#E8EDF4"
  muted: "#ADBDCD"
  accent: "#DDA8B4"
  success: "#95CBB7"
typography:
  display:
    fontFamily: "Baskerville, serif"
    fontSize: "36px"
  body:
    fontFamily: "-apple-system, sans-serif"
  utility:
    fontFamily: "SFMono-Regular, monospace"
rounded:
  panel: "12px"
spacing:
  page: "24px"
  section: "20px"
components:
  preview:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.panel}"
  button:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.background}"
  label:
    textColor: "{colors.text}"
  help:
    textColor: "{colors.muted}"
  status:
    textColor: "{colors.success}"
---

# Nocturne design

## Overview

An English-language, single-window macOS tool for Gil's work Halloween party. The user requested a theatrical vampire, person isolation without a green screen, a distant castle, frequent varied lightning, flying bats, vampire attire, stronger makeup with blood trails, and keyboard cues. The product's job is to preview and send that scene to Teams with minimal setup.

The reference is a moonlit gothic stage viewed from its quiet control booth. The scene owns the drama; controls stay familiar and legible. Avoid streaming-studio complexity and decorative dashboard cards.

The signature is the large live castle composition. No animated chrome or ornamental gauges.

## Colors

`App/Theme.swift` is the canonical runtime palette. Its named constants map one-to-one to the frontmatter values; `ContentView` consumes only those tokens for interface colors. Scene artwork/effects have their own cinematic colors and are not UI tokens. Dark surfaces, cool readable text, dusty rose actions, and pale green camera status. Status always has text as well as color.

## Typography

Baskerville for the name and control-panel titles; macOS system text for controls and help; monospaced text for shortcut hints and numeric settings. English only in this first build; system fonts supply fallback glyphs.

## Layout

Native desktop window, minimum 1040 by 680. Header, broad 16:9 preview and cues on the left, 300-point control panel on the right. Main page inset 24 points; sections separated by 20 points. Stable preview footprint while loading. A single scroll container keeps controls reachable on shorter screens. A native segmented Look / Scene / Setup picker switches the right panel while preserving the large preview, camera controls, distance, and cues on the left. Controls retain their values when switching panels; there is no nested scrolling.

## Elevation & Depth

Tonal panel separation, native control borders, and no ornamental shadows. All depth belongs in the castle scene: separate valley, castle, and near terrace layers, restrained head-responsive parallax, and coherent moonlight/flash on the actor. The UI retains its existing flat tonal hierarchy.

## Shapes

12-point panel/preview corners. Controls inherit native macOS geometry and focus rings.

## Components

Canonical owners: controls and confirmation dialogs use SwiftUI; effect cues use `ContentView.cue`; persistent status belongs to `CameraModel` or `ExtensionManager`. No tables, dates, navigation flows, or remote data exist. Hair selection and the three control panels use native SwiftUI pickers. Repeated percentage sliders use `ContentView.amount`; outfit calibration uses a native DisclosureGroup, with width, collar height, hands-in-front, and Reset fit. Look shows a text tracking state instead of an ornamental confidence gauge. No comparable sibling screen exists in this new one-window app.

Start camera explicitly requests camera access. No microphone access. Permission errors stay visible with a recovery instruction. Extension activation reports pending/approval/success/error states. Removal uses a native app-owned confirmation and stops capture first. Camera-off preview is labeled as such. No claim of Teams connectivity before the CMIO sink connects.

Buttons retain native keyboard, hover, pressed, and disabled states. Global Control–Option shortcuts use Carbon registration, not keyboard monitoring. Every shortcut has an on-screen alternative. Normal camera bypasses all effects, and cue buttons are disabled while bypassed.

Four equal cue buttons share one row: Lightning, Bat swarm, Vanish & return, and Grand entrance. The latter two require a running camera and castle cutout, and are disabled during a performance; a fixed-height text area explains unavailable actions or names the current stage. `StagePerformance` owns one timeline for the actor, flock, lightning and feedback. Vanish lasts six seconds and returns automatically. Grand entrance gathers the flock into the person and times lightning to the face reveal. Neither action modifies the ambient scene toggles. Normal camera, loss of the cutout mode, camera stop and capture errors cancel the performance. The transformation's signature is the actual silhouette folding into photographic bats, with temporary image-textured wing shapes and depth, distinct from the distant ambient flock. Scene offers Haunted windows: rare, small silhouettes behind the existing glass and mullions, attached to the castle plane. Scene motion off suppresses these visits; manual performance cues remain intentional user actions.

Look has a native segmented Character picker for Vampire and Batman. Vanish & return alternates them: outgoing fragments use the current look, the appearance changes during the empty interval, and gathering fragments use the incoming look. The selected character persists after the six-second cue; Grand entrance retains it. Cue help names the next character. The picker is disabled during a performance, and the state also rejects overlapping requests. Cancellation settles the character at the current point in the timeline. Batman replaces the vampire-specific controls with a short description and shares the existing fit disclosure. Vampire preferences remain stored and reappear on return. The original stylized cowl has shaded black rubber, sculpted brows, eye holes and a lower-face opening; an affine fit registers to both eyes and the chin. Only those camera regions and detected hands are retained above the armored torso and cape. `HeroArtwork` owns the generated-once native artwork; `HeroCostume` owns the face attachment and compositing. These effects are scene art, not UI tokens. Normal camera remains a pixel-preserving bypass for both characters.

A Distance slider below the preview controls subject scale with Original/Farther labels, a size percentage, and Reset. It is disabled when the castle cutout is off or normal camera is on. Blood trails and vampire attire have separate switches. A native Hair picker offers Natural, Black + silver temples, Silver-gray, Icy white, and Deep black with a separate strength slider; Natural disables that slider. Icy white at 100% is the requested default, with strand contrast and a tighter forehead guard. Makeup covers the broader head and neck with soft, color-selective masks. The costume is a textured photographic garment overlay with a swept black collar, restrained red piping, and independent torso tracking. Perspective fitting follows shoulders and hips, with a final stabilizer that smooths position separately from shape and suppresses tiny changes. The real torso is removed when attire and the castle cutout are on; only the head, ears, hair, neck and detected hands remain. Hand occlusion lets gestures appear in front. Contacts follow detected pupils, have shaded crimson irises and round dark pupils, and are clipped by the eyelids; surrounding eye shadow is softer. The fit disclosure stays open initially so its adjustments are discoverable. The Scene panel contains Living scene, Scene motion, Depth, Moonlight, Rain, bats, lightning, and Fog amount. Living scene selects the layered perspective environment; its scenery controls are disabled for the classic backdrop. Each scene percentage slider reaches zero to disable its effect. Fog amount controls rising billows that fade out two-thirds up the frame. System reduced-motion preference freezes fog, blood, perspective, mist, and rain and disables automatic bats/lightning initially; explicit cue buttons remain intentional user actions. A plain wall and even face lighting are recommended for segmentation quality. Person cutout failure displays the castle rather than leaking the room.

## Do's and Don'ts

- Keep processing local and frames in memory.
- Make installation and removal status explicit.
- Keep the scene preview and camera-off state honest.
- Do not turn on the physical camera automatically at launch.
- Do not hide failed activation behind a success badge.
