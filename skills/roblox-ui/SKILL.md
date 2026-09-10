---
description: Roblox UI and visual effects patterns — responsive scaling, TweenService animation, CanvasGroup clipping, ViewportFrames, particle gotchas, and juicy game-feel effects. Use when building or reviewing ScreenGuis, HUDs, shop/inventory interfaces, animations, or VFX in Roblox.
---

# Roblox UI & VFX

Roblox UIs run on screens from 4" phones to ultrawide monitors. The patterns
here make interfaces that scale, animate smoothly, and feel juicy without
melting frames.

## Responsive Sizing

- **Scale, not Offset**, for anything that should adapt:
  `UDim2.fromScale(0.3, 0.1)`. Reserve Offset for hairlines/borders.
- **`UIAspectRatioConstraint`** keeps square things square (item slots,
  avatars) while the container scales.
- **`UITextSizeConstraint`** + `TextScaled = true` bounds text so it neither
  overflows on phones nor becomes a billboard on desktop.
- **`UIListLayout` / `UIGridLayout` + `UIPadding`** instead of hand-positioned
  children — then adding the 9th item never breaks the layout. Set
  `AutomaticCanvasSize` on ScrollingFrames with layouts.
- `ScreenGui.IgnoreGuiInset` + `ScreenInsets`/safe-area awareness for
  full-bleed art; keep interactive controls out of device notch/home-bar
  regions.
- Test at minimum in Studio's device emulator: small phone, tablet, desktop.
  A UI signed off only on desktop is broken for most Roblox players (mobile
  is the majority platform).

## Animation: TweenService, not manual easing

```lua
--!strict
local TweenService = game:GetService("TweenService")

local OPEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function openPanel(panel: Frame)
	panel.Visible = true
	panel.Size = UDim2.fromScale(0, 0)
	TweenService:Create(panel, OPEN_INFO, { Size = UDim2.fromScale(0.4, 0.5) }):Play()
end
```

- Hand-rolled `RenderStepped` easing loops are jittery, leak connections, and
  can't be cancelled cleanly. TweenService handles all of it. Keep a passive
  frame loop only for what tweens can't express (e.g. triggering a sound at an
  animation midpoint).
- Reuse `TweenInfo` constants; define an animation vocabulary
  (`FAST = 0.15 Quad`, `BOUNCY = 0.3 Back`) so the whole UI feels coherent.
- Cancel the previous tween before starting a new one on the same property
  (`tween:Cancel()`), or rapid open/close spams fight each other. Track the
  live tween per element.
- Tween `GroupTransparency`/`Position`, not per-child transparency loops.

## CanvasGroup: the clipping and fade workhorse

`ClipsDescendants` clips to the *rectangle* — rounded corners leak. 
**`CanvasGroup` + `UICorner` clips children to the rounded shape**, which is
the clean solution for:

- shimmer/sheen sweeps across rounded buttons and cards,
- sliding elements inside rounded panels,
- fading a whole panel at once via `GroupTransparency` (one property, all
  children, correct compositing — instead of tweening every descendant).

Costs: each CanvasGroup renders to a texture (memory + a resolution ceiling);
don't nest them deeply or use them on huge/frequently-resized containers.
Text inside a CanvasGroup can look slightly soft — keep body text outside
when crispness matters.

## ViewportFrames (3D in UI)

For item/character previews in inventories and shops:

- Clone the model into the ViewportFrame, set a dedicated `Camera`, frame the
  subject via its bounding box (`model:GetBoundingBox()` → position camera at
  a distance derived from the box size, not hardcoded offsets — hardcoded
  offsets break on small or oddly-shaped models).
- Add a `WorldModel` inside the ViewportFrame only if you need animation
  (Humanoids/Animators require it); it costs more.
- ViewportFrames re-render when contents/camera change; a slow idle spin is
  fine, per-frame full-scene updates across 20 slots are not. Consider a
  single shared "photo booth" ViewportFrame + captured thumbnails for large
  grids.

## Particles & World-Space VFX Gotchas

- **ParticleEmitters do not render when parented inside Union operations.**
  Parent the emitter to a normal (invisible, non-collidable) Part positioned
  where you need it.
- Several particle behaviors only preview in Play mode — judge VFX in Play
  solo, not the edit viewport.
- `emitter:Emit(n)` for bursts (pickup, hit flash); leave `Enabled = false`.
  Enabled emitters on projectiles/mobs must be capped (`Rate`, `Lifetime`)
  and pooled — see roblox-performance.
- World-space damage numbers/health bars: `BillboardGui` (attached, scales
  with distance settings) — set `MaxDistance`; hundreds of always-on
  billboards are a real cost.
- For world→screen effects (e.g. "coin flies from mob to your counter"):
  `Camera:WorldToViewportPoint` at the start position, then tween a UI element
  — cheaper and more controllable than a physical part flying at the camera.
- Targeting/anchoring effects on characters: derive positions from
  `model:GetBoundingBox()` or a named attachment, not fixed Y-offsets that
  break on small or flying rigs.

## Game Feel (juice) Cheatsheet

Effects that make actions feel good, ordered by cost-effectiveness:

1. **Scale pop**: tween to 1.1× and back (0.1s out, 0.15s back) on
   press/reward.
2. **Color flash**: brief white/bright overlay frame on the element.
3. **Sound**: every meaningful interaction gets one (with slight random
   `PlaybackSpeed` variation to avoid fatigue).
4. **Count-up numbers**: tween a NumberValue and render it, rather than
   snapping `1,240 → 2,380`.
5. **Particle burst** at the reward source.
6. **Camera/UI shake**: tiny (2–4 px, 0.15 s) and rare — big wins only.
7. **Anticipation beats payoff**: a 0.3 s wind-up (shake, glow build) before a
   reveal reads better than an instant result. The wait itself is part of the
   reward loop.

## Structure & Review Red Flags

| Red flag | Fix |
| --- | --- |
| Pixel Offsets everywhere | Convert to Scale + constraints. |
| `RenderStepped` easing loops for UI | TweenService. |
| Tweening 30 children's transparency separately | CanvasGroup + `GroupTransparency`. |
| UI built entirely from Instance.new in code, or entirely hand-edited with no source of truth | Either works — but pick one per UI and keep it; hybrid drift makes every edit a hunt. Keep static layout in Studio/Rojo-synced instances, dynamic lists code-generated from templates. |
| ScreenGui logic reading game state directly from workspace | Client controllers receive state via remotes/signals (see roblox-architecture); UI renders, it doesn't compute. |
| Buttons with no pressed/hover/disabled states | Minimum: pressed scale pop + disabled desaturation. |
| Shop opens instantly with no transition | 0.2–0.3 s open animation; UIs that snap feel broken. |

When you (Claude) build UI: mock the layout hierarchy first (frames,
layouts, constraints as a tree with Scale sizes), confirm it reads at phone
size, then wire animation constants and state — visuals before logic.
