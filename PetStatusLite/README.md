# Pet Status Lite

A compact status panel for Hunter pets in WoW Forever.

Extract `PetStatusLite.zip` into `_forever_/Interface/AddOns/`. The resulting path should be `AddOns/PetStatusLite/PetStatusLite.toc`. Enable Pet Status Lite and log in on a Hunter.

- Left-click the minimap button or type `/petstatuslite` to show or hide the panel.
- Right-click the button or type `/petstatuslite options` to choose which stats to show.
- Drag the panel with the left mouse button to move it. Position, visibility, and stat choices are saved per character.

The panel shows your active pet's level, XP remaining to the next level, loyalty rank, and happiness as the hunger indicator. A pet at your level shows **At your level** in the XP row.

- **XP bubble bar** fills across ten segments as your pet earns XP toward its next level. It has its own toggle and is enabled by default.
- **XP per hour** and **Catch-up ETA** are off by default. Enable either in Options. They use the last five minutes of pet XP gains, with at least 30 seconds of tracking and two observed gains before showing a pace. Tracking continues with the panel hidden while either option is enabled.

Catch-up ETA targets your Hunter's current level. For each additional level beyond the next one, it uses your pet's current level XP requirement as an approximation. Pace starts over after a reload, when your active pet changes, or after a long break from earning pet XP.
