# Blazing

Générateur de coups légaux pour le jeu d'échecs.

## Compilation

```bash
zig build -Doptimize=ReleaseFast
```

## Utilisation

```bash
./zig-out/bin/Blazing <fen> <profondeur>
```

- `fen` : position initiale au format FEN
- `profondeur` : profondeur de recherche en nombre de coups

## Exemples

```bash
./zig-out/bin/Blazing "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 7
stdout
b1a3: 120142144
b1c3: 148527161
g1f3: 147678554
g1h3: 120669525
a2a3: 106743106
b2b3: 133233975
c2c3: 144074944
d2d3: 227598692
e2e3: 306138410
f2f3: 102021008
g2g3: 135987651
h2h3: 106678423
a2a4: 137077337
b2b4: 134087476
c2c4: 157756443
d2d4: 269605599
e2e4: 309478263
f2f4: 119614841
g2g4: 130293018
h2h4: 138495290
3195901860 nodes found in 4474ms (714.220 MNodes/s)
```

```bash
./zig-out/bin/Blazing "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 1
b1a3
b1c3
g1f3
g1h3
a2a3
b2b3
c2c3
d2d3
e2e3
f2f3
g2g3
h2h3
a2a4
b2b4
c2c4
d2d4
e2e4
f2f4
g2g4
h2h4
20 nodes found
```
