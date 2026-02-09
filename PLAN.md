# PICO-8 Snake Game — Implementation Plan

## Overview

A classic Snake game built as a single PICO-8 cartridge (`snake.p8`) using Lua. The player controls a snake that moves on a grid, eats food to grow longer, and dies on collision with walls or itself. Features include a title screen, score display, increasing speed, sound effects, and custom pixel-art sprites.

## Project Structure

```
pico8-snake/
├── PLAN.md        # This file
├── AGENTS.md      # AI agent notes
└── snake.p8       # The complete PICO-8 cartridge (single file)
```

## Cartridge File Format

The `snake.p8` file follows the standard PICO-8 text cartridge format. Sections appear in this order:

```
pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tab 0: main (game loop & state machine)
-->8
-- tab 1: snake logic
-->8
-- tab 2: food & scoring
-->8
-- tab 3: rendering
-->8
-- tab 4: screens (title & game over)
__gfx__
(spritesheet hex data — 128 hex digits per row, up to 128 rows)
__gff__
(sprite flags — omitted if empty)
__map__
(map hex data — omitted if empty)
__sfx__
(sound effect data — 64 lines of 168 hex digits each)
__music__
(music pattern data — omitted if empty)
```

Tabs within the `__lua__` section are separated by the `-->8` marker on its own line.

## Code Organization (Tabs)

| Tab | Name      | Responsibility                                         |
|-----|-----------|--------------------------------------------------------|
| 0   | `main`    | `_init()`, `_update()`, `_draw()`, game state machine  |
| 1   | `snake`   | Snake data structure, movement, growth, self-collision  |
| 2   | `food`    | Food spawning, eat detection, score tracking            |
| 3   | `render`  | Drawing the grid, snake, food, score HUD, border        |
| 4   | `screens` | Title screen, game over screen, restart logic           |

## Constants & Grid Layout

PICO-8 screen is 128x128 pixels. The game uses an 8px grid:

| Constant    | Value | Notes                                                      |
|-------------|-------|------------------------------------------------------------|
| `grid_size` | 8     | Pixels per cell (matches PICO-8 8x8 sprite size)          |
| `grid_w`    | 15    | Playfield width in cells (120px, 4px border each side)     |
| `grid_h`    | 14    | Playfield height in cells (112px, top HUD + bottom border) |
| `ox`        | 4     | Pixel X offset for playfield origin                        |
| `oy`        | 10    | Pixel Y offset for playfield origin (below HUD)           |

Grid coordinates are 1-based: `(1,1)` is the top-left cell of the playfield.

Pixel conversion: `px = ox + (cell_x - 1) * grid_size`, `py = oy + (cell_y - 1) * grid_size`

## PICO-8 Color Reference

| Index | Color       | Usage in this game         |
|-------|-------------|----------------------------|
| 0     | Black       | Background                 |
| 3     | Dark green  | Snake body segments        |
| 5     | Dark gray   | Playfield border           |
| 6     | Light gray  | UI prompt text             |
| 7     | White       | Score text, highlights     |
| 8     | Red         | Food apple, "game over"    |
| 11    | Green       | Snake head, title text     |

---

## Task 1 — Project Scaffolding & Game State Machine

**Tab**: 0 (`main`)
**Depends on**: Nothing (first task)
**Goal**: Create the `.p8` file with the correct header, all section delimiters, and the core game loop with state machine.

### Requirements

1. Create the file `/root/code/pico8-snake/snake.p8` with the PICO-8 cartridge header:
   ```
   pico-8 cartridge // http://www.pico-8.com
   version 42
   ```
2. Add the `__lua__` section with 5 tab markers (`-->8` between each tab).
3. Add empty `__gfx__`, `__gff__`, `__map__`, `__sfx__`, and `__music__` section delimiters as placeholders.
4. Implement a game state machine with three states:
   - `"title"` — title/start screen
   - `"playing"` — active gameplay
   - `"gameover"` — death screen

### Code to implement in Tab 0

