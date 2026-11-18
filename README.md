# vm-plugins-primitives.st

The Smalltalk side of two plugins of the Pharo VM (Pharo 12 to 15):

- the **UtilsPlugin**: four small primitives in C, each with a Smalltalk twin that answers the same bits when the VM has no plugin;
- the **CairoPlugin**: Athens drawing through cairo with named primitives instead of the callouts of the FFI, opt-in (see [CairoPlugin](#cairoplugin)).

```smalltalk
Metacello new
	baseline: 'VMPluginsPrimitives';
	repository: 'github://massimo-nocentini/vm-plugins-primitives.st:master/src';
	load
```

The groups are `Core` (the package `VM-Plugins-Primitives`), `Tests` (`VM-Plugins-Primitives-Tests`) and `default` (both). The CairoPlugin's groups, `Cairo`, `CairoTests` and `CairoBenchmarks`, are in no other group: they load only when named.

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

## CairoPlugin

The CairoPlugin of [massimo-nocentini/pharo-vm](https://github.com/massimo-nocentini/pharo-vm) (`plugins/CairoPlugin`, whose `docs/CairoPlugin.md` is the contract) lets Athens-Cairo draw through cairo without the FFI's callouts, on the same libcairo the FFI loads (or, on the WebAssembly VMs, the same cairo of the VM). The pixels, the cairo state and the answers are those of the FFI.

```smalltalk
Metacello new
	baseline: 'VMPluginsPrimitives';
	repository: 'github://massimo-nocentini/vm-plugins-primitives.st:master/src';
	load: #( 'Cairo' )
```

Loading `VM-Plugins-Primitives-Cairo` on a VM with the plugin binds it and installs its three groups, which patch the hot methods of Athens-Cairo at run time:

- `#basic`: one primitive per FFI callout (`newPath`, `moveToX:Y:`, `fill`, the matrices, the text metrics, `textPath:`…);
- `#shape`: `AthensCairoCanvas>>draw` of a Rectangle or an AthensCairoPath, filled with a Color or stroked, in one primitive;
- `#text`: a whole `drawString:` in one primitive, for ByteString, ByteSymbol, WideString and WideSymbol (UTF-8 by simdutf, in the plugin).

```smalltalk
CairoPlugin info.			"#(1 'CairoPlugin 1.0' 'native' 11806 'loader' nil #()), or nil without the plugin"
CairoPlugin installedGroups.		"#(#basic #shape #text)"
CairoPlugin uninstall.			"Athens as it was, the FFI everywhere"
CairoPlugin install: #( #basic ).	"only the one-for-one primitives"
CairoPlugin verify.			"#(): the patches are consistent"
CairoPlugin counters.			"the cairo calls made by the plugin, by function"
```

- **Each patch keeps the original** under `ffi<Selector>` (`ffiNewPath`, `ffiDraw`…) and falls back to it when its primitive fails, so Athens draws the same with or without the plugin. `uninstall` puts back uFFI's own methods at once, and removes the copies and the added methods once no process (a drawing preempted inside a patch) runs a patch of theirs.
- **Quiet:** the patches are installed with the system announcements suspended. Athens-Cairo is not marked modified and Epicea logs nothing. Uninstall before committing Athens-Cairo from such an image.
- **Sessions:** at each start of the image the plugin is bound again and the wanted groups installed; on a VM without the plugin they are uninstalled and stay wanted, so a later start with the plugin installs them again. Without the plugin nothing is ever installed: Athens keeps its FFI.
- **Guards:** a patch is installed only on the Athens source it was written for (Pharo 12 to 15), by a hash of each method it replaces or replicates; `verify` and each start check them again and uninstall what no longer matches (still wanted).
- **Upgrades:** loading a newer version of the package replaces the patches the older one installed (the baseline's post-load, and `install` at each start); `verify` reports a stale one.
- `VM-Plugins-Primitives-Cairo-Tests` (group `CairoTests`) checks the pixels, the cairo state, the answers and the calls of every group against the FFI, the failures of every primitive, the installer and the sessions: 51 tests: with the plugin, on Pharo 12 to 15 and on the WebAssembly VM, 48 pass and 3 (those of a VM without it) do not apply; without it 23 pass and the others skip, saying why.
- `VM-Plugins-Primitives-Cairo-Benchmarks` (group `CairoBenchmarks`, `CairoPluginBenchmark`) measures the FFI against the groups, in one image, the modes interleaved; pharo-vm's `plugins/CairoPlugin/bench/run-bench.sh <vm-dir> <image.zip> [--wasm | --wasm-web]` loads the three groups and runs it, and `summarize.py` makes the tables.
- **Speed** (FFI time / plugin time with every group installed, the geometric mean over the scenes of the benchmark): 1.55x on Cog (from 1.05x for a Roassal graph, where rasterizing dominates, to 3.9x for `drawString:`; single calls 1.8 to 3.9x faster) and 2.8x on the WebAssembly VMs (1.4 to 1.9x for Roassal, 8.5 to 11x for `drawString:`). The display of a surface in a Morph (`asForm`) stays on the FFI: about 2% of a frame. The tables are in pharo-vm's `docs/CairoPlugin.md`.

## Notes on the UtilsPlugin

- **`Float>>#times:plus:`** converts its arguments with `asFloat`. Its Smalltalk twin computes the exact value with Fractions and rounds it once, to the nearest Float, ties to even. It does not use `asFloat` for that: on Pharo 12, `LargeNegativeInteger>>#asFloat` does not always answer the nearest Float.
- **`strtok:inclusive:` treats every delimiter character on its own**, so CR LF makes an empty field when `inclusive` is true. `linesIncludeEmptySubstrings:` follows `#lines`, where CR LF ends one line.
- **The Bézier scheme** is that of the original plugin: a recurrence of fused products and sums. t = 0 answers the first control point and t = 1 the last one. Outside [0, 1] it extrapolates, with IEEE infinities and NaNs where it divides by zero.
- **`KnuthRandom`** keeps its state in the `state` of `Random`, plain objects that survive an image save. Only the low 30 bits of the seed count, as in Knuth's code. Its Smalltalk twin translates Knuth's `ranf_start` and `ranf_array`, and checks his own test value.

## History

This repository first held the Smalltalk side of the plugins of the `pharo-10` branch of pharo-vm: Cairo and Pango, DateTimeFormatter, an older timsort, and these primitives. It now holds the four features of the UtilsPlugin of `pharo-12`, and the Smalltalk side of the CairoPlugin of `pharo-12`, a new design (patches of Athens-Cairo installed at run time, on the cairo the FFI loads); the old code is in its history. The timsort lives in [timsort.st](https://github.com/massimo-nocentini/timsort.st).

## Licence

MIT (`LICENSE`). The plugin runs Knuth's `rng-double.c` unchanged; it is in the public domain "as long as you make absolutely no changes", and `UtilsPluginSmalltalk` is a translation of it.
