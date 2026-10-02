# Three Bodies: the gravitational three-body problem, live. Three point
# masses under Newton's law, G = 1, with no softening to speak of
# (1e-6 of a length unit, so a collision is a number and not a NaN).
#
# The physics runs on the host, in IEEE-754 binary64 done in software
# (D: bend-collections' f64.bend, correctly rounded), so the proof
# checker computes the very numbers the app does, and PHYSICS.bend can
# prove what they do. It never divides or takes a root: 1/sqrt is
# Newton's method from a first guess read off the bits. The integrator
# is the 4th-order symplectic Forest-Ruth composition of three
# leapfrogs, and the step follows the tightest pair (2% of its free-fall
# or fly-by time), so a slingshot at 0.0004 of the frame is resolved,
# not skipped. The title shows the drift of the total energy in parts
# per million.
#
# The picture is one bang: eight levels of four-way forks from the
# 2048 root to 8-px tiles (160 x 90 = 14400 of the device's 16384
# lanes), each tile sixty-four pixels of straight-line code. A pixel is
# a closed form of the three bodies: their glare, the equipotential
# lines of their summed field (each line tinted by the body that owns
# that region), a star field, and the trails. The trails live in the
# picture itself: the top byte of a pixel's word (which the window
# never shows) holds who passed and how long ago, and the last frame
# rides down the fork tree to be read, aged and dropped pixel by pixel.
#
# Keys: 1-9 and 0 pick a scenario, N and B (or the arrows) step through
# them, R restarts, Space pauses, Up/Down change the speed, G toggles
# the field lines, T the tour (on: the next scenario comes when a body
# is flung away or the time is up), Esc quits.
#
#   bend main.bend -o tres && ./tres
import Base
import ./vendor/bend-collections/f64.bend as D

# Numbers
# -------
# pick and word beside Bool.pick: the typed ones keep their words in
# registers.

def pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def min(+a: F32, +b: F32) -> F32:
  pick((a < b : F32), a, b)

def max(+a: F32, +b: F32) -> F32:
  pick((a < b : F32), b, a)

def sat(+x: F32) -> F32:
  min(1.0, max(0.0, x))

# Doubles
# -------
# The physics' numbers. A constant is written by its bits, the decimal
# beside it.

def Dbl.pick(c: Bool, a: D.F64, b: D.F64) -> D.F64:
  match c:
    case True{}:
      a
    case False{}:
      b

def Dbl.min(+a: D.F64, +b: D.F64) -> D.F64:
  Dbl.pick(D.lt(a, b), a, b)

def Dbl.max(+a: D.F64, +b: D.F64) -> D.F64:
  Dbl.pick(D.lt(a, b), b, a)

def Dbl.zero() -> D.F64:
  D.zero(False{})

# 0.5
def Dbl.half() -> D.F64:
  D.of_bits(1071644672, 0)

# 1e-12, the softening of a squared distance.
def Dbl.soft() -> D.F64:
  D.of_bits(1030854553, 2167269905)

# 1/sqrt(x), for x > 0. The first guess halves the exponent through the
# bits (0x5FE6EB50C7B537A9 minus half the word, within 3.5%); four
# Newton steps, y <- y (3/2 - x/2 y^2), each square the error, to the
# last bits of a double.
def Rsq.bit(b: Bool) -> U32:
  match b:
    case True{}:
      1
    case False{}:
      0

def Rsq.guess(+x: D.F64) -> D.F64:
  +hi = D.word_hi(x)
  +lo = D.word_lo(x)
  +slo = (lo >> 1n .|. (hi .&. 1) << 31n : U32)
  +shi = (hi >> 1n : U32)
  D.of_bits((1608969040 - shi - Rsq.bit((3350542249 < slo : U32)) : U32), (3350542249 - slo : U32))

# 1.5
def Rsq.newton(+h: D.F64, +y: D.F64) -> D.F64:
  D.mul(y, D.sub(D.of_bits(1073217536, 0), D.mul(h, D.mul(y, y))))

def Rsq.of(+x: D.F64) -> D.F64:
  +h = D.mul(Dbl.half(), x)
  Rsq.newton(h, Rsq.newton(h, Rsq.newton(h, Rsq.newton(h, Rsq.guess(x)))))

# 1/x, for x > 0.
def Dbl.inv(+x: D.F64) -> D.F64:
  +q = Rsq.of(x)
  D.mul(q, q)

# A float as a double, exactly (zero for a subnormal).
def Dbl.exp32(+e: U32) -> U32:
  word(U32.is_eq(e, 0), 0, word(U32.is_eq(e, 255), 2047, (e + 896 : U32)))

def Dbl.of_f32(x: F32) -> D.F64:
  +b = F32.bits(x)
  +e = (b >> 23n .&. 255 : U32)
  +m = (b .&. 8388607 : U32)
  +z = U32.is_eq(e, 0)
  D.of_bits((b >> 31n << 31n .|. Dbl.exp32(e) << 20n .|. word(z, 0, (m >> 3n : U32)) : U32),
    word(z, 0, (m .&. 7 << 29n : U32)))

# A double as a float, its 24 top bits (for the picture and the title).
def Dbl.to_f32(+x: D.F64) -> F32:
  +hi = D.word_hi(x)
  +e = (hi >> 20n .&. 2047 : U32)
  +m = U32.to_f32((8388608 .|. (hi .&. 1048575) << 3n .|. D.word_lo(x) >> 29n : U32))
  +v = (m * F32.pow(2.0, (U32.to_f32(e) - 1046.0 : F32)) : F32)
  pick(U32.is_eq(e, 0), 0.0, pick(((hi >> 31n) > 0 : U32), (0.0 - v : F32), v))

# Bodies
# ------
# A Body is its position (x, y), its velocity (u, v) and its mass; a Sys
# is the three of them.

type Vec is Data:
  Vec{x: D.F64, y: D.F64}

type Body is Data:
  Body{x: D.F64, y: D.F64, u: D.F64, v: D.F64, m: D.F64}

type Sys is Data:
  Sys{a: Body, b: Body, c: Body}

# What a run leaves: the system and the time it did not get to.
type Ran is Data:
  Ran{sys: Sys, left: D.F64}

def Body.drift(+p: Body, +h: D.F64) -> Body:
  Body{x, y, u, v, m} = p
  Body{D.add(x, D.mul(u, h)), D.add(y, D.mul(v, h)), u, v, m}

def Body.kick(+p: Body, ax: D.F64, ay: D.F64, +h: D.F64) -> Body:
  Body{x, y, u, v, m} = p
  Body{x, y, D.add(u, D.mul(ax, h)), D.add(v, D.mul(ay, h)), m}