```lua
-- tab 0: main

-- constants
grid_size = 8
grid_w = 15
grid_h = 14
ox = 4
oy = 10

-- game state
state = "title"
tick = 0
speed = 6  -- snake moves every N frames

function _init()
  state = "title"
  tick = 0
  speed = 6
  snake_init()
  food_init()
end

function _update()
  if state == "title" then
    update_title()
  elseif state == "playing" then
    update_game()
  elseif state == "gameover" then
    update_gameover()
  end
end

function _draw()
  if state == "title" then
    draw_title()
  elseif state == "playing" then
    draw_game()
  elseif state == "gameover" then
    draw_gameover()
  end
end

function update_game()
  snake_input()
  tick += 1
  if tick >= speed then
    tick = 0
    snake_move()
    food_update()
    snake_check_collision()
    if not snake.alive then
      sfx(1)
      state = "gameover"
    end
  end
end
```

### Stub functions to include (filled by later tasks)

Place these at the bottom of Tab 0 so the file is runnable at every stage:

```lua
-- stubs (replaced by real implementations in later tabs)
function snake_init() end
function snake_input() end
function snake_move() end
function snake_check_collision() end
function snake_draw() end
function food_init() end
function food_update() end
function food_draw() end
function update_title() end
function draw_title() end
function update_gameover() end
function draw_gameover() end
function draw_game() end
```

### Acceptance criteria

- The `.p8` file is valid and parseable by PICO-8.
- Running the cartridge cycles through `title -> playing -> gameover -> title` (once other tabs are wired in).
- All constants are defined and accessible globally.
- The tick-based movement timer works: `snake_move()` is called every `speed` frames.

---

## Task 2 — Snake Logic

**Tab**: 1 (`snake`)
**Depends on**: Task 1 (constants `grid_w`, `grid_h` must exist)
**Goal**: Implement the snake data structure, directional input, grid-based movement, growth, and collision detection.

### Data structure

```lua
snake = {
  body = {},       -- ordered list of {x, y} grid coords; index 1 = head
  dir = 1,         -- current direction: 0=left, 1=right, 2=up, 3=down
  next_dir = 1,    -- buffered input (prevents 180-degree reversal mid-frame)
  alive = true,    -- set to false on collision
  grow = 0         -- segments to add (incremented when food is eaten)
}
```

Direction deltas:

```lua
dx = {[0]=-1, [1]=1, [2]=0, [3]=0}
dy = {[0]=0, [1]=0, [2]=-1, [3]=1}
```

### Functions to implement

#### `snake_init()`

- Reset the snake to the center of the grid, 3 segments long, moving right:
  ```lua
  snake.body = {{x=9,y=7},{x=8,y=7},{x=7,y=7}}
  snake.dir = 1
  snake.next_dir = 1
  snake.alive = true
  snake.grow = 0
  ```

#### `snake_input()`

- Read directional buttons using `btn()`:
  - `btn(0)` = left, `btn(1)` = right, `btn(2)` = up, `btn(3)` = down
- **Reversal prevention**: Do NOT accept a direction that is the direct opposite of the current `snake.dir`.
  - Opposite pairs: left(0) <-> right(1), up(2) <-> down(3)
  - Check: if `abs(new_dir - snake.dir) == 1` and `min(new_dir, snake.dir) % 2 == 0`, it's a reversal — reject it.
  - Simpler approach: store opposites in a table: `opposite = {[0]=1,[1]=0,[2]=3,[3]=2}` and reject if `new_dir == opposite[snake.dir]`.
- Store accepted direction in `snake.next_dir`.

#### `snake_move()`

- Apply `snake.next_dir` to `snake.dir`.
- Calculate new head position:
  ```lua
  local head = snake.body[1]
  local nx = head.x + dx[snake.dir]
  local ny = head.y + dy[snake.dir]
  ```
- Insert `{x=nx, y=ny}` at index 1 of `snake.body` (new head).
- If `snake.grow > 0`: decrement `snake.grow` (tail stays, snake gets longer).
- Else: remove the last element of `snake.body` (tail moves forward).

#### `snake_check_collision()`

- **Wall collision**: If head `x < 1` or `x > grid_w` or `y < 1` or `y > grid_h`, set `snake.alive = false`.
- **Self collision**: Loop from index 2 to `#snake.body`. If any segment's `x,y` matches the head's `x,y`, set `snake.alive = false`.

### Acceptance criteria

- Snake starts as 3 segments at the center, moving right.
- Arrow key input changes direction, with 180-degree reversal prevented.
- Snake moves one grid cell per tick in the current direction.
- When `snake.grow > 0`, the snake lengthens by retaining its tail.
- Wall collision and self-collision both set `snake.alive = false`.

---

## Task 3 — Food & Scoring

