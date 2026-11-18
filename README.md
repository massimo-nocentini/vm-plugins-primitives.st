# vm-plugins-primitives.st

The Smalltalk side of the **UtilsPlugin** of the Pharo VM (Pharo 12 to 15): four small primitives in C, each with a Smalltalk twin that answers the same bits when the VM has no plugin.

```smalltalk
Metacello new
	baseline: 'VMPluginsPrimitives';
	repository: 'github://massimo-nocentini/vm-plugins-primitives.st:master/src';
	load
```

The groups are `Core` (the package `VM-Plugins-Primitives`), `Tests` (`VM-Plugins-Primitives-Tests`) and `default` (both).

The plugin is built by [massimo-nocentini/pharo-vm](https://github.com/massimo-nocentini/pharo-vm), in `plugins/UtilsPlugin`, where this repository is the submodule `plugins/UtilsPlugin/vm-plugins-primitives.st`. Its `docs/UtilsPlugin.md` is the contract: the semantics, the primitives, the tests and the speed.

## What it gives

```smalltalk
"The fused multiply-add: x * y + z rounded once (C's fma)"
(1.0 + (2 raisedTo: -52)) times: 1.0 - (2 raisedTo: -53) plus: -1.0.	"2^-53 - 2^-105, not 0"

"Strings split by delimiters: the runs of non-delimiters, or every field"
' a  b ' strtok: ' ' inclusive: false.		"#('a' 'b')"
'a,,b,' strtok: ',' inclusive: true.		"#('a' '' 'b'): an empty last field is dropped"
'one
two

three' linesIncludeEmptySubstrings: true.		"#('one' 'two' '' 'three'), as #lines"

"Points of a Bezier curve (de Casteljau)"
{ 0 @ 0. 1 @ 2. 2 @ 0 } bezierPointsAt: (0 to: 1 by: 0.25).
{ 0 @ 0. 10 @ 20 } bezierPointAt: 0.5.		"5.0 @ 10.0"

"Knuth's lagged Fibonacci generator (TAOCP 3.6), a Random"
(KnuthRandom seed: 310952) next: 3.
(1 to: 10) asArray shuffleBy: KnuthRandom new.
```

Each method:

- **tries the plugin first.** On a VM without it, or when a primitive does not take the arguments, it answers through `UtilsPluginSmalltalk`, the Smalltalk twin of the primitives, with the same result bit for bit (NaN payloads aside), or signals the error.
- **`UtilsPlugin isAvailable`** tells whether the VM has the plugin.
- **`UtilsPlugin pluginHidden: true`** makes everything take the Smalltalk way (the tests run both ways with it).

## Notes

- **`Float>>#times:plus:`** converts its arguments with `asFloat`. Its Smalltalk twin computes the exact value with Fractions and rounds it once, to the nearest Float, ties to even. It does not use `asFloat` for that: on Pharo 12, `LargeNegativeInteger>>#asFloat` does not always answer the nearest Float.
- **`strtok:inclusive:` treats every delimiter character on its own**, so CR LF makes an empty field when `inclusive` is true. `linesIncludeEmptySubstrings:` follows `#lines`, where CR LF ends one line.
- **The Bézier scheme** is that of the original plugin: a recurrence of fused products and sums. t = 0 answers the first control point and t = 1 the last one. Outside [0, 1] it extrapolates, with IEEE infinities and NaNs where it divides by zero.
- **`KnuthRandom`** keeps its state in the `state` of `Random`, plain objects that survive an image save. Only the low 30 bits of the seed count, as in Knuth's code. Its Smalltalk twin translates Knuth's `ranf_start` and `ranf_array`, and checks his own test value.

## History

This repository first held the Smalltalk side of the plugins of the `pharo-10` branch of pharo-vm: Cairo and Pango, DateTimeFormatter, an older timsort, and these primitives. It now holds only the four features of the UtilsPlugin of `pharo-12`; the old code is in its history. The timsort lives in [timsort.st](https://github.com/massimo-nocentini/timsort.st).

## Licence

MIT (`LICENSE`). The plugin runs Knuth's `rng-double.c` unchanged; it is in the public domain "as long as you make absolutely no changes", and `UtilsPluginSmalltalk` is a translation of it.