# dx^2 + dy^2, softened.
def Body.r2(+dx: D.F64, +dy: D.F64) -> D.F64:
  D.add(D.add(D.mul(dx, dx), D.mul(dy, dy)), Dbl.soft())

# q's pull on p per unit of q's mass: (q - p) / |q - p|^3.
def Body.pull(+p: Body, +q: Body) -> Vec:
  Body{px, py, _, _, _} = p
  Body{qx, qy, _, _, _} = q
  +dx = D.sub(qx, px)
  +dy = D.sub(qy, py)
  +i = Rsq.of(Body.r2(dx, dy))
  +k = D.mul(i, D.mul(i, i))
  Vec{D.mul(dx, k), D.mul(dy, k)}

# One over the square of a pair's time scale: (mp + mq)/r^3 + w^2/r^2,
# its free fall and its fly-by.
def Body.pace(+p: Body, +q: Body) -> D.F64:
  Body{px, py, pu, pv, pm} = p
  Body{qx, qy, qu, qv, qm} = q
  +dx = D.sub(qx, px)
  +dy = D.sub(qy, py)
  +wx = D.sub(qu, pu)
  +wy = D.sub(qv, pv)
  +i = Rsq.of(Body.r2(dx, dy))
  +i2 = D.mul(i, i)
  D.add(D.mul(D.add(pm, qm), D.mul(i, i2)), D.mul(D.add(D.mul(wx, wx), D.mul(wy, wy)), i2))

# A pair's binding energy, positive.
def Body.bind(+p: Body, +q: Body) -> D.F64:
  Body{px, py, _, _, pm} = p
  Body{qx, qy, _, _, qm} = q
  D.mul(D.mul(pm, qm), Rsq.of(Body.r2(D.sub(qx, px), D.sub(qy, py))))

def Body.move(+p: Body) -> D.F64:
  Body{_, _, u, v, m} = p
  D.mul(D.mul(Dbl.half(), m), D.add(D.mul(u, u), D.mul(v, v)))

# Kinetic minus binding: the constant of the motion the title watches.
def Sys.energy(+s: Sys) -> D.F64:
  Sys{a, b, c} = s
  D.sub(D.sub(D.sub(D.add(D.add(Body.move(a), Body.move(b)), Body.move(c)), Body.bind(a, b)), Body.bind(a, c)),
    Body.bind(b, c))

# Newton's third law: three pulls feed six kicks.
def Sys.kick(+s: Sys, +ab: Vec, +ac: Vec, +bc: Vec, +h: D.F64) -> Sys:
  Sys{a, b, c} = s
  Body{_, _, _, _, ma} = a
  Body{_, _, _, _, mb} = b
  Body{_, _, _, _, mc} = c
  Vec{abx, aby} = ab
  Vec{acx, acy} = ac
  Vec{bcx, bcy} = bc
  Sys{Body.kick(a, D.add(D.mul(mb, abx), D.mul(mc, acx)), D.add(D.mul(mb, aby), D.mul(mc, acy)), h),
    Body.kick(b, D.sub(D.mul(mc, bcx), D.mul(ma, abx)), D.sub(D.mul(mc, bcy), D.mul(ma, aby)), h),
    Body.kick(c, D.neg(D.add(D.mul(ma, acx), D.mul(mb, bcx))), D.neg(D.add(D.mul(ma, acy), D.mul(mb, bcy))), h)}

def Sys.drift(+s: Sys, +h: D.F64) -> Sys:
  Sys{a, b, c} = s
  Sys{Body.drift(a, h), Body.drift(b, h), Body.drift(c, h)}

def Sys.pulled(+s: Sys, +h: D.F64) -> Sys:
  Sys{a, b, c} = s
  Sys.kick(s, Body.pull(a, b), Body.pull(a, c), Body.pull(b, c), h)

# A leapfrog: half a drift, a kick, half a drift.
def Sys.leap(+s: Sys, +h: D.F64) -> Sys:
  +hh = D.mul(Dbl.half(), h)
  Sys.drift(Sys.pulled(Sys.drift(s, hh), h), hh)

# Forest-Ruth: three leapfrogs of w, 1 - 2w and w, with w = 1/(2 - 2^(1/3))
# = 1.3512071919596578, cancel the error to the 4th order.
def Sys.step(+s: Sys, +h: D.F64) -> Sys:
  +w = D.mul(D.of_bits(1073061515, 1857643321), h)
  Sys.leap(Sys.leap(Sys.leap(s, w), D.sub(h, D.add(w, w))), w)

# The time scale of the tightest pair.
def Sys.pace(+s: Sys) -> D.F64:
  Sys{a, b, c} = s
  Rsq.of(Dbl.max(Body.pace(a, b), Dbl.max(Body.pace(a, c), Body.pace(b, c))))

# The system advanced by left, in steps of 2% (0.02) of its pace; the
# fuel bounds a frame's work, and a frame that runs out (a collision
# course) hands back the time it owes: the world slows down instead of
# lying.
def Sys.run(fuel: Nat, done: Bool, +left: D.F64, +s: Sys) -> Ran:
  match fuel:
    case 0n:
      Ran{s, left}
    case 1n+f:
      match done:
        case True{}:
          Ran{s, left}
        case False{}:
          +h = Dbl.min(left, D.mul(D.of_bits(1066695393, 1202590843), Sys.pace(s)))
          +rest = D.sub(left, h)
          Sys.run(f, D.le(rest, Dbl.zero()), rest, Sys.step(s, h))

def Body.shift(p: Body, +dx: D.F64, +dy: D.F64, +du: D.F64, +dv: D.F64) -> Body:
  Body{x, y, u, v, m} = p
  Body{D.sub(x, dx), D.sub(y, dy), D.sub(u, du), D.sub(v, dv), m}

# sum m q / sum m, for q one coordinate of the three.
def Sys.mean(+am: D.F64, +bm: D.F64, +cm: D.F64, aq: D.F64, bq: D.F64, cq: D.F64, +inv: D.F64) -> D.F64:
  D.mul(D.add(D.add(D.mul(am, aq), D.mul(bm, bq)), D.mul(cm, cq)), inv)

