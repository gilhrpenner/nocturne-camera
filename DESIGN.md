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

Baskerville for the name and two section titles; macOS system text for controls and help; monospaced text for shortcut hints and numeric settings. English only in this first build; system fonts supply fallback glyphs.

## Layout

Native desktop window, minimum 1040 by 680. Header, broad 16:9 preview and cues on the left, 300-point control panel on the right. Main page inset 24 points; sections separated by 20 points. Stable preview footprint while loading. A scroll container keeps controls reachable on shorter screens.

## Elevation & Depth

Tonal panel separation, native control borders, and no ornamental shadows. All depth belongs in the castle scene.

## Shapes

12-point panel/preview corners. Controls inherit native macOS geometry and focus rings.

## Components

Canonical owners: controls and confirmation dialogs use SwiftUI; effect cues use `ContentView.cue`; persistent status belongs to `CameraModel` or `ExtensionManager`. No tables, selects, dates, navigation flows, or remote data exist. No comparable sibling screen exists in this new one-window app.

Start camera explicitly requests camera access. No microphone access. Permission errors stay visible with a recovery instruction. Extension activation reports pending/approval/success/error states. Removal uses a native app-owned confirmation and stops capture first. Camera-off preview is labeled as such. No claim of Teams connectivity before the CMIO sink connects.

Buttons retain native keyboard, hover, pressed, and disabled states. Global Control–Option shortcuts use Carbon registration, not keyboard monitoring. Every shortcut has an on-screen alternative. Normal camera bypasses all effects, and cue buttons are disabled while bypassed.

A Distance slider below the preview controls subject scale with Original/Farther labels, a size percentage, and Reset. It is disabled when the castle cutout is off or normal camera is on. Blood trails and vampire attire have separate switches. The costume is a textured photographic garment overlay with a swept black collar, restrained red piping, and smoothed tracking. System reduced-motion preference freezes blood trails and disables automatic bats/lightning initially; explicit cue buttons remain intentional user actions. A plain wall and even face lighting are recommended for segmentation quality. Person cutout failure displays the castle rather than leaking the room.

## Do's and Don'ts

- Keep processing local and frames in memory.
- Make installation and removal status explicit.
- Keep the scene preview and camera-off state honest.
- Do not turn on the physical camera automatically at launch.
- Do not hide failed activation behind a success badge.
