# Blazing

Générateur de coups légaux pour le jeu d'échecs.

## Compilation

`zig build -Doptimize=ReleaseFast`

## Utilisation

`./zig-out/bin/Blazing <fen> <profondeur> [info|noinfo]`

- `fen` : position initiale au format FEN
- `profondeur` : profondeur de recherche en nombre de coups
- `info|noinfo` : affichage des coups de premier niveau (noinfo par défaut)

## Exemples

```bash
> ./zig-out/bin/Blazing "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 6
119060324 nodes found in 485ms (245.320 MNodes/s)
```

```bash
> ./zig-out/bin/Blazing "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 4 info
b1a3: 8885
b1c3: 9755
g1f3: 9748
g1h3: 8881
a2a3: 8457
b2b3: 9345
c2c3: 9272
d2d3: 11959
e2e3: 13134
f2f3: 8457
g2g3: 9345
h2h3: 8457
a2a4: 9329
b2b4: 9332
c2c4: 9744
d2d4: 12435
e2e4: 13160
f2f4: 8929
g2g4: 9328
h2h4: 9329
197281 nodes found in 4ms (44.870 MNodes/s)
```
