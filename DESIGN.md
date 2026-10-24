---
name: VibeBreak
description: A quiet native macOS control surface for agent lifecycle actions.
typography:
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
spacing:
  compact: "8px"
  control: "12px"
  section: "24px"
---

# Design System: VibeBreak

## Overview

**Creative North Star: "The Native Relay Panel"**

VibeBreak should look and behave like a small part of macOS rather than a
branded dashboard. The interface is operational: state, configuration, testing,
and recovery are visible without onboarding copy or decorative content.

The system inherits standard AppKit and SwiftUI behavior, including dynamic
system colors, keyboard navigation, focus rings, increased contrast, and
reduced motion.

**Key Characteristics:**

- Native controls and familiar macOS terminology.
- Restrained density with one clear task per section.
- Semantic status communicated by text and color together.
- No custom chrome, illustration, or marketing surface inside the app.

## Colors

VibeBreak uses macOS semantic colors rather than fixed light-mode values.

- **Accent:** the user's system accent for enabled controls and selection.
- **Primary label:** system primary text for control labels and values.
- **Secondary label:** system secondary text for paths and supporting state.
- **Success:** system green plus a textual “正在监听” state.
- **Warning:** system orange for connecting or recoverable attention states.
- **Error:** system red with an error icon and recovery copy.

**The Semantic Color Rule.** Never replace system semantic colors with fixed
hex values; light mode, dark mode, increased contrast, and user accent must stay
native.

## Typography

**Display Font:** none

**Body Font:** macOS system font

**Label Font:** macOS system font

The hierarchy comes from native Form roles rather than a custom type scale:
window title, tab labels, section headings, labels, values, and secondary path
text. Paths may use the system monospaced caption style because they are literal
filesystem data.

**The Utility Type Rule.** Do not introduce display typography, tracked labels,
or decorative monospace. This is a repeated-use utility.

## Layout

The settings window uses a stable 610 × 520 pt content area with two top-level
tabs: Automation and Diagnostics. Each tab contains one grouped Form with 12 pt
outer padding.

Automation follows this order:

1. enabled state and aggregate source health;
2. event source toggles and per-source health;
3. start and completion actions;
4. action tests and application refresh;
5. configuration or runtime errors.

Diagnostics follows this order:

1. per-source and task state;
2. local paths;
3. diagnostic commands;
4. privacy boundary.

## Elevation & Depth

Depth is entirely native. The window and grouped Form provide tonal layering;
the app adds no shadows, glass, blur, or floating panels.

**The Flat-by-Default Rule.** A control receives depth only from its standard
macOS state. No decorative elevation is added.

## Shapes

Controls use system-defined macOS shapes. Grouped Form sections provide the only
container rounding. Pills are limited to the native segmented completion
control; buttons and pickers keep their standard silhouettes.

## Components

### Status

A small semantic dot is paired with a textual source state. Color never carries
meaning alone.

### Source Integration

Each source row distinguishes an enabled watcher from an installed upstream
integration. Managed hook/plugin sources expose a compact install action and an
installed menu with a safe remove command. Manual Bridge sources are labeled
manual instead of claiming they are connected.

### Application Picker

The standard macOS picker shows the installed app icon and display name. A
missing selected app is labeled unavailable, followed by an inline recovery
message. There is no fallback application.

### Completion Strategy

A three-option segmented control selects “打开应用”, “恢复原应用”, or
“保持当前应用.” The completion application picker is conditionally visible
only for the first strategy.

### Action Buttons

Test and refresh actions use system symbols with explicit text. A test action is
disabled when its configured app is unavailable.

### Errors

Errors appear inline after the action sections with a system warning symbol,
plain recovery text, selectable details, and a labeled dismiss control when the
error is transient.

## Do's and Don'ts

### Do:

- **Do** use standard SwiftUI and AppKit controls before creating a custom one.
- **Do** keep start and completion choices visible on the same settings tab.
- **Do** expose source failures and incompatible schemas without guessing.
- **Do** pair every semantic color with text or an icon label.
- **Do** test long app names and missing applications.

### Don't:

- **Don't** turn settings sections into nested custom cards.
- **Don't** add productivity scores, engagement metrics, or decorative charts.
- **Don't** use hidden keyword fallbacks for agent lifecycle detection.
- **Don't** disable native focus, contrast, or keyboard behavior for styling.
- **Don't** claim a source is connected unless its schema gate has passed.
