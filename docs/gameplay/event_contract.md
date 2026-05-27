# Combat Event Contract

This document defines the runtime event contract for combat systems.
All modules (program, animation, VFX, SFX, UI, AI) must integrate through these events.

## 1. Goals

- Decouple combat logic from content presentation.
- Keep animation timing, hit detection, VFX, SFX, and UI feedback in sync.
- Make skill behavior data-driven and testable.

## 2. Ownership Rules

- Program layer is the source of truth for hit validation, damage, cooldown, and state transitions.
- Animation layer emits timeline events but does not apply damage directly.
- VFX/SFX/UI listen to events and render feedback without mutating gameplay state.
- AI consumes the same public events as player-facing systems.

## 3. Core Events

### 3.1 Skill lifecycle

#### `OnSkillCastStart`

- Purpose: skill enters cast phase.
- Payload:
  - `skill_id: String`
  - `caster_id: int`
  - `cast_seq: int` (monotonic per caster)
  - `timestamp_ms: int`

#### `OnSkillActive`

- Purpose: skill enters active phase (can hit or spawn projectile).
- Payload:
  - `skill_id: String`
  - `caster_id: int`
  - `cast_seq: int`
  - `frame_index: int`
  - `timestamp_ms: int`

#### `OnSkillHit`

- Purpose: confirmed hit result from authority layer.
- Payload:
  - `skill_id: String`
  - `caster_id: int`
  - `target_id: int`
  - `cast_seq: int`
  - `damage_type: String`
  - `final_damage: float`
  - `is_critical: bool`
  - `timestamp_ms: int`

#### `OnSkillEnd`

- Purpose: skill exits lifecycle.
- Payload:
  - `skill_id: String`
  - `caster_id: int`
  - `cast_seq: int`
  - `reason: String` (`finished` / `cancelled` / `interrupted`)
  - `timestamp_ms: int`

### 3.2 Character state

#### `OnCharacterStateChanged`

- Purpose: state machine transition notification.
- Payload:
  - `character_id: int`
  - `from_state: String`
  - `to_state: String`
  - `timestamp_ms: int`

### 3.3 Buff and debuff

#### `OnBuffApplied`

- Payload:
  - `buff_id: String`
  - `source_id: int`
  - `target_id: int`
  - `duration_ms: int`
  - `stack_after_apply: int`
  - `timestamp_ms: int`

#### `OnBuffExpired`

- Payload:
  - `buff_id: String`
  - `target_id: int`
  - `timestamp_ms: int`

## 4. Integration by Domain

### Program

- Emits authoritative events.
- Rejects duplicated `cast_seq` and invalid state transitions.
- Guarantees order for one caster: `CastStart -> Active -> (Hit*) -> End`.

### Animation

- Emits local timeline markers to program via animation notifies.
- Uses `HitFrame` from skill table; avoid hard-coded delays.

### VFX/SFX

- Subscribe to `OnSkillCastStart`, `OnSkillHit`, `OnSkillEnd`.
- Resolve effect IDs from skill data table (`FX_OnCast`, `SFX_OnHit`, etc.).
- Must handle missing assets gracefully and log one warning per skill ID.

### UI

- Skill slot updates cooldown from `OnSkillCastStart`.
- Damage numbers only spawn from `OnSkillHit` (never from animation marker).
- State widgets (stun, invincible, channeling) listen to state/buff events.

## 5. Reliability Requirements

- Event names are immutable once released.
- New fields can only be additive; never change existing field types.
- All timestamps use integer milliseconds.
- String IDs are ASCII with `_` separators (example: `SK_Player_DashSlash_01`).

## 6. Debug and Validation

- Add a debug overlay to show:
  - current skill phase
  - latest `cast_seq`
  - hitbox/hurtbox visibility
  - last 10 received combat events
- Validation checklist for every new skill:
  - lifecycle events complete and ordered
  - hit event count matches design expectation
  - VFX/SFX/UI all react without direct coupling
  - cancel/interruption path produces `OnSkillEnd`

## 7. Minimal Godot Signal Mapping (Reference)

Example mapping for implementation planning:

- `skill_cast_start(skill_id, caster_id, cast_seq, timestamp_ms)`
- `skill_active(skill_id, caster_id, cast_seq, frame_index, timestamp_ms)`
- `skill_hit(skill_id, caster_id, target_id, cast_seq, damage_type, final_damage, is_critical, timestamp_ms)`
- `skill_end(skill_id, caster_id, cast_seq, reason, timestamp_ms)`
- `character_state_changed(character_id, from_state, to_state, timestamp_ms)`
- `buff_applied(buff_id, source_id, target_id, duration_ms, stack_after_apply, timestamp_ms)`
- `buff_expired(buff_id, target_id, timestamp_ms)`
