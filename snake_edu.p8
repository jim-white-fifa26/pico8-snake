pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- pico-8 snake (education edition)
-- paste this entire code into the
-- pico-8 education edition at:
--   https://www.pico-8-edu.com
--
-- sprites and sfx are created
-- programmatically so no manual
-- editor work is needed.

-----------------------------------
-- constants
-----------------------------------
grid_size = 8
grid_w = 15
grid_h = 14
ox = 4
oy = 10

-----------------------------------
-- game state
-----------------------------------
state = "title"
tick = 0
speed = 6
shake = 0

-----------------------------------
-- sprite builder
-- writes pixel art into the
-- sprite sheet using sset()
-----------------------------------
function build_sprites()
  -- helper: draw an 8x8 sprite
  -- from a string of hex colors
  -- at sprite index n
  local function draw_spr(n,s)
    local sx = (n % 16) * 8
    local sy = flr(n / 16) * 8
    for i = 1, 64 do
      local c = tonum("0x"..sub(s, i, i))
      sset(sx + (i - 1) % 8, sy + flr((i - 1) / 8), c)
    end
  end

  -- sprite 0: snake head (green b=11, eyes 0=black)
  draw_spr(0,
    "00bbbb00"..
    "0bbbbbb0"..
    "0bb00bb0"..
    "0bbbbbb0"..
    "0bbbbbb0"..
    "0bb00bb0"..
    "0bbbbbb0"..
    "00bbbb00"
  )

  -- sprite 1: snake body (dark green 3)
  draw_spr(1,
    "00333300"..
    "03333330"..
    "03333330"..
    "33333333"..
    "33333333"..
    "03333330"..
    "03333330"..
    "00333300"
  )

  -- sprite 2: food apple (red 8, stem b=11)
  draw_spr(2,
    "000b0000"..
    "00888800"..
    "08888880"..
    "88888888"..
    "88888888"..
    "08888880"..
    "08888880"..
    "00888800"
  )
end

-----------------------------------
-- sfx builder
-- writes sound data into sfx
-- memory using poke()
-----------------------------------
function build_sfx()
  -- sfx memory starts at 0x3200
  -- each sfx = 68 bytes
  -- byte 0: editor mode
  -- byte 1: speed
  -- byte 2: loop start
  -- byte 3: loop end
  -- bytes 4-67: 32 notes (2 bytes each)
  -- note low byte:  pitch (6 bits) + waveform low bit (1 bit) << 7 ... 
  -- actually, let's use the poke-based note format:
  --
  -- each note is 2 bytes (little-endian):
  --   low byte  = pitch[0:5] | waveform[0] << 6 | waveform[1] << 7
  --   high byte = waveform[2] | volume[0:2] << 1 | effect[0:2] << 4 | custom << 7
  --
  -- helper to poke a note
  local function poke_note(sfx_n, note_i, pitch, waveform, volume, effect)
    local addr = 0x3200 + sfx_n * 68 + 4 + note_i * 2
    local lo = pitch
    lo = lo | (waveform & 0x1) << 6
    lo = lo | (waveform & 0x2) << 6  -- bit 1 -> bit 7
    local hi = (waveform & 0x4) >> 2
    hi = hi | (volume & 0x7) << 1
    hi = hi | (effect & 0x7) << 4
    poke(addr, lo, hi)
  end

  -- sfx 0: eat food (speed 2, ascending triangle blip)
  poke(0x3200, 1)  -- editor mode
  poke(0x3201, 2)  -- speed
  poke(0x3202, 0)  -- loop start
  poke(0x3203, 0)  -- loop end
  -- c3=24, e3=28, g3=31, c4=36 (pico-8 note numbers)
  poke_note(0, 0, 24, 2, 5, 0)  -- c3 triangle vol5
  poke_note(0, 1, 28, 2, 5, 0)  -- e3 triangle vol5
  poke_note(0, 2, 31, 2, 5, 0)  -- g3 triangle vol5
  poke_note(0, 3, 36, 2, 5, 0)  -- c4 triangle vol5

  -- sfx 1: death (speed 4, descending pulse buzz)
  poke(0x3268, 1)  -- editor mode
  poke(0x3269, 4)  -- speed
  poke(0x326a, 0)  -- loop start
  poke(0x326b, 0)  -- loop end
  -- c4=36, a3=33, f3=29, d3=26, b2=23, g2=19
  poke_note(1, 0, 36, 3, 5, 0)  -- c4 pulse vol5
  poke_note(1, 1, 33, 3, 5, 0)  -- a3 pulse vol5
  poke_note(1, 2, 29, 3, 5, 0)  -- f3 pulse vol5
  poke_note(1, 3, 26, 3, 4, 0)  -- d3 pulse vol4
  poke_note(1, 4, 23, 3, 3, 0)  -- b2 pulse vol3
  poke_note(1, 5, 19, 3, 2, 0)  -- g2 pulse vol2
