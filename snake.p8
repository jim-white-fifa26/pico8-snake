pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tab 0: main (game loop & state machine)

-- constants
grid_size = 8
grid_w = 15
grid_h = 14
ox = 4
oy = 10

-- game state
state = "title"
tick = 0
speed = 6  -- snake moves every n frames
shake = 0

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
      shake = 5
      state = "gameover"
    end
  end
end


-->8
-- tab 1: snake logic

-- direction deltas
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
  -- wall collision
  if head.x < 1 or head.x > grid_w or head.y < 1 or head.y > grid_h then
    snake.alive = false
    return
  end
  -- self collision
  for i = 2, #snake.body do
    if snake.body[i].x == head.x and snake.body[i].y == head.y then
      snake.alive = false
      return
    end
  end
end
-->8
-- tab 2: food & scoring

food = {x = 0, y = 0}
score = 0

function food_init()
  score = 0
  food_spawn()
end

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

function food_draw()
  local px = ox + (food.x - 1) * grid_size
  local py = oy + (food.y - 1) * grid_size
  spr(2, px, py)
end
-->8
-- tab 3: rendering

function draw_game()
  cls(0)
  -- draw border around playfield
  rect(ox - 1, oy - 1, ox + grid_w * grid_size, oy + grid_h * grid_size, 5)
  -- draw game objects
  food_draw()
  snake_draw()
  -- draw hud
  print("score:"..score, 2, 2, 7)
end

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
-->8
-- tab 4: screens (title & game over)

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
  -- game title
  print("snake", 52, 40, 11)
  -- subtitle
  print("pico-8", 49, 50, 3)
  -- blinking prompt
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
__gfx__
00bbbb0000333300000b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbb0033333300088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb00bb0033333300888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbb0333333338888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbb0333333338888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb00bb0033333300888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbbbb0033333300888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbbb00003333000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
__map__
__sfx__
01020000182501c2501f2502425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104000024350213501d3501a34017330133200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