# The system seen from its centre of mass, at rest: the camera never
# has to move.
def Sys.center(+s: Sys) -> Sys:
  Sys{a, b, c} = s
  Body{ax, ay, au, av, +am} = a
  Body{bx, by, bu, bv, +bm} = b
  Body{cx, cy, cu, cv, +cm} = c
  +inv = Dbl.inv(D.add(D.add(am, bm), cm))
  +x = Sys.mean(am, bm, cm, ax, bx, cx, inv)
  +y = Sys.mean(am, bm, cm, ay, by, cy, inv)
  +u = Sys.mean(am, bm, cm, au, bu, cu, inv)
  +v = Sys.mean(am, bm, cm, av, bv, cv, inv)
  Sys{Body.shift(a, x, y, u, v), Body.shift(b, x, y, u, v), Body.shift(c, x, y, u, v)}

# The square of a body's distance from the centre.
def Body.far(+p: Body) -> D.F64:
  Body{x, y, _, _, _} = p
  D.add(D.mul(x, x), D.mul(y, y))

# Are the three bodies somewhere (within 10^6)? A comparison with a NaN
# is False, so a body that is not a number fails it.
def Sys.sane(+s: Sys) -> Bool:
  Sys{a, b, c} = s
  +big = D.of_bits(1114446484, 2717908992)
  D.lt(Body.far(a), big) && D.lt(Body.far(b), big) && D.lt(Body.far(c), big)

# Is p leaving for good? Seen from the centre of mass of the other
# two, it is more than 800 px away, moving outwards, and its two-body
# energy is positive: an ejection, not an excursion.
def Body.gone(+p: Body, +q: Body, +r: Body, +zoom: D.F64) -> Bool:
  Body{px, py, pu, pv, pm} = p
  Body{qx, qy, qu, qv, +qm} = q
  Body{rx, ry, ru, rv, +rm} = r
  +m = D.add(qm, rm)
  +inv = Dbl.inv(m)
  +dx = D.sub(px, D.mul(D.add(D.mul(qm, qx), D.mul(rm, rx)), inv))
  +dy = D.sub(py, D.mul(D.add(D.mul(qm, qy), D.mul(rm, ry)), inv))
  +wx = D.sub(pu, D.mul(D.add(D.mul(qm, qu), D.mul(rm, ru)), inv))
  +wy = D.sub(pv, D.mul(D.add(D.mul(qm, qv), D.mul(rm, rv)), inv))
  +r2 = D.add(D.mul(dx, dx), D.mul(dy, dy))
  +d = D.mul(r2, Rsq.of(r2))
  D.lt(D.of_bits(1082720256, 0), D.mul(d, zoom)) && D.lt(Dbl.zero(), D.add(D.mul(dx, wx), D.mul(dy, wy)))
    && D.lt(D.add(pm, m), D.mul(D.mul(Dbl.half(), D.add(D.mul(wx, wx), D.mul(wy, wy))), d))

def Sys.gone(+s: Sys, +zoom: D.F64) -> Bool:
  Sys{a, b, c} = s
  Body.gone(a, b, c, zoom) || Body.gone(b, a, c, zoom) || Body.gone(c, a, b, zoom)

# Scenarios
# ---------
# Ten initial conditions. 0-4 are periodic solutions: the figure-8
# of Moore, Chenciner and Montgomery, and four of Suvakov and
# Dmitrasinovic's (2013), which start at (-1, 0), (1, 0), (0, 0) with
# velocities (p, q), (p, q), (-2p, -2q). 5 is Lagrange's rotating
# triangle, unstable for equal masses: it holds for a few turns, then
# the rounding of the last bit is enough to tear it apart. 6 is
# Burrau's Pythagorean problem: masses 3, 4, 5 at rest on the corners
# of a 3-4-5 triangle. 7 and 8 are hierarchies that last: a star, a
# planet and its moon; a planet around a binary star. 9 is drawn from
# the seed: three masses dropped almost at rest.

def Scn.count() -> U32:
  10

# (-1, 0), (1, 0) and (0, 0), with velocities (p, q), (p, q), (-2p, -2q).
def Scn.trio(+p: D.F64, +q: D.F64) -> Sys:
  +one = D.of_bits(1072693248, 0)
  +two = D.of_bits(1073741824, 0)
  Sys{Body{D.neg(one), Dbl.zero(), p, q, one}, Body{one, Dbl.zero(), p, q, one},
    Body{Dbl.zero(), Dbl.zero(), D.neg(D.mul(two, p)), D.neg(D.mul(two, q)), one}}

def Scn.rand(+x: U32) -> U32:
  +a = (x .^. x << 13n : U32)
  +b = (a .^. a >> 17n : U32)
  (b .^. b << 5n : U32)

# A number in [0, 1) from the seed's k-th successor.
def Scn.unit(k: Nat, +seed: U32) -> F32:
  match k:
    case 0n:
      (U32.to_f32((seed >> 8n .&. 65535 : U32)) / 65536.0 : F32)
    case 1n+j:
      Scn.unit(j, Scn.rand(seed))

# A body of the random scenario: near the i-th corner of a triangle,
# 0.7 to 1.3 from the centre, with a mass of 0.6 to 1.4, turning with
# the others at half a radian per unit of time plus a drift of its own
# (cold enough to stay bound, with enough spin to dance for a while
# before one is flung out). It is drawn in floats, then held as doubles.
def Scn.drop(+i: Nat, +seed: U32) -> Body:
  +k = Nat.mul(i, 5n)
  +ang = (2.0943951 * U32.to_f32(U32.from_nat(i)) + 1.2 * Scn.unit(Nat.add(k, 1n), seed) : F32)
  +rad = (0.7 + 0.6 * Scn.unit(Nat.add(k, 2n), seed) : F32)
  +x = (rad * F32.cos(ang) : F32)
  +y = (rad * F32.sin(ang) : F32)
  Body{Dbl.of_f32(x), Dbl.of_f32(y), Dbl.of_f32((0.5 * Scn.unit(Nat.add(k, 3n), seed) - 0.25 - 0.5 * y : F32)),
    Dbl.of_f32((0.5 * Scn.unit(Nat.add(k, 4n), seed) - 0.25 + 0.5 * x : F32)),
    Dbl.of_f32((0.6 + 0.8 * Scn.unit(Nat.add(k, 5n), seed) : F32))}