end

-----------------------------------
-- init
-----------------------------------
function _init()
  build_sprites()
  build_sfx()
  state = "title"
  tick = 0
  speed = 6
  snake_init()
  food_init()
end

-----------------------------------
-- update
-----------------------------------
function _update()
  if state == "title" then
    update_title()
  elseif state == "playing" then
    update_game()
  elseif state == "gameover" then
    update_gameover()
  end
end

-----------------------------------
-- draw
-----------------------------------
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
      shake = 5
      state = "gameover"
    end
  end
end

-----------------------------------
-- snake logic
-----------------------------------
dx = {[0]=-1, [1]=1, [2]=0, [3]=0}
dy = {[0]=0, [1]=0, [2]=-1, [3]=1}
opposite = {[0]=1,[1]=0,[2]=3,[3]=2}

snake = {}

function snake_init()
  snake.body = {{x=9,y=7},{x=8,y=7},{x=7,y=7}}
  snake.dir = 1
  snake.next_dir = 1
  snake.alive = true
  snake.grow = 0
end

function snake_input()
  local new_dir = snake.dir
  if btn(0) then new_dir = 0
  elseif btn(1) then new_dir = 1
  elseif btn(2) then new_dir = 2
  elseif btn(3) then new_dir = 3
  end
  if new_dir ~= opposite[snake.dir] then
    snake.next_dir = new_dir
  end
end

function snake_move()
  snake.dir = snake.next_dir
  local head = snake.body[1]
  local nx = head.x + dx[snake.dir]
  local ny = head.y + dy[snake.dir]
  add(snake.body, {x=nx, y=ny}, 1)
  if snake.grow > 0 then
    snake.grow -= 1
  else
    deli(snake.body, #snake.body)
  end
end

function snake_check_collision()
  local head = snake.body[1]
  if head.x < 1 or head.x > grid_w or head.y < 1 or head.y > grid_h then
    snake.alive = false
    return
  end
  for i = 2, #snake.body do
    if snake.body[i].x == head.x and snake.body[i].y == head.y then
      snake.alive = false
      return
    end
  end
end

-----------------------------------
-- food & scoring
-----------------------------------
food = {x = 0, y = 0}
score = 0

function food_init()
  score = 0
  food_spawn()
end

function food_spawn()
  local valid = false
  for _ = 1, 100 do
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

function food_update()
  local head = snake.body[1]
  if head.x == food.x and head.y == food.y then
    score += 1
    snake.grow += 1
    sfx(0)
    food_spawn()
    if score % 5 == 0 and speed > 2 then
      speed -= 1
    end
  end
end

function food_draw()
  local px = ox + (food.x - 1) * grid_size
  local py = oy + (food.y - 1) * grid_size
  spr(2, px, py)
end

-----------------------------------
-- rendering
-----------------------------------
function draw_game()
  cls(0)
  rect(ox - 1, oy - 1, ox + grid_w * grid_size, oy + grid_h * grid_size, 5)
  food_draw()
  snake_draw()
  print("score:"..score, 2, 2, 7)
end

function snake_draw()
  for i, seg in ipairs(snake.body) do
    local px = ox + (seg.x - 1) * grid_size
    local py = oy + (seg.y - 1) * grid_size
    if i == 1 then
      spr(0, px, py)
    else
      spr(1, px, py)
    end
  end
end

-----------------------------------
-- screens
-----------------------------------
function update_title()
  if btnp(4) or btnp(5) then
    snake_init()
    food_init()
    speed = 6
    tick = 0
    state = "playing"
  end
end

function draw_title()
  cls(0)
  print("snake", 52, 40, 11)
  print("pico-8", 49, 50, 3)
  if (time() % 1) > 0.5 then
    print("\x8e/\x97 to start", 32, 80, 6)
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    state = "title"
  end
end

function draw_gameover()
  if shake > 0 then
    camera(rnd(shake) - shake/2, rnd(shake) - shake/2)
    shake -= 1
  else
    camera(0, 0)
  end
  cls(0)
  print("game over", 40, 36, 8)
  print("score: "..score, 43, 50, 7)
  if (time() % 1) > 0.5 then
    print("\x8e/\x97 to retry", 32, 80, 6)
  end
end