**Tab**: 2 (`food`)
**Depends on**: Task 1 (constants), Task 2 (snake data structure)
**Goal**: Implement food spawning on the grid, eat detection, and score tracking.

### Data

```lua
food = {x = 0, y = 0}  -- grid coordinates
score = 0
```

### Functions to implement

#### `food_init()`

```lua
function food_init()
  score = 0
  food_spawn()
end
```

#### `food_spawn()`

- Generate a random grid position:
  ```lua
  food.x = flr(rnd(grid_w)) + 1
  food.y = flr(rnd(grid_h)) + 1
  ```
- **Collision check**: Ensure the food does not overlap any segment of `snake.body`. If it does, re-roll. Use a loop with a safety cap (e.g. 100 iterations) to avoid infinite loops if the snake fills the grid.
- Implementation:
  ```lua
  function food_spawn()
    local valid = false
    for attempt = 1, 100 do
      food.x = flr(rnd(grid_w)) + 1
      food.y = flr(rnd(grid_h)) + 1
      valid = true
      for seg in all(snake.body) do
        if seg.x == food.x and seg.y == food.y then
          valid = false
          break
        end
      end
      if valid then return end
    end
  end
  ```

#### `food_update()`

- Compare the snake head position with food position:
  ```lua
  function food_update()
    local head = snake.body[1]
    if head.x == food.x and head.y == food.y then
      score += 1
      snake.grow += 1
      sfx(0)
      food_spawn()
      -- speed increase: every 5 points, reduce tick interval (min 2)
      if score % 5 == 0 and speed > 2 then
        speed -= 1
      end
    end
  end
  ```

#### `food_draw()`

- Draw the food sprite at the food's pixel position:
  ```lua
  function food_draw()
    local px = ox + (food.x - 1) * grid_size
    local py = oy + (food.y - 1) * grid_size
    spr(2, px, py)
  end
  ```

### Acceptance criteria

- Food spawns at a random grid cell that does not overlap the snake.
- When the snake head enters the food cell: score increments, snake grows by 1, eat SFX plays, new food spawns.
- Every 5 points, `speed` decreases by 1 (minimum of 2), making the game progressively harder.
- Food is drawn using sprite 2 at the correct pixel position.

---

## Task 4 — Rendering

**Tab**: 3 (`render`)
**Depends on**: Tasks 1-3 (constants, snake data, food data)
**Goal**: Draw the playfield border, snake body, food, and score HUD during gameplay.

### Functions to implement

#### `draw_game()`

The main render function called during the `"playing"` state:

```lua
function draw_game()
  cls(0)
  -- draw border around playfield
  rect(ox - 1, oy - 1, ox + grid_w * grid_size, oy + grid_h * grid_size, 5)
  -- draw game objects
  food_draw()
  snake_draw()
  -- draw HUD
  print("score:"..score, 2, 2, 7)
end
```

#### `snake_draw()`

- Iterate over `snake.body` and draw each segment:
  ```lua
  function snake_draw()
    for i, seg in ipairs(snake.body) do
      local px = ox + (seg.x - 1) * grid_size
      local py = oy + (seg.y - 1) * grid_size
      if i == 1 then
        spr(0, px, py)  -- head sprite
      else
        spr(1, px, py)  -- body sprite
      end
    end
  end
  ```

### Rendering order

1. `cls(0)` — black background
2. Playfield border (`rect`)
3. Food (`food_draw`) — drawn before snake so snake overlaps food on eat frame
4. Snake (`snake_draw`)
5. HUD score text (`print`)

### Acceptance criteria

- Screen is cleared to black each frame.
- A dark-gray rectangle outlines the playfield.
- Snake head is drawn with sprite 0, body segments with sprite 1.
- Food is drawn with sprite 2.
- Score is displayed in white at the top-left corner.
- All sprites are positioned correctly on the pixel grid (no off-by-one errors).

---

## Task 5 — Sprite & Art Design

**Section**: `__gfx__`
**Depends on**: Nothing (can be done in parallel with code tasks)
**Goal**: Design 8x8 pixel art for the snake head, snake body, and food item.

### Sprite Definitions

#### Sprite 0 — Snake Head (color 11, green)

An 8x8 green block with two dark eye pixels. The head should be clearly distinguishable from the body.