def Scn.sys(id: U32, +seed: U32) -> Sys:
  match id:
    case 0:
      # (0.97000436, -0.24308753), (-0.97000436, 0.24308753), (0, 0);
      # velocities (0.466203685, 0.43236573) twice and minus twice that.
      Sys{Body{D.of_bits(1072630342, 2506468697), D.of_bits(3218021757, 4290063474), D.of_bits(1071502919, 4212547904), D.of_bits(1071360993, 1334884082), D.of_bits(1072693248, 0)},
        Body{D.of_bits(3220113990, 2506468697), D.of_bits(1070538109, 4290063474), D.of_bits(1071502919, 4212547904), D.of_bits(1071360993, 1334884082), D.of_bits(1072693248, 0)},
        Body{D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(3220035143, 4212547904), D.of_bits(3219893217, 1334884082), D.of_bits(1072693248, 0)}}
    case 1:
      # (0.30689, 0.12551)
      Scn.trio(D.of_bits(1070834709, 4099803982), D.of_bits(1069551798, 816387384))
    case 2:
      # (0.46444, 0.39606)
      Scn.trio(D.of_bits(1071495522, 2361201221), D.of_bits(1071208716, 181419419))
    case 3:
      # (0.51394, 0.30474)
      Scn.trio(D.of_bits(1071673906, 1283679825), D.of_bits(1070825692, 863116628))
    case 4:
      # (0.55906, 0.34919)
      Scn.trio(D.of_bits(1071768529, 3423604331), D.of_bits(1071012129, 59098750))
    case 5:
      # (0, 1), (-0.8660254, -0.5), (0.8660254, -0.5); velocities
      # (-0.7598357, 0), (0.3799178, -0.658037), (0.3799178, 0.658037).
      Sys{Body{D.of_bits(0, 0), D.of_bits(1072693248, 0), D.of_bits(3219673234, 4114262560), D.of_bits(0, 0), D.of_bits(1072693248, 0)},
        Body{D.of_bits(3219895930, 3864013713), D.of_bits(3219128320, 0), D.of_bits(1071141010, 3213542635), D.of_bits(3219459747, 2622610110), D.of_bits(1072693248, 0)},
        Body{D.of_bits(1072412282, 3864013713), D.of_bits(3219128320, 0), D.of_bits(1071141010, 3213542635), D.of_bits(1071976099, 2622610110), D.of_bits(1072693248, 0)}}
    case 6:
      # masses 3, 4, 5 at rest at (1, 3), (-2, -1), (1, -1).
      Sys{Body{D.of_bits(1072693248, 0), D.of_bits(1074266112, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1074266112, 0)}, Body{D.of_bits(3221225472, 0), D.of_bits(3220176896, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1074790400, 0)},
        Body{D.of_bits(1072693248, 0), D.of_bits(3220176896, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1075052544, 0)}}
    case 7:
      # a star of mass 1; a planet of 0.01 at (1, 0) moving at 1.00504;
      # a moon of 0.0001 at (1.05, 0) moving at 1.45448.
      Sys{Body{D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1072693248, 0)}, Body{D.of_bits(1072693248, 0), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1072698532, 3534929883), D.of_bits(1065646817, 1202590843)},
        Body{D.of_bits(1072745676, 3435973837), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1073169804, 3523934767), D.of_bits(1058682594, 3944497965)}}
    case 8:
      # stars of 1 and 0.7 at -0.24706 and 0.35294, moving at -0.69311
      # and 0.99015; a planet of 0.002 at 2.2, moving at 0.87957.
      Sys{Body{D.of_bits(3218055081, 2115185494), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(3219533301, 97581657), D.of_bits(1072693248, 0)},
        Body{D.of_bits(1071027857, 2807877819), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1072672591, 226774273), D.of_bits(1072064102, 1717986918)},
        Body{D.of_bits(1073846681, 2576980378), D.of_bits(0, 0), D.of_bits(0, 0), D.of_bits(1072440687, 4228996598), D.of_bits(1063281229, 3539053052)}}
    case _:
      Sys{Scn.drop(0n, seed), Scn.drop(1n, seed), Scn.drop(2n, seed)}

# Pixels per unit of length.
def Scn.zoom(id: U32) -> F32:
  match id:
    case 0:
      400.0
    case 1:
      400.0
    case 2:
      270.0
    case 3:
      235.0
    case 4:
      230.0
    case 5:
      150.0
    case 6:
      100.0
    case 7:
      300.0
    case 8:
      140.0
    case _:
      130.0

# Units of time per second.
def Scn.rate(id: U32) -> F32:
  match id:
    case 0:
      0.9
    case 1:
      0.8
    case 2:
      1.4
    case 3:
      1.5
    case 4:
      2.0
    case 5:
      1.6
    case 6:
      1.4
    case 7:
      0.5
    case 8:
      1.2
    case _:
      1.6

# Seconds on tour.
def Scn.show(id: U32) -> U32:
  match id:
    case 5:
      60
    case 6:
      70
    case 9:
      70
    case _:
      40

def Scn.name(id: U32) -> String:
  match id:
    case 0:
      "Figure-8 (Moore, Chenciner-Montgomery)"
    case 1:
      "Butterfly I (Suvakov-Dmitrasinovic)"
    case 2:
      "Moth I (Suvakov-Dmitrasinovic)"
    case 3:
      "Yin-Yang I (Suvakov-Dmitrasinovic)"
    case 4:
      "Yarn (Suvakov-Dmitrasinovic)"
    case 5:
      "Lagrange's triangle: from order to chaos"
    case 6:
      "Burrau's Pythagorean problem (3-4-5)"
    case 7:
      "Star, planet and moon"
    case 8:
      "A planet of two stars"
    case _:
      "Chaos: three random masses"

# Light
# -----
# What the device needs of a frame, all scalars, so every fork carries
# them in registers. A Star is a body on screen: where it is, where it
# was half a frame and a frame ago (its trail is laid through the
# three), its radius in pixels and its mass. mode: bit 0 wipes the trails, bit 1 draws the
# field lines.

type Star is Data:
  Star{x: F32, y: F32, hx: F32, hy: F32, ox: F32, oy: F32, r: F32, m: F32}

type Uni is Data:
  Uni{a: Star, b: Star, c: Star, time: F32, phase: U32, fade: U32, mode: U32}

# What a body gives a pixel: light of its own colour, white heat, its
# potential, its share of the field's gradient, and the trail it lays
# there (0..63).
type Lit is Data:
  Lit{w: F32, k: F32, p: F32, gx: F32, gy: F32, t: U32}

def Px.hash(x: U32, y: U32) -> U32:
  +a = (x * 374761393 + y * 668265263 : U32)
  +b = ((a .^. a >> 13n) * 1274126177 : U32)
  (b .^. b >> 16n : U32)

