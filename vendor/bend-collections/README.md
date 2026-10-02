# bend-collections (vendored)

These files are copied unchanged from [Giulio2002/bend-collections](https://github.com/Giulio2002/bend-collections), commit `66a76aa`, under its MIT license (`LICENSE`).

`f64.bend` is IEEE-754 binary64 written in Bend on two `U32` words, with Berkeley SoftFloat's algorithms. Its author proves in that repository that every operation is correctly rounded; those proofs are not copied here. The other files are what `f64.bend` imports.

Three Bodies uses it for its physics: because these doubles are ordinary Bend code, the proof checker can compute them, which is what makes `PHYSICS.bend` possible.
