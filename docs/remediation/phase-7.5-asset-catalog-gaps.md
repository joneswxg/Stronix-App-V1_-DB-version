# Phase 7.5: Asset catalog gaps

## Inventory and decision

`AppIcon.appiconset` supplies one iOS universal 1024 × 1024 icon, `1024.png`. Its catalog declares only that shipped file. Dark and tinted app-icon variants are not declared because no brand-approved artwork was supplied.

`StronixLogo.imageset` supplies one universal 1x image, `512.png`. Its catalog declares only that shipped file. The `StronixLogo` name remains unchanged for the existing SwiftUI call sites.

macOS app-icon variants are not declared because the app target supports iPhone only.

## Follow-up artwork requirements

When approved source artwork becomes available, add the corresponding catalog entries and files together:

- Dark and tinted app-icon variants require dedicated, brand-approved 1024 × 1024 source images.
- Native 2x and 3x logo variants require a vector master or sufficiently high-resolution raster source exported at the intended scales.
- macOS icon sizes are needed only if the app target adds macOS support.

Do not create these variants by upscaling the existing raster images: that fills catalog slots without improving visual fidelity.

## Validation

Build the app with Xcode after catalog changes and confirm the asset compiler reports no warnings. Check the installed app icon and the logo on representative login and profile screens in Simulator.