# The square of the distance from (fx, fy) to the segment a-b.
def Px.seg(fx: F32, fy: F32, +ax: F32, +ay: F32, bx: F32, by: F32) -> F32:
  +ex = (bx - ax : F32)
  +ey = (by - ay : F32)
  +px = (fx - ax : F32)
  +py = (fy - ay : F32)
  +t = sat(((px * ex + py * ey) / (ex * ex + ey * ey + 0.000001) : F32))
  +qx = (px - t * ex : F32)
  +qy = (py - t * ey : F32)
  (qx * qx + qy * qy : F32)

# A body at a pixel: a disc of white heat with a soft edge, a tight
# halo and a wide one, both falling with the square of the distance,
# four diffraction spikes, the potential m/d and its gradient (d
# softened by 2 px), and the trail between where it was and where it is.
def Star.lit(+s: Star, +fx: F32, +fy: F32) -> Lit:
  Star{x, y, hx, hy, ox, oy, r, m} = s
  +dx = (fx - x : F32)
  +dy = (fy - y : F32)
  +d2 = (dx * dx + dy * dy : F32)
  +rr = (r * r : F32)
  +i = (1.0 / F32.sqrt((d2 + 4.0 : F32)) : F32)
  +p = (m * i : F32)
  +q = (p * i * i : F32)
  +core = sat(((rr - d2) / r * 0.45 + 0.5 : F32))
  +reach = (25.0 * rr : F32)
  +sx = (reach / (reach + dx * dx) : F32)
  +sy = (reach / (reach + dy * dy) : F32)
  +spike = (sat((1.0 - 0.75 * F32.abs(dy) : F32)) * sx * sx + sat((1.0 - 0.75 * F32.abs(dx) : F32)) * sy * sy : F32)
  +gain = (0.9 * sat((0.25 * (r - 3.0) : F32)) : F32)
  +lay = sat((1.3 + 0.08 * r - F32.sqrt(min(Px.seg(fx, fy, ox, oy, hx, hy), Px.seg(fx, fy, hx, hy, x, y))) : F32))
  Lit{(2.0 * rr / (d2 + rr) + 8.0 * rr / (d2 + reach) + gain * spike + 2.0 * core : F32), (3.0 * core : F32),
    p, (q * dx : F32), (q * dy : F32), F32.to_u32((63.0 * lay : F32))}

# A channel through the film's curve to 0..255, with d in [0, 1) of
# dither so the dark gradients do not band.
def Px.tone(c: F32, d: F32) -> U32:
  F32.to_u32((255.0 * (1.0 - F32.exp((0.0 - c : F32))) + d : F32))

# The pixel from the three bodies' light, its hash and its last word.
#
# The trail is the word's top byte: who passed (2 bits) and how fresh
# (6 bits). It loses a level when the frame's clock crosses the pixel's
# own phase (the hash's low 6 bits), so a line fades in 63 x 64 ticks
# and neighbours never step together; a body passing over writes its
# own. The field lines are the levels of 7 ln(potential): e is the
# distance to the nearest level and slope the levels per pixel, so
# e / slope is the distance to the line in pixels, whatever the field;
# every fourth is drawn stronger, and lines closer than two pixels fade
# before they alias. Each line takes the colours of the bodies in
# proportion to their share of the potential there.
def Px.mix(
  +x: U32, +y: U32, +old: U32, la: Lit, lb: Lit, lc: Lit, time: F32, phase: U32, fade: U32, +mode: U32
) -> U32:
  Lit{wa, ka, +pa, gxa, gya, +ta} = la
  Lit{wb, kb, +pb, gxb, gyb, +tb} = lb
  Lit{wc, kc, +pc, gxc, gyc, +tc} = lc
  +h = Px.hash(x, y)
  +in0 = (old >> 24n .&. 63 : U32)
  +due = ((((phase - h) .&. 63) < fade) && (in0 > 0) : U32)
  +in1 = word(((mode .&. 1) > 0 : U32), 0, word(due, (in0 - 1 : U32), in0))
  +k1 = ((ta > 0) && (ta >= in1) : U32)
  +v1 = word(k1, ta, in1)
  +k2 = ((tb > 0) && (tb >= v1) : U32)
  +v2 = word(k2, tb, v1)
  +k3 = ((tc > 0) && (tc >= v2) : U32)
  +v3 = word(k3, tc, v2)
  +id = word(k3, 3, word(k2, 2, word(k1, 1, (old >> 30n : U32))))
  +tv = (U32.to_f32(v3) / 63.0 : F32)
  +glow = (tv * tv * 0.9 + tv * 0.1 : F32)
  +p = (pa + pb + pc : F32)
  +gx = (gxa + gxb + gxc : F32)
  +gy = (gya + gyb + gyc : F32)
  +lvl = (7.0 * F32.log(p) : F32)
  +n = F32.floor((lvl + 0.5 : F32))
  +e = F32.abs((lvl - n : F32))
  +slope = (7.0 * F32.sqrt((gx * gx + gy * gy : F32)) / p + 0.000001 : F32)
  +major = pick(F32.is_eq((n - 4.0 * F32.floor((0.25 * n : F32)) : F32), 0.0), 0.26, 0.11)
  +line = (major * sat((1.2 - e / slope : F32)) * sat((2.4 - 4.0 * slope : F32))
    * U32.to_f32((mode >> 1n .&. 1 : U32)) / p : F32)
  +fa = (wa + line * pa + pick(U32.is_eq(id, 1), glow, 0.0) : F32)
  +fb = (wb + line * pb + pick(U32.is_eq(id, 2), glow, 0.0) : F32)
  +fc = (wc + line * pc + pick(U32.is_eq(id, 3), glow, 0.0) : F32)
  +k = (ka + kb + kc : F32)
  +vx = ((U32.to_f32(x) - 639.5) * 0.00136 : F32)
  +vy = ((U32.to_f32(y) - 359.5) * 0.00136 : F32)
  +bg = (1.0 - 0.7 * (vx * vx + vy * vy) : F32)
  +lum = (U32.to_f32((h >> 17n .&. 255 : U32)) * 0.0039215686 : F32)
  +star = pick(((h >> 6n .&. 2047) < 3 : U32), ((0.1 + 0.9 * lum * lum * lum)
    * (0.72 + 0.28 * F32.sin((time * (1.3 + 0.45 * U32.to_f32((h >> 25n .&. 7 : U32)))
      + 0.39 * U32.to_f32((h >> 28n : U32)) : F32))) : F32), 0.0)
  +warm = U32.to_f32((h >> 5n .&. 1 : U32))
  +d = (U32.to_f32((h * 2654435761 >> 24n : U32)) * 0.00390625 : F32)
  (id << 30n .|. v3 << 24n
    .|. Px.tone((0.012 * bg + star * (0.8 + 0.2 * warm) + 0.3 * fa + fb + fc + k : F32), d) << 16n
    .|. Px.tone((0.016 * bg + star * 0.88 + 0.6 * fa + 0.7 * fb + 0.28 * fc + k : F32), d) << 8n
    .|. Px.tone((0.034 * bg + star * (1.0 - 0.25 * warm) + fa + 0.25 * fb + 0.4 * fc + k : F32), d) : U32)