Design (using PICO-8 color indices):
```
00bbbb00
0bbbbb b0
0bb00bb0    <- eyes (color 0 on green 'b'=11)
0bbbbb b0
0bbbbb b0
0bb00bb0
0bbbbb b0
00bbbb00
```

Where `b` = `b` (hex for color 11 = green), `0` = color 0 (black).

#### Sprite 1 — Snake Body (color 3, dark green)

An 8x8 darker green block with a subtle border to create visual segmentation.

Design:
```
00333300
03333330
03333330
33333333
33333333
03333330
03333330
00333300
```

#### Sprite 2 — Food / Apple (color 8, red + color 11 stem)

An 8x8 red circle-ish shape with a green stem pixel.

Design:
```
000b0000    <- stem (b = color 11)
00888800
08888880
88888888
88888888
08888880
08888880
00888800
```

### How to encode

- The `__gfx__` section contains 128 lines of 128 hex characters each.
- Each hex character is one pixel (0-F maps to PICO-8 colors 0-15).
- Sprite 0 occupies columns 0-7 of rows 0-7.
- Sprite 1 occupies columns 8-15 of rows 0-7.
- Sprite 2 occupies columns 16-23 of rows 0-7.
- All remaining columns should be `0`.
- Only include the rows that contain non-zero data (PICO-8 omits trailing empty rows).

### Implementation

Write exactly 8 lines. Each line has 128 hex digits. Columns 0-7 are sprite 0, columns 8-15 are sprite 1, columns 16-23 are sprite 2, columns 24-127 are all `0`.

### Acceptance criteria

- Three visually distinct 8x8 sprites are defined.
- Snake head (sprite 0) is bright green with visible eyes.
- Snake body (sprite 1) is darker green with a rounded/segmented look.
- Food (sprite 2) is red with a green stem pixel.
- The hex data is correctly formatted (128 chars per line, 8 lines minimum).

---

## Task 6 — Screens: Title & Game Over

**Tab**: 4 (`screens`)
**Depends on**: Task 1 (state machine), Task 2 (`snake_init`), Task 3 (`food_init`)
**Goal**: Implement the title screen and game over screen with input handling and visual presentation.

### Functions to implement

#### `update_title()`

```lua
function update_title()
  -- btnp(4) = O button (Z key), btnp(5) = X button (X key)
  if btnp(4) or btnp(5) then
    snake_init()
    food_init()
    speed = 6
    tick = 0
    state = "playing"
  end
end
```

#### `draw_title()`

```lua
function draw_title()
  cls(0)

  -- game title (large, centered)
  print("snake", 52, 40, 11)

  -- subtitle
  print("pico-8", 49, 50, 3)

  -- prompt (blinking effect using frame counter)
  if (time() % 1) > 0.5 then
    print("\x8e/\x97 to start", 32, 80, 6)
  end
end
```

- `\x8e` and `\x97` are PICO-8 special characters for the O and X button glyphs.
- The blinking prompt uses `time()` (returns seconds since boot) modulo to toggle visibility.

#### `update_gameover()`

```lua
function update_gameover()
  if btnp(4) or btnp(5) then
    state = "title"
  end
end
```

#### `draw_gameover()`

```lua
function draw_gameover()
  cls(0)

  print("game over", 40, 36, 8)

  print("score: "..score, 43, 50, 7)

  if (time() % 1) > 0.5 then
    print("\x8e/\x97 to retry", 32, 80, 6)
  end
end
```

### Acceptance criteria

- Title screen displays "snake" in green, "pico-8" subtitle, and a blinking start prompt.
- Pressing Z or X on the title screen starts a new game (reinitializes snake and food).
- Game over screen displays "game over" in red, the final score in white, and a blinking retry prompt.
- Pressing Z or X on the game over screen returns to the title screen.

---

## Task 7 — Sound Effects

**Section**: `__sfx__`
**Depends on**: Nothing (can be done in parallel with code tasks)
**Goal**: Create two chip-tune sound effects for eating food and dying.

### SFX Definitions

#### SFX 0 — Eat Food

A short, bright ascending blip that signals a positive event.

| Property  | Value                                           |
|-----------|-------------------------------------------------|
| Speed     | 2 (fast)                                        |
| Waveform  | Triangle (2) — soft, classic chip-tune feel      |
| Notes     | 4 ascending notes: C3, E3, G3, C4               |
| Volume    | 5                                                |
| Loop      | No loop (start=0, end=0)                         |

