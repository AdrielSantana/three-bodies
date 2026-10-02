# Three Bodies -- the physics: what the app's own integrator does with
# the figure-8, computed by the proof checker itself. The doubles are
# software (vendor/bend-collections), so every operation the app runs
# the checker runs too, bit for bit, and the law below holds of the
# very numbers the app shows.
#
# It takes the checker about three hours: 352 steps of the integrator,
# about 30 s each.
#
#   bend PHYSICS.bend --check-only
import Base
import ./main.bend as App
import ./vendor/bend-collections/f64.bend as D

# The figure-8 as the app starts it: scenario 1, seen from its centre
# of mass.
def Fig8.start() -> App.Sys:
  App.Sys.center(App.Scn.sys(0, 0))

# A third of its period: 6.32591398 / 3.
def Fig8.third() -> D.F64:
  D.of_bits(1073798781, 2560868867)

def Phys.apart(+a: D.F64, +b: D.F64) -> D.F64:
  D.abs(D.sub(a, b))

# How far two bodies are in position and velocity: the largest
# difference of a coordinate.
def Phys.gap(+p: App.Body, +q: App.Body) -> D.F64:
  App.Body{px, py, pu, pv, _} = p
  App.Body{qx, qy, qu, qv, _} = q
  App.Dbl.max(App.Dbl.max(Phys.apart(px, qx), Phys.apart(py, qy)), App.Dbl.max(Phys.apart(pu, qu), Phys.apart(pv, qv)))

# How far s is from s0 with each body moved on to the next one's place:
# a to where c began, b to where a began, c to where b began.
def Phys.passed(+s0: App.Sys, +s: App.Sys) -> D.F64:
  App.Sys{a0, b0, c0} = s0
  App.Sys{a, b, c} = s
  App.Dbl.max(Phys.gap(a, c0), App.Dbl.max(Phys.gap(b, a0), Phys.gap(c, b0)))

# The total momentum: its larger component.
def Phys.momentum(+s: App.Sys) -> D.F64:
  App.Sys{a, b, c} = s
  App.Body{_, _, au, av, am} = a
  App.Body{_, _, bu, bv, bm} = b
  App.Body{_, _, cu, cv, cm} = c
  App.Dbl.max(D.abs(D.add(D.add(D.mul(am, au), D.mul(bm, bu)), D.mul(cm, cu))),
    D.abs(D.add(D.add(D.mul(am, av), D.mul(bm, bv)), D.mul(cm, cv))))

# The four claims about a run, with their bounds: 1e-7, 1e-9, 1e-13.
def Fig8.claims(+r: App.Ran) -> Bool & Bool & Bool & Bool:
  App.Ran{s, left} = r
  +s0 = Fig8.start()
  +e0 = App.Sys.energy(s0)
  (D.le(left, App.Dbl.zero()), D.lt(Phys.passed(s0, s), D.of_bits(1048238066, 2596056904)),
    D.lt(Phys.apart(App.Sys.energy(s), e0), D.mul(D.of_bits(1041313291, 3894859413), D.abs(e0))), D.lt(Phys.momentum(s), D.of_bits(1027352002, 1749644930)))

# LAW: run from the app's figure-8 start for a third of its period, the
# app's integrator
# 1. gets through all of that time within its fuel;
# 2. leaves each body where the next one began, moving as it began,
#    within 1e-7: the three chase each other along one curve, the
#    figure-8's defining property, which only Newton's law gives;
# 3. keeps the energy within one part in 10^9;
# 4. keeps the total momentum, zero at the start, below 1e-13.
law figure8_third:
  {Fig8.claims(App.Sys.run(400n, False{}, Fig8.third(), Fig8.start())) == (True{}, True{}, True{}, True{})
    : Bool & Bool & Bool & Bool}

# The checker runs the 352 steps and reads the four answers.
def figure8_third():
  {==}
