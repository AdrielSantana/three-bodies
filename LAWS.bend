# Three Bodies -- the laws: what the keys and a pause may do to the world.
import Base
import ./main.bend as App
import ./vendor/bend-collections/f64.bend as D

# LAW: an Esc key-down quits, whatever follows it and whatever the world.
law esc_quits:
  for rest: List<Event>
  for w: App.World
  {App.World.events(Key{27, True{}} <> rest, w) == None{} : Maybe<App.World>}

# LAW: closing the window quits, whatever follows it and whatever the world.
law close_quits:
  for rest: List<Event>
  for w: App.World
  {App.World.events(Close{} <> rest, w) == None{} : Maybe<App.World>}

# LAW: a paused world does not move: whatever the clock says, a frame
# leaves the three bodies exactly where they were.
law pause_freezes:
  for +ms: U32
  for +now: Nat
  for +w: App.World
  {App.World.bodies(App.World.turn(True{}, ms, now, w)) == App.World.bodies(w) : App.Sys}

# LAW: Space twice changes nothing.
law space_twice:
  for +w: App.World
  {App.World.key(32, App.World.key(32, w)) == w : App.World}

# Added after the one-shot, by Claude Opus 5.5
# --------------------------------------------
# What the program does with its numbers: which ones it keeps, which
# keys do what, when the clock stops and when the trails go. What the
# numbers themselves do (the orbits, the energy) is in PHYSICS.bend.

# The three masses of a system.
def Mass.of(s: App.Sys) -> D.F64 & D.F64 & D.F64:
  App.Sys{a, b, c} = s
  App.Body{_, _, _, _, ma} = a
  App.Body{_, _, _, _, mb} = b
  App.Body{_, _, _, _, mc} = c
  (ma, mb, mc)

def Mass.ran(r: App.Ran) -> D.F64 & D.F64 & D.F64:
  App.Ran{s, _} = r
  Mass.of(s)

# The scenario a world is on (0 is the key 1, 9 is the key 0).
def Scn.of(w: App.World) -> U32:
  App.World{_, _, run, _, _} = w
  App.Run{id, _, _, _, _, _} = run
  id

def Run.of(w: App.World) -> App.Run:
  App.World{_, _, run, _, _} = w
  run

def Wipe.of(w: App.World) -> Bool:
  App.World{_, _, run, _, _} = w
  App.Run{_, _, _, _, _, wipe} = run
  wipe

# How many trail levels a frame fades, as the GPU is told.
def Fade.uni(u: App.Uni) -> U32:
  App.Uni{_, _, _, _, _, fade, _} = u
  fade

def Fade.of(w: App.World) -> U32:
  Fade.uni(App.World.view(w))

# The scenario after each of k presses of a key.
def Keys.press(+code: U32, k: Nat, w: App.World) -> List<U32>:
  match k:
    case 0n:
      []
    case 1n+j:
      +w2 = App.World.key(code, w)
      Scn.of(w2) <> Keys.press(code, j, w2)

# The scenario each digit key picks, from 1 to 9 and then 0.
def Keys.digits(+w: App.World) -> List<U32>:
  [Scn.of(App.World.key(49, w)), Scn.of(App.World.key(50, w)), Scn.of(App.World.key(51, w)),
    Scn.of(App.World.key(52, w)), Scn.of(App.World.key(53, w)), Scn.of(App.World.key(54, w)),
    Scn.of(App.World.key(55, w)), Scn.of(App.World.key(56, w)), Scn.of(App.World.key(57, w)),
    Scn.of(App.World.key(48, w))]

# The larger of |a| and |b|.
def Rest.big(+a: D.F64, +b: D.F64) -> D.F64:
  App.Dbl.max(D.abs(a), D.abs(b))

# sum m q, for q one coordinate of the three.
def Rest.sum(+am: D.F64, +bm: D.F64, +cm: D.F64, aq: D.F64, bq: D.F64, cq: D.F64) -> D.F64:
  D.add(D.add(D.mul(am, aq), D.mul(bm, bq)), D.mul(cm, cq))

# Is s at rest at the origin: are sum m x, sum m y (its centre of mass)
# and sum m u, sum m v (its momentum) all below 1e-15?
def Rest.at(+s: App.Sys) -> Bool:
  App.Sys{a, b, c} = s
  App.Body{ax, ay, au, av, am} = a
  App.Body{bx, by, bu, bv, bm} = b
  App.Body{cx, cy, cu, cv, cm} = c
  D.lt(App.Dbl.max(Rest.big(Rest.sum(am, bm, cm, ax, bx, cx), Rest.sum(am, bm, cm, ay, by, cy)),
    Rest.big(Rest.sum(am, bm, cm, au, bu, cu), Rest.sum(am, bm, cm, av, bv, cv))), D.of_bits(1020396463, 2665960982))