#### SFX 1 — Death

A descending buzz/noise that signals failure.

| Property  | Value                                           |
|-----------|-------------------------------------------------|
| Speed     | 4 (moderate)                                    |
| Waveform  | Noise (6) or Pulse (3) — harsher tone           |
| Notes     | 6 descending notes: C4, A3, F3, D3, B2, G2     |
| Volume    | 5, fading to 2                                   |
| Loop      | No loop (start=0, end=0)                         |

### SFX Line Format

Each SFX is one line of 168 hex characters:

```
[effect 2 digits][speed 2 digits][loop_start 2 digits][loop_end 2 digits][note0 5 digits][note1 5 digits]...[note31 5 digits]
```

Each note (5 hex digits):
- Digits 0-1: Note number (0x00-0x3F, where 0x18 = C3, 0x24 = C4)
- Digit 2: Waveform (0-6)
- Digit 3: Volume (0-7)
- Digit 4: Effect (0-7)

Unused notes should be `00000`.

### Acceptance criteria

- SFX 0 plays a short rising blip when food is eaten.
- SFX 1 plays a descending harsh tone on death.
- Both SFX are short (under 8 notes) so they don't overlap gameplay.
- The `__sfx__` section contains valid hex data with exactly 168 characters per line.

---

## Task 8 — Integration & Polish

**Depends on**: All previous tasks (1-7)
**Goal**: Assemble all tabs into the final `.p8` file, verify correctness, and add gameplay polish.

### Integration checklist

- [ ] All 5 tabs are present in `__lua__`, separated by `-->8` markers.
- [ ] Remove all stub functions from Tab 0 (real implementations now exist in their respective tabs).
- [ ] Verify the `__gfx__` section contains the sprite data from Task 5.
- [ ] Verify the `__sfx__` section contains the sound data from Task 7.
- [ ] Ensure `_init()` properly calls `snake_init()` and `food_init()`.
- [ ] Ensure `sfx(0)` is called on food eat and `sfx(1)` on death.

### Polish features to add

#### Speed increase

Already wired in `food_update()` (Task 3): every 5 points, decrement `speed` by 1 (floor of 2).

#### Screen shake on death

Add a small camera shake effect when the snake dies:

```lua
-- in update_gameover or draw_gameover:
shake = 5  -- set on death

-- in draw_gameover():
if shake > 0 then
  camera(rnd(shake) - shake/2, rnd(shake) - shake/2)
  shake -= 1
else
  camera(0, 0)
end
```

#### Frame counter for animations

Use a global `t` counter incremented in `_update()` for timing animations (blinking text, food pulse, etc.).

### Edge cases to verify

- Snake eating food when adjacent to the wall (food should respawn correctly).
- 180-degree turn prevention works at all speeds.
- Snake cannot eat itself on the frame it grows.
- Food never spawns on top of the snake body.
- Score persists correctly across the playing -> gameover transition.
- Restarting from title fully resets all game state.

### Final file structure verification

Ensure the `.p8` file sections appear in this exact order:
1. Header (2 lines)
2. `__lua__` (all 5 tabs with `-->8` separators)
3. `__gfx__` (sprite hex data)
4. `__gff__` (sprite flags, can be omitted if empty)
5. `__map__` (map data, can be omitted if empty)
6. `__sfx__` (sound effect hex data)
7. `__music__` (music patterns, can be omitted if empty)

### Acceptance criteria

- The complete `snake.p8` file loads and runs in PICO-8 without errors.
- Full game loop works: title -> play -> eat food (SFX, score, growth) -> die (SFX, shake) -> game over -> title -> replay.
- Speed increases as the player scores more points.
- All sprites render correctly at proper grid positions.
- No orphaned stub functions or dead code remain.

---

## Execution Order & Parallelism

```
Task 1 (scaffolding)
  |
  v
  +--> Task 2 (snake logic)   --+
  +--> Task 3 (food & scoring) -+
  +--> Task 4 (rendering)     --+--> Task 8 (integration & polish)
  +--> Task 5 (sprite art)    --+
  +--> Task 6 (screens)       --+
  +--> Task 7 (sound effects) --+
```

- **Task 1** must complete first (creates the file and defines constants).
- **Tasks 2-7** can all execute in parallel — they target different tabs/sections.
- **Task 8** runs last, assembling and polishing the final cartridge.
