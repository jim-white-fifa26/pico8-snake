# PICO-8 Snake Game

A classic Snake game built for the [PICO-8](https://www.lexaloffle.com/pico-8.php) fantasy console.

## How to Play

1. Load `snake.p8` in PICO-8
2. Press O (Z key) or X to start
3. Use arrow keys to control the snake
4. Eat food to grow and increase your score
5. Avoid hitting walls and yourself
6. Speed increases every 5 points

## Running

### With PICO-8 Desktop

```bash
pico8 -run snake.p8
```

### Without PICO-8 (Education Edition)

A self-contained version is provided in `snake_edu.p8` that generates sprites and sound effects programmatically at runtime -- no manual sprite/SFX editor work needed.

1. Open [pico-8-edu.com](https://www.pico-8-edu.com/)
2. Click the code editor tab (top-left icon)
3. Select all default code and delete it
4. Copy the entire Lua section from `snake_edu.p8` (everything between `__lua__` and the end of the file) and paste it in
5. Click the **Run** button (or press Ctrl+R)

Controls: arrow keys to move, Z or X to start/restart.

## Features

- 15x14 grid playfield with border
- Pixel-art sprites (snake head, body, apple)
- Score tracking with progressive speed increase
- Screen shake on death
- Sound effects for eating and dying
- Title screen and game over screen with blinking prompts

## Project Structure

```
pico8-snake/
├── README.md
├── PLAN.md          # Implementation plan
├── AGENTS.md        # AI agent notes
├── snake.p8         # Complete PICO-8 cartridge
├── snake_edu.p8     # Education Edition (self-contained, paste-and-run)
└── .tools/
    └── shrinko8/    # Linting & validation tool
```

## Cart Stats

| Metric     | Value | PICO-8 Limit | Usage |
|------------|------:|-------------:|------:|
| Tokens     |   797 |        8,192 |   10% |
| Characters | 4,370 |       65,535 |    7% |
| Compressed | 1,525 |       15,616 |   10% |

## Linting & Validation

This project uses [shrinko8](https://github.com/thisismypassport/shrinko8) for static analysis of the cartridge. Shrinko8 validates Lua syntax, checks for undefined/unused variables, and verifies the cart stays within PICO-8 token and size limits.

### Setup

```bash
# Clone shrinko8 into .tools/ (one-time setup)
git clone --depth 1 https://github.com/thisismypassport/shrinko8.git .tools/shrinko8
```

Requires Python 3.8+.

### Running

```bash
# Lint — checks for syntax errors, undefined globals, unused locals
python3 .tools/shrinko8/shrinko8.py --lint snake.p8

# Count — reports tokens, characters, and compressed size vs PICO-8 limits
python3 .tools/shrinko8/shrinko8.py --count snake.p8
```

A clean lint run produces no output. Any warnings or errors are printed to stdout.
