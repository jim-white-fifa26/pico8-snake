# Agent Notes

Guidelines for AI agents working on this PICO-8 Snake project.

## After Every Change

Run both commands after any modification to `snake.p8`:

```bash
# 1. Lint — must produce zero output (no warnings, no errors)
python3 .tools/shrinko8/shrinko8.py --lint snake.p8

# 2. Count — verify tokens, chars, and compressed size stay within limits
python3 .tools/shrinko8/shrinko8.py --count snake.p8
```

A clean lint run produces no output. Any output means there is a problem that must be fixed before committing.

## PICO-8 Limits

| Metric     | Hard Limit |
|------------|------------|
| Tokens     | 8,192      |
| Characters | 65,535     |
| Compressed | 15,616 B   |

Always check `--count` output to confirm changes haven't pushed the cart over budget.

## Tool Setup

Shrinko8 must be cloned into `.tools/` before use:

```bash
git clone --depth 1 https://github.com/thisismypassport/shrinko8.git .tools/shrinko8
```

Requires Python 3.8+.

## Code Organization

The cartridge `snake.p8` uses 5 Lua tabs separated by `-->8` markers:

| Tab | Name     | Contents                                    |
|-----|----------|---------------------------------------------|
| 0   | main     | Constants, state machine, `_init/_update/_draw` |
| 1   | snake    | Snake data, movement, input, collision      |
| 2   | food     | Food spawning, eat detection, scoring       |
| 3   | render   | Drawing playfield, snake, food, HUD         |
| 4   | screens  | Title screen, game over screen              |

Non-code sections: `__gfx__` (sprites), `__sfx__` (sound effects).

## Conventions

- Grid coordinates are 1-based.
- PICO-8 Lua uses `+=`, `-=`, `!=` shorthand syntax.
- Use `_` for unused loop variables to keep lint clean.
- Globals defined in earlier tabs are available in later tabs (PICO-8 evaluates sequentially).
