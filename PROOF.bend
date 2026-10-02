# Three Bodies -- the proofs. The two quits hold by computation; the
# pause opens the world and its clocks, then computes; Space twice
# opens the world down to the pause flag and computes each case.
import Base
import ./main.bend as App
import ./LAWS.bend as Laws
import ./vendor/bend-collections/f64.bend as D

def Laws.esc_quits(rest, w):
  {==}

def Laws.close_quits(rest, w):
  {==}

def Laws.pause_freezes(ms, now, w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match clk:
        case App.Clk{stamp, clock, fade, begin, frames}:
          {==}

def Laws.space_twice(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match opt:
        case App.Opt{paused, lines, tour, speed}:
          match paused:
            case True{}:
              {==}
            case False{}:
              {==}

# Added after the one-shot, by Claude Opus 5.5
# --------------------------------------------

# The masses: open the three bodies, and the step hands each mass back
# untouched, so the two sides compute to the same triple.
def Laws.step_keeps_mass(s, h):
  match s:
    case App.Sys{a, b, c}:
      match a:
        case App.Body{ax, ay, au, av, am}:
          match b:
            case App.Body{bx, by, bu, bv, bm}:
              match c:
                case App.Body{cx, cy, cu, cv, cm}:
                  {==}

# A run, by induction on its fuel: the rest of the run keeps the masses
# of the stepped system, which are the masses of the system.
def Laws.run_keeps_mass(fuel, done, left, s):
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      match done:
        case True{}:
          {==}
        case False{}:
          +h = App.Dbl.min(left, D.mul(D.of_bits(1066695393, 1202590843), App.Sys.pace(s)))
          +rest = D.sub(left, h)
          %Laws.step_keeps_mass(s, h) : {Laws.Mass.ran(App.Sys.run(f, D.le(rest, App.Dbl.zero()), rest, App.Sys.step(s, h)))
            == _ : D.F64 & D.F64 & D.F64}
          Laws.run_keeps_mass(f, D.le(rest, App.Dbl.zero()), rest, App.Sys.step(s, h))

# The quits, in general: whatever the frame's events have made of the
# world so far (or if they have already ended it), the events from there
# on end it. By induction on the events before the quit.
law Esc.ends:
  for before: List<Event>
  for rest: List<Event>
  for m: Maybe<App.World>
  {Maybe.bind(&1, App.World, App.World, m,
    w => App.World.events(List.append(&1, Event, before, Key{27, True{}} <> rest), w)) == None{} : Maybe<App.World>}

def Esc.ends(before, rest, m):
  match before:
    case []:
      match m:
        case None{}:
          {==}
        case Some{w}:
          {==}
    case e <> more:
      match m:
        case None{}:
          {==}
        case Some{w}:
          Esc.ends(more, rest, App.World.event(e, w))

law Close.ends:
  for before: List<Event>
  for rest: List<Event>
  for m: Maybe<App.World>
  {Maybe.bind(&1, App.World, App.World, m,
    w => App.World.events(List.append(&1, Event, before, Close{} <> rest), w)) == None{} : Maybe<App.World>}

def Close.ends(before, rest, m):
  match before:
    case []:
      match m:
        case None{}:
          {==}
        case Some{w}:
          {==}
    case e <> more:
      match m:
        case None{}:
          {==}
        case Some{w}:
          Close.ends(more, rest, App.World.event(e, w))

def Laws.esc_anywhere(before, rest, w):
  Esc.ends(before, rest, Some{w})

def Laws.close_anywhere(before, rest, w):
  Close.ends(before, rest, Some{w})

# The keys that pick a scenario: open the world down to its run, and
# every press computes.
def Laws.digits_pick(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match run:
        case App.Run{id, seed, t, e0, age, wipe}:
          {==}

def Laws.n_cycles(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match run:
        case App.Run{id, seed, t, e0, age, wipe}:
          {==}

def Laws.b_cycles(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match run:
        case App.Run{id, seed, t, e0, age, wipe}:
          {==}

# Restart. First, for any scenario k the world is on, R reloads k: open
# the world and rewrite its scenario into k.
def Seed.of(w: App.World) -> U32:
  App.World{_, _, run, _, _} = w
  App.Run{_, seed, _, _, _, _} = run
  seed

law Restart.reloads:
  for +k: U32
  for w: App.World
  for on: {k == Laws.Scn.of(w) : U32}
  {App.World.bodies(App.World.key(114, w))
    == App.Sys.center(App.Scn.sys(((k + 0) % App.Scn.count() : U32), App.Scn.rand((Seed.of(w) + 2654435761 : U32))))
    : App.Sys}

def Restart.reloads(k, w, on):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match run:
        case App.Run{id, seed, t, e0, age, wipe}:
          %on : {App.Sys.center(App.Scn.sys(((_ + 0) % App.Scn.count() : U32), App.Scn.rand((seed + 2654435761 : U32))))
            == App.Sys.center(App.Scn.sys(((k + 0) % App.Scn.count() : U32), App.Scn.rand((seed + 2654435761 : U32))))
            : App.Sys}
          {==}

# False is not True.
def Clash.disc(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

law Clash.bool:
  for e: {False{} == True{} : Bool}
  Empty

def Clash.bool(e):
  %e : Clash.disc(_)
  Unit{}

# Then, scenario by scenario: each fixed one ignores the seed, so its
# reload is its start; past the ninth, d < 9 is False == True.
def Laws.restart_restores(d, lt, w, on):
  match d:
    case 0n:
      Restart.reloads(0, w, on)
    case 1n:
      Restart.reloads(1, w, on)
    case 2n:
      Restart.reloads(2, w, on)
    case 3n:
      Restart.reloads(3, w, on)
    case 4n:
      Restart.reloads(4, w, on)
    case 5n:
      Restart.reloads(5, w, on)
    case 6n:
      Restart.reloads(6, w, on)
    case 7n:
      Restart.reloads(7, w, on)
    case 8n:
      Restart.reloads(8, w, on)
    case 9n+p:
      match p:
        case 0n:
          Empty.absurd({App.World.bodies(App.World.key(114, w)) == App.Sys.center(App.Scn.sys(U32.from_nat(9n), 0)) : App.Sys}, Clash.bool(lt))
        case 1n+q:
          Empty.absurd({App.World.bodies(App.World.key(114, w)) == App.Sys.center(App.Scn.sys(U32.from_nat(10n+q), 0)) : App.Sys}, Clash.bool(lt))

# The pause: open the world and its clocks, and compute.
def Laws.pause_keeps_run(ms, now, w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match clk:
        case App.Clk{stamp, clock, fade, begin, frames}:
          {==}

# The trails: the frame's uniforms read the whole world, so open it all.
def Laws.pause_keeps_trails(ms, now, w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match sys:
        case App.Sys{a, b, c}:
          match a:
            case App.Body{ax, ay, au, av, am}:
              match b:
                case App.Body{bx, by, bu, bv, bm}:
                  match c:
                    case App.Body{cx, cy, cu, cv, cm}:
                      match run:
                        case App.Run{id, seed, t, e0, age, wipe}:
                          match opt:
                            case App.Opt{paused, lines, tour, speed}:
                              match clk:
                                case App.Clk{stamp, clock, fade, begin, frames}:
                                  {==}

# A load writes the order; seen clears it.
def Laws.load_wipes(k, w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match run:
        case App.Run{id, seed, t, e0, age, wipe}:
          {==}

# G and T as Space: open the world down to the flag and compute each case.
def Laws.g_twice(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match opt:
        case App.Opt{paused, lines, tour, speed}:
          match lines:
            case True{}:
              {==}
            case False{}:
              {==}

def Laws.t_twice(w):
  match w:
    case App.World{sys, was, run, opt, clk}:
      match opt:
        case App.Opt{paused, lines, tour, speed}:
          match tour:
            case True{}:
              {==}
            case False{}:
              {==}

# Where the scenarios start: the checker computes all nine.
def Laws.starts_at_rest():
  {==}
