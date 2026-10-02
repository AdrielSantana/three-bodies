# Three Bodies

**English** | [Português](README.pt-BR.md)

The gravitational three-body problem, live, written in [Bend](https://bend-lang.com). The physics runs on the CPU; every pixel of every frame is computed on the GPU.

![The figure-8 of Moore, Chenciner and Montgomery](preview-figure8.png)

![Burrau's Pythagorean problem](preview-burrau.png)

## Running it

Install Bend (2.0.34 or newer) and build the native binary:

```bash
curl -fsSL https://bend-lang.com/install.sh | sh
bend main.bend -o tres && ./tres
```

The build produces `tres` and `tres.gpu`, which must stay in the same folder.

Requirements:

- clang 19 or newer
- macOS: Metal
- Linux: CUDA 12 at `/usr/local/cuda`, and `libx11-dev`

The GPU is used by default. To compare with the CPU:

```bash
./tres --gpu off       # run everything on the CPU, in parallel
./tres --threads 8     # pick the number of CPU threads
```

Tested on an Apple M5 with Bend 2.0.34: 60 FPS at 1280 × 720.

## Controls

| Key | Action |
| --- | --- |
| `1`–`9`, `0` | Pick a scenario |
| `N` / `B` or `→` / `←` | Next / previous |
| `R` | Restart the scenario |
| `Space` | Pause |
| `↑` / `↓` | Speed up / slow down (from 1/8× to 8×) |
| `G` | Toggle the field lines |
| `T` | Toggle the tour |
| `Esc` | Quit |

With the tour on, the next scenario comes in when a body is ejected or when the scenario's time is up.

## Scenarios

| # | Scenario |
| --- | --- |
| 1 | Figure-8 (Moore, Chenciner-Montgomery) |
| 2 | Butterfly I (Šuvakov-Dmitrašinović) |
| 3 | Moth I (Šuvakov-Dmitrašinović) |
| 4 | Yin-Yang I (Šuvakov-Dmitrašinović) |
| 5 | Yarn (Šuvakov-Dmitrašinović) |
| 6 | Lagrange's triangle: from order to chaos |
| 7 | Burrau's Pythagorean problem (masses 3, 4 and 5) |
| 8 | Star, planet and moon |
| 9 | A planet of two stars |
| 0 | Chaos: three random masses |

The first five are periodic solutions. Lagrange's triangle is unstable for equal masses: it holds for a few turns until the rounding of the last bit tears it apart. The last scenario draws three new bodies every time.

## How it works

### Physics

- Three point masses under Newton's law, with G = 1 and practically no softening (1e-6 of a length unit).
- Every number of the physics is an IEEE-754 double computed in software, by [Giulio2002/bend-collections](https://github.com/Giulio2002/bend-collections)' `f64.bend` (see [Credits](#credits)). Because these doubles are ordinary Bend code, the proof checker can compute them too, which is what makes `PHYSICS.bend` possible.
- The physics never divides or takes a square root: `1/√x` is four Newton steps from a first guess read off the bits.
- The 4th-order symplectic Forest-Ruth integrator, a composition of three leapfrogs.
- Adaptive step: 2% of the free-fall or fly-by time of the tightest pair, so a gravitational slingshot is resolved instead of skipped.
- The window title shows the drift of the total energy in parts per million.

### Picture

- The whole frame is a single `!` call, which Bend sends to the GPU: eight levels of four-way forks, from a 2048 px root down to 8 px tiles (160 × 90 = 14,400 tiles).
- Each pixel is a closed form of the three bodies: the glare of each one, the equipotential lines of their summed field (tinted by the body that dominates the region), a star field and the trails.
- The trails live in the picture itself: the top byte of each pixel, which the window never shows, holds who passed there and how long ago. The previous frame rides down the fork tree to be read, aged and dropped pixel by pixel.

## Laws and proofs

`LAWS.bend` states what the program must do, and `PROOF.bend` proves it. Bend's checker verifies each law for every possible input, not for a sample like a test does. The check takes about a minute:

```bash
bend PROOF.bend --check-only
```

### From the one-shot

| Law | What it guarantees |
| --- | --- |
| `esc_quits` | Esc quits, whatever the world and whatever follows. |
| `close_quits` | Closing the window quits. |
| `pause_freezes` | A paused frame does not move the bodies, whatever the clock says. |
| `space_twice` | Space twice changes nothing. |

### Added afterwards, by Claude Opus 5.5

| Law | What it guarantees |
| --- | --- |
| `step_keeps_mass` | An integration step never changes a mass, for any bodies and any step size. |
| `run_keeps_mass` | Neither does a whole run of the integrator, however many steps it takes (by induction). |
| `starts_at_rest` | Each of the nine fixed scenarios starts with its centre of mass at the origin and its momentum zero, to 1e-15. |
| `esc_anywhere` | Esc quits wherever it comes in a frame's events, whatever came before it. |
| `close_anywhere` | So does closing the window. |
| `digits_pick` | Keys 1–9 pick scenarios 1–9, and 0 picks the 10th, from any world. |
| `n_cycles` | From the first scenario, N visits the other nine in order and comes back. |
| `b_cycles` | B visits them backwards. |
| `restart_restores` | On any of the nine fixed scenarios, R puts the bodies back exactly where the scenario starts, whatever happened since. |
| `pause_keeps_run` | A paused frame keeps the scenario, the simulated time and the tour clock. |
| `pause_keeps_trails` | A frame drawn while paused fades no trail. |
| `load_wipes` | A new scenario wipes the old trails, exactly once. |
| `g_twice` | G twice changes nothing. |
| `t_twice` | T twice changes nothing. |

Each new law was also tested against injected bugs, such as letting the integrator touch a mass, making N skip a scenario or making R jump to the next one. Every bug made the check fail.

The physics was also moved afterwards, from `F32` to software doubles. Bend's checker treats `F32` arithmetic as opaque (it cannot prove even `1.5 + 2.25 == 3.75` in `F32`), so with `F32` nothing about the orbits could be proven.

### The physics: `PHYSICS.bend`

`PHYSICS.bend` proves a theorem about the app's own integrator, started where the app starts the figure-8 and run for a third of its period (352 steps). It claims four things:

1. The integrator gets through all of that time within its fuel.
2. Each body ends where the next one began, moving as it began, within 1e-7. The three bodies chase each other along a single curve: that is the figure-8's defining property, and only Newton's law produces it.
3. The total energy stays within one part in 10⁹ of its starting value.
4. The total momentum, zero at the start, stays below 1e-13.

There are no tactics or approximations in the proof: the checker runs all 352 steps itself, on the same software doubles the app uses, and reads off the four answers. That takes about three hours:

```bash
bend PHYSICS.bend --check-only
```

**Status:** checked. With Bend 2.0.34 on an Apple M5, `bend PHYSICS.bend --check-only` printed `ALL PROOFS CHECK` on October 2, 2026, after 2 h 58 min. That is Bend's regular checker; the recheck with its Lean-built kernel (`--verdict`) has not been run yet.

### What is not proven

- **Other starting conditions.** The theorem is about the figure-8 and this span of time. A law for all initial conditions ("for any bodies, the energy drifts by less than X") would need a formal analysis of rounding errors, which is still out of reach here.
- **The frames the app shows.** The app runs the same integrator, but in pieces of one frame each; the theorem runs it in one piece.
- **The picture and the operating system.** The picture computed on the GPU is still `F32` and has no proofs. The window and keyboard code that talks to the operating system is out of reach of Bend's proofs.

## Files

| File | Contents |
| --- | --- |
| `main.bend` | The simulation: physics, scenarios, pixels, keyboard and main loop |
| `LAWS.bend` | The laws: what the program must do |
| `PROOF.bend` | The proofs |
| `PHYSICS.bend` | The figure-8 theorem, with its proof |
| `vendor/bend-collections/` | The software doubles, from Giulio2002/bend-collections |

## Credits

The software doubles in `vendor/bend-collections/` are by [Giulio2002](https://github.com/Giulio2002), from [bend-collections](https://github.com/Giulio2002/bend-collections) (MIT). His IEEE-754 binary64 in pure Bend, proven correctly rounded, is what lets the proof checker compute the physics, and so what makes `PHYSICS.bend` possible.

## License

[MIT](LICENSE) © Adriel Santana
