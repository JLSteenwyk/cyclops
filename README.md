# Pocus

Pocus is a small, native macOS menu-bar app that keeps your selected window clear while blurring and dimming everything around it. Change windows normally and the focus area follows you across displays and Spaces.

## Features

- Follows the frontmost window automatically.
- Handles multiple displays, windows that span displays, and full-screen Spaces.
- Lets you pause the effect and choose backdrop strength or focus padding from the menu bar.
- Passes every click through to the apps beneath the overlay.
- Runs locally and never records, stores, or transmits screen contents.

## Requirements

- macOS 13 Ventura or newer
- Xcode or the Xcode Command Line Tools

## Build and run

```sh
make app
open dist/Pocus.app
```

On first launch, approve Pocus in **System Settings → Privacy & Security → Accessibility**. Pocus uses that permission only to read the position and size of the focused window. It does not request Screen Recording permission and does not inspect window contents or keyboard input.

The finished app bundle is `dist/Pocus.app`. You can drag it into `/Applications` if you want to keep it installed. Launch the app from its final location before granting Accessibility permission, because macOS associates that permission with the app's path and signature.

## Use

1. Select any app window.
2. Pocus leaves that window clear and applies a blurred backdrop everywhere else.
3. Use the viewfinder icon in the menu bar to pause, resume, or adjust the effect.
4. Quit from the same menu when you are done.

If no regular window is selected (for example, while the desktop is active), Pocus temporarily hides the backdrop.

## Development

```sh
make build
make test
```

Pocus is implemented with AppKit, the macOS Accessibility API, and `NSVisualEffectView`. There are no third-party dependencies and no network access.
