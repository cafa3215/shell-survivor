# Weapon Carrier Visual Design V1

## Professional Roles Used

- Visual Director: define weapon identity language and silhouette readability.
- Technical Artist: ensure style is performance-safe and reusable in Godot.
- UX Visual Designer: make page presentation clear and scannable.

## Goal

Build a unique "carrier" visual for each weapon so the player can recognize weapon type, firing behavior, and hit effect at a glance from UI and in-combat cues.

## Core Design Principles

- Identity-first: each weapon has a unique carrier silhouette before color/effects.
- Attribute-linked color: color family maps to weapon attribute, but no flat single-color blocks.
- Multi-tone layering: each carrier uses at least 5 tones (deep, base, mid, glow, spark).
- Behavior-visible: firing pattern and hit logic are visible in shape language, not only text.
- Readability under scale: 64px card icon must remain distinguishable.

## Attribute Color Families (Refined)

- Electric (cyan-blue): sharp edges, arc lines, ion sparks.
- Explosive (orange-red): heavy core, pressure rings, ember fragments.
- Frost (cool blue): crystalline ribs, soft mist edge, radial chill wave.
- Heal (emerald): smooth loops, pulse bands, leaf/flow motifs.

Each family uses:

- deep: low-frequency shadow mass
- base: dominant body color
- mid: structural lines and secondary surfaces
- glow: emissive shell
- spark: point highlights and micro accents

## Carrier Structure Spec

Each carrier includes 4 visual layers:

1) Core Body
- Main shape that defines weapon identity.
- Static and readable.

2) Guidance Layer
- Motion hints for firing style (spiral, line, orbit, cone, chain).
- Low alpha, medium speed animation.

3) Impact Signature Layer
- Hit-side motif preview (burst ring, chain fork, freeze crack, heal pulse).
- Triggered or periodic pulse.

4) Upgrade Mark Layer
- Level markers and evolved state accent.
- Avoid overpowering core body.

## Weapon-to-Carrier Mapping (Current Weapons)

- kunai -> "Mag-Slit Dagger Pod"
  - firing cue: linear slit tracer
  - hit cue: thin pierce flash

- quantum_ball -> "Phase Sphere Cage"
  - firing cue: orbiting field ring
  - hit cue: bounce spark halo

- lightning -> "Arc Fork Emitter"
  - firing cue: segmented chain arcs
  - hit cue: multi-branch fork flash

- rocket -> "Pressure Rocket Chamber"
  - firing cue: thick thrust plume
  - hit cue: concentric shock ring

- molotov -> "Thermal Flask Core"
  - firing cue: lobbed ember trail
  - hit cue: sticky burn puddle glyph

- guardian -> "Orbit Shield Hub"
  - firing cue: rotating guard blades
  - hit cue: repel pulse

- drone_ab -> "Twin Relay Drone Core"
  - firing cue: paired alternating beams
  - hit cue: synced impact twin spark

- boomerang -> "Return Arc Frame"
  - firing cue: curved return path arc
  - hit cue: re-entry slash pulse

- frost_aura -> "Cryo Field Resonator"
  - firing cue: expanding frost ring
  - hit cue: freeze crack + slow haze

- stun_mine -> "Pulse Trap Node"
  - firing cue: charging blink
  - hit cue: radial stun wave

- heal_aura -> "Bio-Regen Halo"
  - firing cue: soft pulse petals
  - hit cue: uplift wave + clean spark

## Page Presentation Layout

- Left rail: carrier list (icon + short role tag).
- Center: large carrier view (idle + loop animation).
- Right panel:
  - attribute
  - firing mode
  - hit signature
  - evolved marker

## Motion Rules (UI)

- Idle motion amplitude: low (1.0x baseline).
- Guidance motion amplitude: medium (0.6x baseline).
- Impact signature preview: short pulse, max 350ms.
- No full-screen bloom. Keep local contrast controlled.

## Technical Constraints

- Keep card icon source at 512x512.
- Export page icon at 256 and 64.
- Emissive alpha cap: 0.72.
- Peak particle-equivalent count per carrier preview: <= 24.
- Avoid full-screen additive overlays.

## V1 Deliverables

- Carrier concept cards for 4 attribute families.
- Palette definitions with 5 tones each.
- Reusable texture kit:
  - energy_surface
  - carrier_ring_icon
  - accent_shape_sheet

## Acceptance Checklist

- Distinguishable at 64px icon size.
- Attribute can be guessed without reading text.
- Firing and hit behavior is inferable from shape cues.
- No single-flat-color look.
- Compatible with current Godot UI performance budget.
