# 21 - Game Design for the C64

Designing *with* the constraints rather than against them, and the design lessons that
modern C64 releases have learned the hard way.

---

## 1. The constraints are the design brief

| Constraint | Design implication |
|---|---|
| 8 sprites per raster line | Enemies must **spread vertically**. Design encounters, not crowds |
| 16 KB VIC bank | A limited visual vocabulary per area. Lean into distinct "worlds" |
| 1 colour per 8×8 cell | Bold, flat, high-contrast art. Not painterly |
| 3 SID voices | Music and SFX compete. Design moments of silence |
| ~12,000 usable cycles/frame | Simple per-entity logic; ~20–30 active entities max |
| Slow loading (floppy) | Either long levels, or streaming, or a cartridge |
| 1-button joystick | **This is the biggest design constraint of all** |

### The one-button problem

A standard C64 joystick has 4 directions and **one fire button**. Every action must map to
direction + fire combinations, contextual behaviour, or modes.

Proven approaches:
- **Contextual fire** - fire does the sensible thing for the current situation.
- **Direction + fire modifiers** - down+fire = crouch attack, up+fire = jump.
- **Hold vs tap** - tap fires, hold charges. Very readable.
- **Mode switching** - *Sam's Journey*'s six costumes each redefine abilities, turning a
  control problem into a design feature.
- **Second joystick port** for two-player, or keyboard for secondary functions (pause,
  map, inventory) that aren't needed during action.

**Design the control scheme before the mechanics.** A mechanic that needs three buttons is
not a C64 mechanic.

---

## 2. Design lessons from modern releases

These come directly from the case studies in [`19-case-studies.md`](19-case-studies.md).

### "Very few players viewed the instructions"

From the *Cab Hustle* retrospective, and the single highest-value design insight for this
platform. Modern players - including retro enthusiasts - **do not read the manual**, even
when it's one click away and even when it answers their exact complaint.

Consequences:
- Mechanics must be **discoverable through play**.
- The first 30 seconds must teach the core verb.
- If something needs explaining, explain it **in the game**, at the moment it's relevant.
- A "how to play" screen in the title menu is better than a text file, and an interactive
  first level is better than both.

### Err on the easy side

*Cab Hustle*'s physics were "too hard for most players," splitting the audience. The
modern C64 audience is largely **nostalgic adults with limited time**, not teenagers with
infinite afternoons. The new Commodore 64 Ultimate has brought in owners who are newer
still.

- Design the difficulty curve for someone who will give you 20 minutes.
- Offer difficulty options if in doubt - they're cheap.
- Save/continue systems are near-mandatory now.

### Reject the 80s defaults

*Sam's Journey* deliberately has **no limited lives and no game-over screen**. Players
explore, advance, and save freely. This was a conscious rejection of arcade-era design and
is widely cited as one reason it landed so well.

Modern-friendly defaults:

| 80s default | Modern replacement |
|---|---|
| 3 lives, then restart from level 1 | Checkpoints, unlimited retries |
| No saving | Save anywhere, or generous checkpoints |
| Instant death on any contact | Health bar, invulnerability frames |
| Hidden mechanics | Telegraphed, taught in level 1 |
| Trial-and-error level design | Readable, fair, learnable |
| Score as the only goal | Progression and completion |

### Know your audience's expectation

*Cab Hustle* took criticism for blending *Space Taxi* mechanics with *Crazy Taxi* time
pressure and *TurboRaketti* physics - players wanted a straight *Space Taxi* clone. If
your game evokes a classic, players will expect that classic. Either lean in deliberately,
or make the difference obvious from the first screen so nobody feels misled.

---

## 3. Genre fit

Which genres suit the platform, honestly:

| Genre | Fit | Notes |
|---|---|---|
| **Single-screen arcade** | Excellent | No scroll cost, full sprite budget for gameplay. *Bubble Bobble*, *Boulder Dash* |
| **Flip-screen platformer/adventure** | Excellent | Big worlds from small data, no scroll cost. *Soulless*, *Joe Gunn*, *Nixy* |
| **Horizontal shooter** | Excellent | The platform's signature genre. *Armalyte*, *Katakis* |
| **Scrolling platformer** | Good, expensive | *Sam's Journey*, *Turrican*. Needs a real engine |
| **Puzzle** | Excellent | Cheap to implement, high design leverage, ages well |
| **Isometric adventure** | Good | *Last Ninja*. Softsprite masking is the challenge |
| **Turn-based strategy / RPG** | Good, data-hungry | CPU is fine; **data volume needs cartridge or good streaming**. *Eye of the Beholder* |
| **Racing** | Medium | Pseudo-3D road via colour splits and charset tricks |
| **Twin-stick / bullet hell** | Poor | One button; sprite-per-line limit kills bullet density |
| **Real-time strategy** | Poor | Pathfinding at 1 MHz, plus mouse/pointer UX |
| **Text-heavy narrative** | Medium | 40×25 chars is tight; needs a proportional font or careful writing |
| **First-person 3D** | Very hard | Possible (*Grey* at 16 fps), but it's the whole project |