def Px.at(+x: U32, +y: U32, old: U32, +u: Uni) -> U32:
  Uni{a, b, c, time, phase, fade, mode} = u
  +fx = (U32.to_f32(x) + 0.5 : F32)
  +fy = (U32.to_f32(y) + 0.5 : F32)
  Px.mix(x, y, old, Star.lit(a, fx, fy), Star.lit(b, fx, fy), Star.lit(c, fx, fy), time, phase, fade,
    mode)

# Frame
# -----
# The last frame's image of a region as its quadrants: it goes down the
# fork tree beside the new one, and each pixel reads its old word (the
# match frees the node: the last frame is dropped where it is read).

type Four is Data:
  Four{a: Image, b: Image, c: Image, d: Image}

def Old.open(old: Image) -> Four:
  match old:
    case Pix{+c}:
      Four{Pix{c}, Pix{c}, Pix{c}, Pix{c}}
    case Qua{a, b, c, d}:
      Four{a, b, c, d}

def Old.word(old: Image) -> U32:
  match old:
    case Pix{c}:
      c
    case Qua{a, b, c, d}:
      0

# A tile as four 4-squares of four 2-squares of four pixels,
# straight-line: a recursion costs a frame per square on the device.
def Tile.b2(+x: U32, +y: U32, old: Four, +u: Uni) -> Image:
  Four{a, b, c, d} = old
  +x1 = (x + 1 : U32)
  +y1 = (y + 1 : U32)
  Qua{Pix{Px.at(x, y, Old.word(a), u)}, Pix{Px.at(x1, y, Old.word(b), u)},
    Pix{Px.at(x, y1, Old.word(c), u)}, Pix{Px.at(x1, y1, Old.word(d), u)}}

def Tile.b4(+x: U32, +y: U32, old: Four, +u: Uni) -> Image:
  Four{a, b, c, d} = old
  +x1 = (x + 2 : U32)
  +y1 = (y + 2 : U32)
  Qua{Tile.b2(x, y, Old.open(a), u), Tile.b2(x1, y, Old.open(b), u),
    Tile.b2(x, y1, Old.open(c), u), Tile.b2(x1, y1, Old.open(d), u)}

def Tile.b8(+x: U32, +y: U32, old: Four, +u: Uni) -> Image:
  Four{a, b, c, d} = old
  +x1 = (x + 4 : U32)
  +y1 = (y + 4 : U32)
  Qua{Tile.b4(x, y, Old.open(a), u), Tile.b4(x1, y, Old.open(b), u),
    Tile.b4(x, y1, Old.open(c), u), Tile.b4(x1, y1, Old.open(d), u)}

# The frame, 1280 x 720 under a 2048 root.
def Screen.w() -> U32:
  1280

def Screen.h() -> U32:
  720

