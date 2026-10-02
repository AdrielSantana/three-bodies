# Three Bodies -- the laws: what the keys and a pause may do to the world.
import Base
import ./main.bend as App

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