# How each of the nine fixed scenarios starts, as the app loads it.
def Rest.starts() -> List<Bool>:
  [Rest.at(App.Sys.center(App.Scn.sys(0, 0))), Rest.at(App.Sys.center(App.Scn.sys(1, 0))),
    Rest.at(App.Sys.center(App.Scn.sys(2, 0))), Rest.at(App.Sys.center(App.Scn.sys(3, 0))),
    Rest.at(App.Sys.center(App.Scn.sys(4, 0))), Rest.at(App.Sys.center(App.Scn.sys(5, 0))),
    Rest.at(App.Sys.center(App.Scn.sys(6, 0))), Rest.at(App.Sys.center(App.Scn.sys(7, 0))),
    Rest.at(App.Sys.center(App.Scn.sys(8, 0)))]

# LAW: a step of the integrator never changes a mass, whatever the
# bodies and whatever the step.
law step_keeps_mass:
  for +s: App.Sys
  for +h: D.F64
  {Mass.of(App.Sys.step(s, h)) == Mass.of(s) : D.F64 & D.F64 & D.F64}

# LAW: nor does a whole run of it, however many steps it takes.
law run_keeps_mass:
  for fuel: Nat
  for done: Bool
  for +left: D.F64
  for +s: App.Sys
  {Mass.ran(App.Sys.run(fuel, done, left, s)) == Mass.of(s) : D.F64 & D.F64 & D.F64}

# LAW: an Esc key-down quits wherever it comes in a frame's events,
# whatever came before it.
law esc_anywhere:
  for before: List<Event>
  for rest: List<Event>
  for w: App.World
  {App.World.events(List.append(&1, Event, before, Key{27, True{}} <> rest), w) == None{} : Maybe<App.World>}

# LAW: so does closing the window.
law close_anywhere:
  for before: List<Event>
  for rest: List<Event>
  for w: App.World
  {App.World.events(List.append(&1, Event, before, Close{} <> rest), w) == None{} : Maybe<App.World>}

# LAW: the keys 1 to 9 pick scenarios 1 to 9, and 0 picks the 10th,
# whatever the world.
law digits_pick:
  for +w: App.World
  {Keys.digits(w) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] : List<U32>}

# LAW: from the first scenario, N visits the other nine in order and
# comes back to the first.
law n_cycles:
  for w: App.World
  {Keys.press(110, 10n, App.World.key(49, w)) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0] : List<U32>}

# LAW: and B visits them backwards.
law b_cycles:
  for w: App.World
  {Keys.press(98, 10n, App.World.key(49, w)) == [9, 8, 7, 6, 5, 4, 3, 2, 1, 0] : List<U32>}

# LAW: on any of the nine fixed scenarios (all but the random one), R
# puts the bodies back exactly where the scenario starts, whatever
# happened since.
law restart_restores:
  for d: Nat
  for lt: {Nat.is_lt(d, 9n) == True{} : Bool}
  for w: App.World
  for on: {U32.from_nat(d) == Scn.of(w) : U32}
  {App.World.bodies(App.World.key(114, w)) == App.Sys.center(App.Scn.sys(U32.from_nat(d), 0)) : App.Sys}

# LAW: a paused frame leaves the run alone: the scenario, the time
# simulated and the tour's clock all stand still.
law pause_keeps_run:
  for +ms: U32
  for +now: Nat
  for +w: App.World
  {Run.of(App.World.turn(True{}, ms, now, w)) == Run.of(w) : App.Run}

# LAW: and the frame drawn while paused fades no trail.
law pause_keeps_trails:
  for +ms: U32
  for +now: Nat
  for +w: App.World
  {Fade.of(App.World.turn(True{}, ms, now, w)) == 0 : U32}

# LAW: a new scenario wipes the old trails, and only once: the frame
# that shows it clears the order.
law load_wipes:
  for +k: U32
  for +w: App.World
  {(Wipe.of(App.World.load(k, w)), Wipe.of(App.World.seen(App.World.load(k, w)))) == (True{}, False{}) : Bool & Bool}

# LAW: G twice changes nothing.
law g_twice:
  for +w: App.World
  {App.World.key(103, App.World.key(103, w)) == w : App.World}

# LAW: T twice changes nothing.
law t_twice:
  for +w: App.World
  {App.World.key(116, App.World.key(116, w)) == w : App.World}

# LAW: each of the nine fixed scenarios starts with its centre of mass
# at the origin and its momentum zero, to 1e-15: the camera never has
# to move.
law starts_at_rest:
  {Rest.starts() == [True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}] : List<Bool>}