**For a first project:** single-screen arcade, flip-screen, or puzzle. All three let you
spend your effort on game feel rather than on an engine.

---

## 4. Designing around the 8-sprite line limit

This shapes level design more than anything else.

- **Vertical distribution.** If 6 enemies share a horizontal band, one disappears. Design
  encounters that stagger vertically.
- **Reserve slots.** Player (often 2 sprites with an overlay) + player bullets get
  guaranteed slots; enemies compete for the rest.
- **Use character graphics for anything that can be grid-aligned** - static hazards,
  collectibles, blocks, background detail, projectiles that move on a grid. Every object
  moved out of sprites is a sprite freed for something that needs pixel movement.
- **Cull aggressively.** Off-screen entities shouldn't hold sprite slots.
- **Make the limit a mechanic.** "Only N enemies spawn at once" is a legitimate,
  invisible design rule.

---

## 5. Game feel on a 1 MHz machine

What makes C64 games feel good:

| Technique | Cost | Effect |
|---|---|---|
| **Sub-pixel movement** (16-bit positions) | 1 byte/entity | Smooth motion at any speed. Non-negotiable |
| **Acceleration/deceleration** | A few cycles | Weight and momentum |
| **Screen shake** | Free ($D011/$D016 offset) | Impact |
| **Colour flash on hit** | Free ($D027+n or $D020) | Clear feedback |
| **Invulnerability blink** | Free (toggle $D015 bit) | Communicates state |
| **Squash/stretch frames** | 64 bytes/frame | Life and personality |
| **Charset animation in the background** | ~350 cycles | The world feels alive |
| **Colour cycling** ($D021–$D024) | Free | Water, lava, energy, atmosphere |
| **Anticipation frames** before an action | Sprite RAM | Readability |
| **Distinct SFX per event** | A few bytes each | Feedback without visuals |
| **Music that changes with state** | Player support | Tension, reward |

**The cheapest wins are colour-based** because the VIC-II gives them away for free. A
game that flashes, cycles, and shakes feels dramatically more responsive than one that
doesn't, at essentially zero CPU cost.

### Responsiveness
Input is read once per frame (50 Hz PAL) - a 20 ms granularity, which is fine. What kills
responsiveness is:
- Animation locking out input (avoid long uninterruptible animations)
- Movement that only starts after an acceleration ramp (add an instant first step)
- Actions that only register on a specific animation frame

---

## 6. Onboarding and communication

Given that nobody reads instructions:

1. **The title screen shows the controls.** One screen, joystick diagram, five words.
2. **The first level is the tutorial** and doesn't announce itself as one. Introduce one
   verb at a time in a safe space.
3. **Telegraph everything.** Enemies wind up before attacking; hazards are visually
   distinct from scenery; interactive objects look interactive.
4. **Use colour as a language** consistently - e.g. anything red hurts you, anything
   yellow is collectible. Then never break it.
5. **A short in-game hint system** costs a few hundred bytes and prevents the most common
   frustration.

---

## 7. Scope guidance

Realistic content targets by project size:

| Project | Content | Effort (part-time) |
|---|---|---|
| **16 KB compo game** | 1 mechanic, 10–20 screens or endless, 2 tunes | 2–6 months |
| **Small commercial game** | 20–40 screens, 4–8 enemy types, 5 tunes | 6–18 months |
| **Mid-size** (*Soulless* class) | 100+ rooms, boss fights, story, 10 tunes | 1–3 years |
| **Large** (*Sam's Journey* class) | 2,000 screens, 27 levels, 19 tunes | Multiple years, 3 people |

*Cab Hustle*: 18 months of occasional weekends for a single-mechanic game. That is a
realistic solo baseline. **Scope so that you'd still be proud of it at 30 % of the
planned content**, because that's what will exist when you run out of enthusiasm.

---

## 8. Design checklist

- [ ] The core verb is clear in the first 10 seconds, without text
- [ ] Every action maps to 4 directions + 1 button
- [ ] Enemies distribute vertically; no more than 8 sprites can share a line
- [ ] There is visible, immediate feedback for: hitting, being hit, collecting, dying
- [ ] The player can save or continue
- [ ] Difficulty is tuned for a competent adult with 20 minutes, not a 1988 teenager
- [ ] Nothing important is explained only in the manual
- [ ] Loading pauses are covered by something (music, art, a tip, an animation)
- [ ] The game is completable, and the ending is worth reaching
- [ ] The first screenshot someone sees communicates what the game is
