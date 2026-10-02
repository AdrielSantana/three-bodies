# Three Bodies -- the proofs. The two quits hold by computation; the
# pause opens the world and its clocks, then computes; Space twice
# opens the world down to the pause flag and computes each case.
import Base
import ./main.bend as App
import ./LAWS.bend as Laws

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
