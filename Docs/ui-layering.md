# UI layering

Minimizer uses shared Halo and spell renderer components for Target and Focus overlays.

- Halo frames inherit the strata and frame level context of their host and never call `SetFrameStrata`.
- Target host frames are nameplate frames and use relative frame levels.
- Focus portrait frames are parented to the nameplate and use relative frame levels.
- Mouse overlays use their own host context.
- The old player-center Wheel and Pip system has been removed.

`Minimizer.toc` loads `Overlays/Halo.lua` before `Overlays/Focus.lua`, `Overlays/Target.lua`, and `Overlays/Mouse.lua`.