# A region of 8 << k pixels a side: off the frame it is one black Pix
# before any fork; on it, four-way forks down to the 8-px tiles, one
# per lane (a fork per pixel drowns in scheduling, a fork per big cell
# leaves lanes idle).
def Frame.node(+k: Nat, on: Bool, +x: U32, +y: U32, old: Four, +u: Uni) -> Image:
  match k on:
    case 0n True{}:
      Tile.b8(x, y, old, u)
    case 1n+e True{}:
      Four{oa, ob, oc, od} = old
      +s = U32.shln(8, e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      a b c d = Frame.node(e, True{}, x, y, Old.open(oa), u)
        Frame.node(e, (x1 < Screen.w() : U32), x1, y, Old.open(ob), u)
        Frame.node(e, (y1 < Screen.h() : U32), x, y1, Old.open(oc), u)
        Frame.node(e, ((x1 < Screen.w()) && (y1 < Screen.h()) : U32), x1, y1, Old.open(od), u)
      Qua{a, b, c, d}
    case _ False{}:
      Pix{0}

# The frame over the last one: one bang, in a pure def (inside a do
# block the callee would own what it reads).
def Frame.show(u: Uni, old: Image) -> Image:
  Frame.node!(8n, True{}, 0, 0, Old.open(old), u)

# World
# -----
# The bodies now and a frame ago, the scenario's run, the user's
# options, and the clocks.

# id: the scenario; seed: the random one's; t: the time simulated; e0:
# the energy it started with; age: the milliseconds it has been on;
# wipe: the trails must go before the next frame.
type Run is Data:
  Run{id: U32, seed: U32, t: D.F64, e0: D.F64, age: U32, wipe: Bool}

type Opt is Data:
  Opt{paused: Bool, lines: Bool, tour: Bool, speed: F32}

# stamp: the last frame's clock; clock: the milliseconds the trails
# have aged; fade: the trail ticks of this frame; begin and frames
# count the frame rate.
type Clk is Data:
  Clk{stamp: Nat, clock: U32, fade: U32, begin: Nat, frames: U32}

# Where the bodies were: half a frame ago and a frame ago.
type Past is Data:
  Past{mid: Sys, old: Sys}

type World is Data:
  World{sys: Sys, was: Past, run: Run, opt: Opt, clk: Clk}

# The trail tick of a clock: 4032 ticks (63 levels of 64) in 30 s.
def Clk.tick(c: U32) -> U32:
  (c * 43 / 320 : U32)

# A scenario from its start, under the options and clocks of w.
def World.load(+id: U32, w: World) -> World:
  World{_, _, run, opt, clk} = w
  Run{_, seed, _, _, _, _} = run
  +next = Scn.rand((seed + 2654435761 : U32))
  +s = Sys.center(Scn.sys(id, next))
  World{s, Past{s, s}, Run{id, next, Dbl.zero(), Sys.energy(s), 0, True{}}, opt, clk}

def World.init(+now: Nat) -> World:
  +s = Sys.center(Scn.sys(0, 0))
  World.load(0, World{s, Past{s, s}, Run{0, U32.from_nat(now), Dbl.zero(), Dbl.zero(), 0, True{}},
    Opt{False{}, True{}, True{}, 1.0}, Clk{now, 0, 0, now, 0}})

# The scenario after this one.
def World.next(+w: World) -> World:
  World{_, _, run, _, _} = w
  Run{id, _, _, _, _, _} = run
  World.load(((id + 1) % Scn.count() : U32), w)

# This scenario from its start (the random one, with new bodies).
def World.again(+w: World) -> World:
  World{_, _, run, _, _} = w
  Run{id, _, _, _, _, _} = run
  World.load(id, w)

def World.aged(age: U32, w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Run{id, seed, t, e0, _, wipe} = run
  World{sys, was, Run{id, seed, t, e0, age, wipe}, opt, clk}

# A body was flung out: the tour moves on, but the random scenario
# draws three new bodies until its own time is up.
def World.flung(random: Bool, +w: World) -> World:
  match random:
    case True{}:
      World{_, _, run, _, _} = w
      Run{_, _, _, _, age, _} = run
      World.aged(age, World.again(w))
    case False{}:
      World.next(w)

# The run after a frame: lost (a body is not a number) starts it over;
# on tour, late (its time is up) moves on, and so does flung (a body
# is ejected).
def World.fate(lost: Bool, late: Bool, flung: Bool, +w: World) -> World:
  match lost late flung:
    case True{} _ _:
      World.again(w)
    case False{} True{} _:
      World.next(w)
    case False{} False{} True{}:
      World{_, _, run, _, _} = w
      Run{id, _, _, _, _, _} = run
      World.flung(U32.is_eq(id, 9), w)
    case False{} False{} False{}:
      w

# The world after the frame's run: the time it got to, its age, the
# trail ticks that passed, and its fate.
def World.land(ran: Ran, mid: Sys, +dt: D.F64, +ms: U32, +now: Nat, +w: World) -> World:
  Ran{+s, left} = ran
  World{sys, _, run, opt, clk} = w
  Run{id, seed, t, e0, age, wipe} = run
  Opt{_, _, tour, _} = opt
  Clk{_, clock, _, begin, frames} = clk
  +old = (age + ms : U32)
  +c = (clock + ms : U32)
  World.fate(Bool.not(Sys.sane(s)), tour && (old > Scn.show(id) * 1000 : U32),
    tour && Sys.gone(s, Dbl.of_f32(Scn.zoom(id))), World{s, Past{mid, sys}, Run{id, seed, D.sub(D.add(t, dt), left), e0, old, wipe}, opt,
      Clk{now, c, (Clk.tick(c) - Clk.tick(clock) : U32), begin, (frames + 1 : U32)}})

# The second half of the frame's run, from where the first got to and
# with the time it left; the bodies in between give the trail a bend.
def World.half(ran: Ran, half: D.F64, +dt: D.F64, +ms: U32, +now: Nat, +w: World) -> World:
  Ran{+mid, left} = ran
  +due = D.add(half, left)
  World.land(Sys.run(2048n, D.le(due, Dbl.zero()), due, mid), mid, dt, ms, now, w)

# A frame of the world: paused, only the clocks move; else the bodies
# run for the time since the last frame (50 ms at most) at the
# scenario's rate and the user's speed.
def World.turn(paused: Bool, +ms: U32, +now: Nat, +w: World) -> World:
  match paused:
    case True{}:
      World{sys, _, run, opt, clk} = w
      Clk{_, clock, _, begin, frames} = clk
      World{sys, Past{sys, sys}, run, opt, Clk{now, clock, 0, begin, (frames + 1 : U32)}}
    case False{}:
      World{sys, _, run, opt, _} = w
      Run{id, _, _, _, _, _} = run
      Opt{_, _, _, speed} = opt
      +dt = Dbl.of_f32((U32.to_f32(ms) * 0.001 * Scn.rate(id) * speed : F32))
      +half = D.mul(Dbl.half(), dt)
      World.half(Sys.run(2048n, D.le(half, Dbl.zero()), half, sys), half, dt, ms, now, w)

def World.tick(+now: Nat, +w: World) -> World:
  World{_, _, _, opt, clk} = w
  Opt{paused, _, _, _} = opt
  Clk{stamp, _, _, _, _} = clk
  +gap = U32.from_nat(Nat.sub(now, stamp))
  World.turn(paused, word((gap > 50 : U32), 50, gap), now, w)

# A body on screen, with where it was half a frame and a frame ago:
# the centre of mass at the centre of the frame, y up, the radius by
# the cube root of the mass (11 px for the heaviest).
def Body.star(p: Body, h: Body, o: Body, +zoom: F32, big: F32) -> Star:
  Body{x, y, _, _, m} = p
  Body{hx, hy, _, _, _} = h
  Body{ox, oy, _, _, _} = o
  +mf = Dbl.to_f32(m)
  Star{(640.0 + zoom * Dbl.to_f32(x) : F32), (360.0 - zoom * Dbl.to_f32(y) : F32),
    (640.0 + zoom * Dbl.to_f32(hx) : F32), (360.0 - zoom * Dbl.to_f32(hy) : F32),
    (640.0 + zoom * Dbl.to_f32(ox) : F32), (360.0 - zoom * Dbl.to_f32(oy) : F32),
    max(2.2, (11.0 * F32.pow((mf / big : F32), 0.33333334) : F32)), mf}

def Bit.of(b: Bool, v: U32) -> U32:
  word(b, v, 0)

# The frame's uniforms.
def World.view(+w: World) -> Uni:
  World{sys, was, run, opt, clk} = w
  Sys{a, b, c} = sys
  Body{_, _, _, _, ma} = a
  Body{_, _, _, _, mb} = b
  Body{_, _, _, _, mc} = c
  Past{mid, old} = was
  Sys{ha, hb, hc} = mid
  Sys{oa, ob, oc} = old
  Run{id, _, _, _, _, wipe} = run
  Opt{_, lines, _, _} = opt
  Clk{stamp, clock, fade, _, _} = clk
  +zoom = Scn.zoom(id)
  +big = max(Dbl.to_f32(ma), max(Dbl.to_f32(mb), Dbl.to_f32(mc)))
  Uni{Body.star(a, ha, oa, zoom, big), Body.star(b, hb, ob, zoom, big), Body.star(c, hc, oc, zoom, big),
    (U32.to_f32((U32.from_nat(stamp) .&. 1048575 : U32)) * 0.001 : F32), (Clk.tick(clock) .&. 63 : U32), fade,
    (Bit.of(wipe, 1) .|. Bit.of(lines, 2) : U32)}

# The three bodies of a world.
def World.bodies(w: World) -> Sys:
  World{sys, _, _, _, _} = w
  sys

# The world once its frame is drawn: the trails are wiped only once.
def World.seen(w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Run{id, seed, t, e0, age, _} = run
  World{sys, was, Run{id, seed, t, e0, age, False{}}, opt, clk}

# Keys
# ----

def World.pause(w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Opt{paused, lines, tour, speed} = opt
  World{sys, was, run, Opt{Bool.not(paused), lines, tour, speed}, clk}

def World.lines(w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Opt{paused, lines, tour, speed} = opt
  World{sys, was, run, Opt{paused, Bool.not(lines), tour, speed}, clk}

def World.tour(w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Opt{paused, lines, tour, speed} = opt
  World{sys, was, run, Opt{paused, lines, Bool.not(tour), speed}, clk}

# The speed times k, kept in [1/8, 8].
def World.pace(k: F32, w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Opt{paused, lines, tour, speed} = opt
  World{sys, was, run, Opt{paused, lines, tour, min(8.0, max(0.125, (speed * k : F32)))}, clk}

# The scenario n places after this one.
def World.hop(n: U32, +w: World) -> World:
  World{_, _, run, _, _} = w
  Run{id, _, _, _, _, _} = run
  World.load(((id + n) % Scn.count() : U32), w)

# 1-9 are scenarios 0-8, and 0 is 9.
def World.digit(digit: Bool, zero: Bool, code: U32, w: World) -> World:
  match digit zero:
    case True{} _:
      World.load((code - 49 : U32), w)
    case False{} True{}:
      World.load(9, w)
    case False{} False{}:
      w

def World.key(+code: U32, +w: World) -> World:
  match code:
    case 32:
      World.pause(w)
    case 103:
      World.lines(w)
    case 116:
      World.tour(w)
    case 114:
      World.hop(0, w)
    case 110:
      World.hop(1, w)
    case 63235:
      World.hop(1, w)
    case 98:
      World.hop(9, w)
    case 63234:
      World.hop(9, w)
    case 63232:
      World.pace(1.25, w)
    case 63233:
      World.pace(0.8, w)
    case _:
      World.digit(((code >= 49) && (code <= 57) : U32), U32.is_eq(code, 48), code, w)

# Esc or Close quits; a key down is its command.
def World.event(e: Event, w: World) -> Maybe<World>:
  match e:
    case Key{27, True{}}:
      None{}
    case Close{}:
      None{}
    case Key{code, True{}}:
      Some{World.key(code, w)}
    case _:
      Some{w}

def World.events(events: List<Event>, w: World) -> Maybe<World>:
  match events:
    case []:
      Some{w}
    case e <> rest:
      Maybe.bind(&1, World, World, World.event(e, w), w2 => World.events(rest, w2))

# Title
# -----

def Tag.of(on: Bool, text: String) -> String:
  match on:
    case True{}:
      text
    case False{}:
      ""

# x with two decimals.
def Fix.show(+x: F32) -> String:
  +n = F32.to_u32((x * 100.0 + 0.5 : F32))
  +c = (n % 100 : U32)
  U32.show((n / 100 : U32)) ++ "." ++ Tag.of((c < 10 : U32), "0") ++ U32.show(c)

# The scenario, the frame rate, the time simulated, the drift of the
# energy in parts per million, the speed.
def World.title(w: World, fps: U32) -> String:
  World{+sys, _, run, opt, _} = w
  Run{+id, _, t, +e0, _, _} = run
  Opt{paused, _, tour, speed} = opt
  "3 Bodies | " ++ U32.show((id + 1 : U32)) ++ "/10 " ++ Scn.name(id) ++ " | " ++ U32.show(fps)
    ++ " FPS | t = " ++ Fix.show(Dbl.to_f32(t)) ++ " | dE/E = "
    ++ U32.show(F32.to_u32((1000000.0 * F32.abs(Dbl.to_f32(D.div(D.sub(Sys.energy(sys), e0), e0))) + 0.5 : F32)))
    ++ " ppm | x" ++ Fix.show(speed) ++ Tag.of(tour, " | tour") ++ Tag.of(paused, " | PAUSED")

# Loop
# ----

# The frame counter restarted at now.
def World.mark(now: Nat, w: World) -> World:
  World{sys, was, run, opt, clk} = w
  Clk{stamp, clock, fade, _, _} = clk
  World{sys, was, run, opt, Clk{stamp, clock, fade, now, 0}}

# Twice a second the title is written and the count restarts.
def Loop.pace(due: Bool, window: Window, +w: World, +now: Nat, k: Window -> World -> IO(Unit)) -> IO(Unit):
  match due:
    case False{}:
      k(window, w)
    case True{}:
      World{_, _, _, _, clk} = w
      Clk{_, _, _, begin, frames} = clk
      +ms = U32.from_nat(Nat.sub(now, begin))
      IO.bind(Window, Unit, Window.set_title(window, World.title(w, ((frames * 1000 + ms / 2) / ms : U32))),
        win => k(win, World.mark(now, w)))

# The end closes the window; else the next turn takes the image shown,
# to read its trails and drop it.
def Loop.next(window: Window, next: Maybe<World>, image: Image, rest: Window -> World -> Image -> IO(Unit)) -> IO(Unit):
  match next:
    case None{}:
      Window.close(window)
    case Some{w}:
      rest(window, w, image)

def Loop.shown(
  shown: Window & Image & List<Event>, +w: World, +now: Nat, rest: Window -> World -> Image -> IO(Unit)
) -> IO(Unit):
  (window, image, events) = shown
  World{_, _, _, _, clk} = w
  Clk{_, _, _, begin, _} = clk
  Loop.pace(Nat.is_ge(Nat.sub(now, begin), 500n), window, w, now,
    win => w2 => Loop.next(win, World.events(events, w2), image, rest))

# A turn: the world's frame on the host, an IO seam, the picture in one
# bang over the last one, the window, the events.
def Loop.go(fuel: Nat, window: Window, w: World, old: Image) -> IO(Unit):
  match fuel:
    case 0n:
      Window.close(window)
    case 1n+f:
      do IO<Unit>:
        +now : Nat <- IO.now()
        +w2 : World = World.tick(now, w)
        seam : Nat <- IO.now()
        image : Image <- IO.pure(Image, Frame.show(World.view(w2), old))
        shown : Window & Image & List<Event> <- Window.frame(window, image)
        Loop.shown(shown, World.seen(w2), now, win => w3 => img => Loop.go(f, win, w3, img))

def main() -> IO(Unit):
  do IO<Unit>:
    window : Window <- IO.try(Window, Window.open("The 3-Body Problem", Screen.w(), Screen.h()))
    +now : Nat <- IO.now()
    Loop.go(4294967295n, window, World.init(now), Pix{0})
