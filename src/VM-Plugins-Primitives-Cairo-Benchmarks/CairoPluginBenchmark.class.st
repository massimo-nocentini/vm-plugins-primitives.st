"
I measure Athens drawing through the FFI against the CairoPlugin, in one image and one VM (pharo-vm, `plugins/CairoPlugin/bench`, `docs/CairoPlugin.md`).

## The modes

- `#ffi` (nothing installed: stock Athens),
- `#basic` (the one-for-one primitives)
- and `#all` (basic, shape and text),

switched with the installer (`CairoPluginTestSupport setMode:`; from the second switch on, the installer reinstalls from its cache and compiles nothing).

## The scenes

- those of `CairoPluginScenes` (`a-polyline`, `a2-lines`, `b-rects`, `c-bezier`, `d-transforms`, `e-text` and its variants `e-text-wide` (WideStrings) and `e-text-long` (strings of 2000 characters, one `WideString` in four)),
- the Roassal graph drawn by `RSAthensRenderer` with its paths built at each run (`f-roassal-first`) or cached (`f-roassal-cached`),
- the same on an SVG surface (`g-roassal-svg-first/cached`),
- and `h-morph-frame`: an `RSAthensMorph` of that graph drawn on a `FormCanvas` of 800 x 600, end to end (Roassal, then `asForm` and the SurfacePlugin callbacks of BitBlt, which stay on the FFI);

each at surface sizes 1000 and 1 (the 1 px control: the same calls, nothing to rasterize).

## The micro-benchmarks (`micro`)

ns per call of single patched methods, with the controls:

- an empty Smalltalk loop,
- the Smalltalk side of a void FFI callout (the runner skips the call),
- an FFI callout of `cairo_version` (an empty C function),
- and a named primitive that does nothing (the FilePlugin's `primitiveDirectoryDelimitor`, which answers a Character);

each control's time includes the loop's (`ctl-loop`), which `summarize.py` subtracts in its net column.

## Per scene and size

1. The data are built once;
2. then, untimed, each mode draws the scene once (uFFI generates its callouts, the fonts are made) and once more counted (the FFI callouts by cairo function and by calling method, the plugin's cairo calls and primitive calls) and fingerprinted (the pixels);
3. then N repetitions, the modes in a rotating order (`ffi basic all`, `basic all ffi`, `all ffi basic`, ...), each run after a mode switch, an untimed warm-up run and a garbage collection.

## The output

I print a line per scene, size and mode:

```text
BENCH <pharo> <vm> cairo=<x.y.z> <scene> <size> <mode>
  median_ms=<f> best_ms=<f> spread_ms=<f> ffi=<n> prims=<n> cairo=<n>
  sha=<12 hex> drift_ms=<f> runs=<N> calls=<n>
  [PIXELS-DIFFER] [CALLS-DIFFER] [FALLBACK <what>=<n> ...]
```

where

- `spread` is max - min of the runs (the noise figure of `#ffi`),
- `drift` the median of the first half of the runs minus that of the second half,
- `ffi` the FFI callouts,
- `prims` the plugin's primitive calls,
- `cairo` the plugin's cairo calls,
- `calls` the cairo calls of both but the `*_destroy` ones (finalization),
- `sha` the fingerprint of the pixels (the first 12 hex digits of the SHA-256 of the CRC-32s of the 64 KiB chunks of the surface bytes: a full SHA-256 takes seconds per surface in Smalltalk, minutes on the WebAssembly VMs).

The flags:

- `PIXELS-DIFFER`: the fingerprint differs from `#ffi`'s;
- `CALLS-DIFFER`: the calls of a cairo function (FFI callouts plus the plugin's calls, without the `*_destroy` ones) differ from `#ffi`'s, followed by the functions that differ (`'cairo_fill=3/2'`, at most 5);
- `FALLBACK`: in a plugin mode, an ffi copy of a patched method made callouts, or a cairo function that an installed group covers (`CairoPluginInstaller coveredFunctions`) was called through the FFI: a primitive failed and its method fell back.

The three count as failures (`runOn:` answers their number). A line `CALLS` lists the calls by function, and `MICRO`, `COND` and `SKIP` lines give the micro-benchmarks, the conditions and what was not run.

## The parameters

The parameters come from the environment (`fromEnvironment`):

- `CP_BENCH_SCENES` (names separated by commas, default all and `micro`);
- `CP_BENCH_SIZES` (1000,1);
- `CP_BENCH_REPS` (7);
- `CP_BENCH_SCALE` (1: the counts of `bench.st`);
- `CP_BENCH_ROASSAL_SCALE` (1, for f, g and h);
- `CP_BENCH_MODES` (`ffi,basic,all`; only `ffi` on a VM without the plugin);
- `CP_BENCH_MICRO_CALLS` (200000);
- `CP_BENCH_VM` (the name of the VM in the lines: `native-cog`, `wasm-node` or `wasm-web`).

At the end the groups installed, wanted and the binding are restored.
"
Class {
	#name : 'CairoPluginBenchmark',
	#superclass : 'Object',
	#instVars : [
		'out',
		'vmName',
		'pharoMajor',
		'cairoVersion',
		'sceneNames',
		'sizes',
		'reps',
		'modes',
		'scale',
		'roassalScale',
		'microCalls',
		'failures',
		'scenesBySize',
		'roassalBySize'
	],
	#classInstVars : [
		'stubbedOriginal',
		'stubMethod',
		'voidType'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Benchmarks',
	#package : 'VM-Plugins-Primitives-Cairo-Benchmarks'
}

{ #category : 'accessing' }
CairoPluginBenchmark class >> allSceneNames [

	^ #( 'a-polyline' 'a2-lines' 'b-rects' 'c-bezier' 'd-transforms' 'e-text' 'e-text-wide' 'e-text-long'
	     'f-roassal-first' 'f-roassal-cached' 'g-roassal-svg-first' 'g-roassal-svg-cached' 'h-morph-frame' 'micro' )
]

{ #category : 'instance creation' }
CairoPluginBenchmark class >> fromEnvironment [
	"A benchmark with the parameters of the environment (see the class comment)"

	| env list |
	env := OSEnvironment current.
	list := [ :key :default |
	        | items |
	        items := (env at: key ifAbsent: [ '' ]) substrings: ', '.
	        items isEmpty
		        ifTrue: [ default ]
		        ifFalse: [ items asArray ] ].
	^ self new
		  sceneNames: (list value: 'CP_BENCH_SCENES' value: self allSceneNames);
		  sizes: ((list value: 'CP_BENCH_SIZES' value: #( '1000' '1' )) collect: [ :each | each asNumber ]);
		  reps: (env at: 'CP_BENCH_REPS' ifAbsent: [ '7' ]) asNumber;
		  scale: (env at: 'CP_BENCH_SCALE' ifAbsent: [ '1' ]) asNumber;
		  roassalScale: (env at: 'CP_BENCH_ROASSAL_SCALE' ifAbsent: [ '1' ]) asNumber;
		  modes: ((list value: 'CP_BENCH_MODES' value: #( 'ffi' 'basic' 'all' )) collect: [ :each | each asSymbol ]);
		  microCalls: (env at: 'CP_BENCH_MICRO_CALLS' ifAbsent: [ '200000' ]) asNumber;
		  vmName: (env at: 'CP_BENCH_VM' ifAbsent: [ self defaultVMName ]);
		  yourself
]

{ #category : 'accessing' }
CairoPluginBenchmark class >> defaultVMName [

	^ (CairoPlugin info notNil and: [ (CairoPlugin info at: 3) = 'emscripten' ])
		  ifTrue: [ 'wasm-node' ]
		  ifFalse: [ 'native-cog' ]
]

{ #category : 'micro' }
CairoPluginBenchmark class >> primDirectoryDelimitor [
	"The FilePlugin's primitive that answers the directory delimiter: a named primitive that does nothing (the control of the cost of a named primitive's call)"

	<primitive: 'primitiveDirectoryDelimitor' module: 'FilePlugin'>
	^ nil
]

{ #category : 'void stub' }
CairoPluginBenchmark class >> installVoidStub [
	"Make the FFI skip every void callout (the C call), so that a timing measures the Smalltalk side of the callouts only: the void-stub control of the benchmark. Put in quietly (no announcement, nothing logged); removeVoidStub takes it out"

	| proto current |
	current := TFSameThreadRunner compiledMethodAt: #invokeFunction:withArguments:.
	current == stubMethod ifTrue: [ ^ self ].
	stubbedOriginal := current.
	voidType := TFBasicType void.
	proto := TFSameThreadRunner protocolNameOfSelector: #invokeFunction:withArguments:.
	CairoPluginInstaller quietly: [
		stubMethod
			ifNil: [
				TFSameThreadRunner
					compile: 'invokeFunction: function withArguments: aCollection
	"Installed by CairoPluginBenchmark class>>#installVoidStub while it measures the Smalltalk side of the void callouts (benchmark only)"

	function definition returnType == CairoPluginBenchmark voidType ifTrue: [ ^ nil ].
	^ CairoPluginBenchmark runner: self invoke: function withArguments: aCollection'
					classified: proto
					withStamp: nil
					notifying: nil
					logSource: false.
				stubMethod := TFSameThreadRunner compiledMethodAt: #invokeFunction:withArguments: ]
			ifNotNil: [
				CairoPluginInstaller
					put: stubMethod
					in: TFSameThreadRunner
					at: #invokeFunction:withArguments:
					protocol: proto ] ]
]

{ #category : 'void stub' }
CairoPluginBenchmark class >> removeVoidStub [

	| current |
	current := TFSameThreadRunner compiledMethodAt: #invokeFunction:withArguments:.
	(stubMethod notNil and: [ current == stubMethod and: [ stubbedOriginal notNil ] ]) ifFalse: [ ^ self ].
	CairoPluginInstaller quietly: [
		CairoPluginInstaller
			put: stubbedOriginal
			in: TFSameThreadRunner
			at: #invokeFunction:withArguments:
			protocol: (TFSameThreadRunner protocolNameOfSelector: #invokeFunction:withArguments:) ]
]

{ #category : 'void stub' }
CairoPluginBenchmark class >> runner: aRunner invoke: aFunction withArguments: aCollection [
	"The stub's call of a function that is not void: the original method"

	^ stubbedOriginal valueWithReceiver: aRunner arguments: {
			  aFunction.
			  aCollection }
]

{ #category : 'void stub' }
CairoPluginBenchmark class >> voidType [

	^ voidType
]

{ #category : 'scenes' }
CairoPluginBenchmark >> benchmarkScene: aName size: n [
	"Check, then time, the scene aName at the size n in every mode; print its lines"

	| scene checks times |
	scene := self sceneNamed: aName size: n.
	scene ifNil: [ ^ self ].
	checks := Dictionary new.
	modes do: [ :mode |
		self setMode: mode.
		scene warm.
		Smalltalk garbageCollect.
		checks at: mode put: (self check: scene) ].
	times := Dictionary new.
	modes do: [ :mode | times at: mode put: OrderedCollection new ].
	1 to: reps do: [ :r |
		(self rotation: r) do: [ :mode |
			| t0 t1 |
			self setMode: mode.
			scene warm.
			scene before.
			Smalltalk garbageCollect.
			t0 := Time primUTCMicrosecondsClock.
			scene run.
			t1 := Time primUTCMicrosecondsClock.
			(times at: mode) add: t1 - t0 / 1000.0 ] ].
	modes do: [ :mode |
		self
			printScene: scene
			mode: mode
			times: (times at: mode)
			checks: checks ]
]

{ #category : 'micro' }
CairoPluginBenchmark >> benchmarkMicro [
	"Time the micro-benchmarks on a surface of 1 x 1 in every mode (rotating order, as the scenes), and the controls; print the MICRO lines"

	| surface results rect controls |
	results := Dictionary new.
	rect := 0 @ 0 extent: 1 @ 1.
	surface := AthensCairoSurface extent: 1 @ 1.
	surface drawDuring: [ :c |
		c setFont: (LogicalFont familyName: 'Source Sans Pro' pointSize: 10).
		1 to: reps do: [ :r |
			(self rotation: r) do: [ :mode |
				self setMode: mode.
				c setPaint: Color black.
				(self micros: rect) do: [ :micro |
					self
						time: micro
						on: c
						as: mode
						into: results ].
				mode = modes first ifTrue: [
					controls := self controlsFor: mode.
					controls do: [ :micro |
						self
							time: micro
							on: c
							as: (micro at: 4)
							into: results ] ] ] ] ].
	((self micros: rect) , (controls ifNil: [ #(  ) ])) do: [ :micro |
		| name k |
		name := micro first.
		k := self callsOf: micro.
		(results at: name ifAbsent: [ Dictionary new ]) keysAndValuesDo: [ :mode :all |
			out
				nextPutAll: 'MICRO ';
				nextPutAll: pharoMajor printString;
				nextPutAll: ' ';
				nextPutAll: vmName;
				nextPutAll: ' ';
				nextPutAll: name;
				nextPutAll: ' ';
				nextPutAll: mode;
				nextPutAll: ' ns=';
				nextPutAll: ((self median: all) printShowingDecimalPlaces: 1);
				nextPutAll: ' best_ns=';
				nextPutAll: ((all inject: all first into: [ :a :b | a min: b ]) printShowingDecimalPlaces: 1);
				nextPutAll: ' calls=';
				nextPutAll: k printString;
				nextPutAll: ' runs=';
				nextPutAll: all size printString;
				lf ] ].
	out flush
]

{ #category : 'micro' }
CairoPluginBenchmark >> callsOf: aMicro [

	^ microCalls // (aMicro at: 2) max: 1
]

{ #category : 'scenes' }
CairoPluginBenchmark >> check: aScene [
	"An untimed run of aScene in the current mode: { FFI callouts by function (Bag). by calling method (Bag). the plugin's cairo calls (Dictionary). its primitive calls (Dictionary). the fingerprint of the pixels. the ffi copies of the installed patches (Set). the cairo functions the installed groups cover (Set) }"

	| result bags counters prims fingerprint plugin |
	plugin := CairoPlugin isAvailable.
	aScene before.
	plugin ifTrue: [ CairoPlugin resetCounters ].
	bags := CairoPluginTestSupport ffiCallsDuring: [ result := aScene run ].
	counters := plugin
		            ifTrue: [ CairoPlugin counters ]
		            ifFalse: [ Dictionary new ].
	prims := plugin
		         ifTrue: [ CairoPluginTestSupport drawingPrimitiveCounters ]
		         ifFalse: [ Dictionary new ].
	fingerprint := self fingerprintOf: (aScene bytesOf: result).
	^ {
		  bags first.
		  bags last.
		  counters.
		  prims.
		  fingerprint.
		  self ffiCopyNames.
		  self coveredFunctions }
]

{ #category : 'micro' }
CairoPluginBenchmark >> controlsFor: aMode [
	"The controls: { name. divisor of the calls. block. the mode printed. optionally { what to do before. what to do after } }"

	| controls |
	controls := OrderedCollection new.
	controls add: {
			'ctl-loop'.
			1.
			[ :c :k | 1 to: k do: [ :i | c yourself ] ].
			#smalltalk }.
	aMode = #ffi ifTrue: [
		controls add: {
				'ctl-void-stub-newPath'.
				1.
				[ :c :k | 1 to: k do: [ :i | c newPath ] ].
				#ffi.
				{
					[ self class installVoidStub ].
					[ self class removeVoidStub ] } } ].
	controls add: {
			'ctl-empty-ffi-cairo_version'.
			1.
			[ :c :k | 1 to: k do: [ :i | CairoPluginTestSupport cairoVersion ] ].
			#ffi }.
	"a named primitive that does nothing but answer a constant (FilePlugin's directory delimiter: a Character, no allocation), the cost of the call of any named primitive; every VM has the FilePlugin"
	controls add: {
			'ctl-empty-prim-FilePlugin-delimitor'.
			1.
			[ :c :k | 1 to: k do: [ :i | self class primDirectoryDelimitor ] ].
			#plugin }.
	^ controls asArray
]

{ #category : 'checks' }
CairoPluginBenchmark >> coveredFunctions [
	"The cairo functions that the installed groups call through the plugin"

	| covered table |
	covered := Set new.
	table := CairoPluginInstaller coveredFunctions.
	CairoPlugin installedGroups do: [ :g | covered addAll: (table at: g ifAbsent: [ #(  ) ]) ].
	^ covered
]

{ #category : 'checks' }
CairoPluginBenchmark >> ffiCopyNames [
	"The ffi copies of the installed patches, as the counting hook names their callers ('AthensCairoCanvas>>ffiNewPath')"

	| names |
	names := Set new.
	CairoPluginInstaller records do: [ :recs |
		recs do: [ :r |
			names add: r targetClassName , (r isMeta
					  ifTrue: [ ' class' ]
					  ifFalse: [ '' ]) , '>>' , r ffiSelector ] ].
	^ names
]

{ #category : 'checks' }
CairoPluginBenchmark >> fingerprintOf: aByteArray [
	"The first 12 hex digits of the SHA-256 of the size and of the CRC-32 of each 64 KiB chunk of aByteArray"

	| chunk crcs i |
	chunk := 65536.
	crcs := WriteStream on: (ByteArray new: aByteArray size // chunk + 2 * 4).
	self put32: aByteArray size on: crcs.
	i := 1.
	[ i <= aByteArray size ] whileTrue: [
		| j |
		j := i + chunk - 1 min: aByteArray size.
		self
			put32: ((ZipWriteStream updateCrc: 16rFFFFFFFF from: i to: j in: aByteArray) bitXor: 16rFFFFFFFF)
			on: crcs.
		i := j + 1 ].
	^ (SHA256 hashMessage: crcs contents) hex first: 12
]

{ #category : 'scenes' }
CairoPluginBenchmark >> hasWebWindows [
	"The image has the methods of OSWindow-Web with which a surface makes its Form without the SurfacePlugin (image/web of a WebAssembly build, or a stock image into which tests/web-surface.st put them, in *OSWindow-Web): the WebAssembly VMs have no SurfacePlugin"

	^ PackageOrganizer default packageNames anySatisfy: [ :each | each asString = 'OSWindow-Web' ]
]

{ #category : 'scenes' }
CairoPluginBenchmark >> hostedRoassalCanvas: someScenes [
	"The Roassal graph of someScenes in a morph of 1000 x 1000, zoomed to fit (as bench.st): with a host, RSAthensRenderer draws the shapes of the dirty rectangle (without one it draws none)"

	| cv |
	cv := someScenes roassalCanvas.
	cv createMorph extent: 1000 @ 1000.
	cv zoomToFit.
	^ cv
]

{ #category : 'micro' }
CairoPluginBenchmark >> micros: aRectangle [
	"The micro-benchmarks: { name. divisor of the calls. block taking the canvas and the number of calls }"

	^ {
		  {
			  'newPath'.
			  1.
			  [ :c :k | 1 to: k do: [ :i | c newPath ] ] }.
		  {
			  'moveToX:Y:'.
			  1.
			  [ :c :k | c createPath: [ :b | 1 to: k do: [ :i | b moveToX: 1.0 Y: 2.0 ] ] ] }.
		  {
			  'primRectangleX:y:width:height:'.
			  1.
			  [ :c :k |
			  1 to: k do: [ :i |
				  c primRectangleX: 1.0 y: 2.0 width: 3.0 height: 4.0.
				  i \\ 1000 = 0 ifTrue: [ c newPath ] ].
			  c newPath ] }.
		  {
			  'primSetSourceR:g:b:a:'.
			  1.
			  [ :c :k | 1 to: k do: [ :i | c primSetSourceR: 0.1 g: 0.2 b: 0.3 a: 1.0 ] ] }.
		  {
			  'setPathMatrix'.
			  1.
			  [ :c :k | 1 to: k do: [ :i | c setPathMatrix ] ] }.
		  {
			  'fill-empty'.
			  1.
			  [ :c :k |
			  c newPath.
			  1 to: k do: [ :i | c fill ] ] }.
		  {
			  'setPaint:+drawShape:'.
			  10.
			  [ :c :k |
			  1 to: k do: [ :i |
				  c
					  setPaint: Color red;
					  drawShape: aRectangle ] ] }.
		  {
			  'drawString:'.
			  10.
			  [ :c :k |
			  c setPaint: Color black.
			  1 to: k do: [ :i | c drawString: 'node 123' ] ] } }
]

{ #category : 'accessing' }
CairoPluginBenchmark >> microCalls: anInteger [

	microCalls := anInteger
]

{ #category : 'checks' }
CairoPluginBenchmark >> isCompared: aFunctionName [
	"The cairo calls that must be the same in every mode: the *_destroy ones depend on when finalization runs"

	^ (aFunctionName beginsWith: 'cairo_') and: [ (aFunctionName endsWith: '_destroy') not ]
]

{ #category : 'statistics' }
CairoPluginBenchmark >> median: someNumbers [

	| sorted n |
	sorted := someNumbers asSortedCollection asArray.
	n := sorted size.
	^ n odd
		  ifTrue: [ sorted at: n + 1 // 2 ]
		  ifFalse: [ (sorted at: n // 2) + (sorted at: n // 2 + 1) / 2.0 ]
]

{ #category : 'accessing' }
CairoPluginBenchmark >> modes: someSymbols [

	modes := someSymbols
]

{ #category : 'printing' }
CairoPluginBenchmark >> print: aString value: anObject [
	"A line COND <pharo> <vm> aString anObject"

	out
		nextPutAll: 'COND ';
		nextPutAll: pharoMajor printString;
		nextPutAll: ' ';
		nextPutAll: vmName;
		nextPutAll: ' ';
		nextPutAll: aString;
		nextPutAll: ' ';
		nextPutAll: ((anObject isString
				  ifTrue: [ anObject ]
				  ifFalse: [ anObject printString ]) copyReplaceAll: String lf with: ' ');
		lf;
		flush
]

{ #category : 'printing' }
CairoPluginBenchmark >> printBag: aBag plus: aDictionary [
	"f=n,... sorted by function"

	| d |
	d := Dictionary new.
	aBag asSet do: [ :f | d at: f put: (aBag occurrencesOf: f) ].
	aDictionary keysAndValuesDo: [ :f :n | n > 0 ifTrue: [ d at: f put: (d at: f ifAbsent: [ 0 ]) + n ] ].
	d isEmpty ifTrue: [ ^ '-' ].
	^ String streamContents: [ :s |
		  d keys asSortedCollection
			  do: [ :f |
				  s
					  nextPutAll: f;
					  nextPut: $=;
					  print: (d at: f) ]
			  separatedBy: [ s nextPut: $, ] ]
]

{ #category : 'printing' }
CairoPluginBenchmark >> printConditions [

	| vm |
	self print: 'image' value: SystemVersion current printString.
	vm := Smalltalk vm version.
	self print: 'vm' value: (vm copyReplaceAll: String cr with: ' ').
	self print: 'cairo' value: cairoVersion.
	self print: 'plugin' value: CairoPlugin info.
	self print: 'modes' value: modes.
	self print: 'sizes' value: sizes.
	self print: 'reps' value: reps.
	self print: 'scale' value: scale.
	self print: 'roassal-scale' value: roassalScale.
	self print: 'micro-calls' value: microCalls.
	self print: 'scenes' value: sceneNames.
	self print: 'fingerprint' value: 'sha = SHA-256 of the CRC-32 of each 64 KiB of the pixels (12 hex digits)'
]

{ #category : 'printing' }
CairoPluginBenchmark >> printScene: aScene mode: aMode times: someTimes checks: checks [

	| c reference sorted functions callers counters prims calls flags fallbacks half drift |
	c := checks at: aMode.
	reference := checks at: modes first.
	sorted := someTimes asSortedCollection asArray.
	functions := c at: 1.
	callers := c at: 2.
	counters := c at: 3.
	prims := c at: 4.
	calls := [ :check | (self callsByFunction: check) inject: 0 into: [ :sum :a | sum + a value ] ].
	half := someTimes size // 2.
	drift := half = 0
		         ifTrue: [ 0.0 ]
		         ifFalse: [ (self median: (someTimes first: half)) - (self median: (someTimes last: half)) ].
	flags := OrderedCollection new.
	(c at: 5) = (reference at: 5) ifFalse: [
		flags add: 'PIXELS-DIFFER'.
		failures := failures + 1 ].
	"the calls of each cairo function (FFI callouts plus the plugin's calls), not only their total"
	(self callsByFunction: c) = (self callsByFunction: reference) ifFalse: [
		flags add: 'CALLS-DIFFER'.
		flags addAll: (self callsDifferenceOf: c from: reference).
		failures := failures + 1 ].
	aMode = #ffi ifFalse: [
		fallbacks := OrderedCollection new.
		(functions asSet select: [ :f | (c at: 7) includes: f ]) asSortedCollection do: [ :f |
			fallbacks add: f , '=' , (functions occurrencesOf: f) printString ].
		(callers asSet select: [ :m | (c at: 6) includes: m ]) asSortedCollection do: [ :m |
			fallbacks add: m , '=' , (callers occurrencesOf: m) printString ].
		fallbacks isEmpty ifFalse: [
			flags add: 'FALLBACK'.
			flags addAll: fallbacks.
			failures := failures + 1 ] ].
	out
		nextPutAll: 'BENCH ';
		nextPutAll: pharoMajor printString;
		nextPutAll: ' ';
		nextPutAll: vmName;
		nextPutAll: ' cairo=';
		nextPutAll: cairoVersion;
		nextPutAll: ' ';
		nextPutAll: aScene name;
		nextPutAll: ' ';
		nextPutAll: aScene surfaceSize printString;
		nextPutAll: ' ';
		nextPutAll: aMode;
		nextPutAll: ' median_ms=';
		nextPutAll: ((self median: someTimes) printShowingDecimalPlaces: 3);
		nextPutAll: ' best_ms=';
		nextPutAll: (sorted first printShowingDecimalPlaces: 3);
		nextPutAll: ' spread_ms=';
		nextPutAll: (sorted last - sorted first printShowingDecimalPlaces: 3);
		nextPutAll: ' ffi=';
		nextPutAll: functions size printString;
		nextPutAll: ' prims=';
		nextPutAll: (prims inject: 0 into: [ :a :b | a + b ]) printString;
		nextPutAll: ' cairo=';
		nextPutAll: (counters inject: 0 into: [ :a :b | a + b ]) printString;
		nextPutAll: ' sha=';
		nextPutAll: (c at: 5);
		nextPutAll: ' drift_ms=';
		nextPutAll: (drift printShowingDecimalPlaces: 3);
		nextPutAll: ' runs=';
		nextPutAll: someTimes size printString;
		nextPutAll: ' calls=';
		nextPutAll: (calls value: c) printString.
	flags do: [ :each |
		out
			nextPutAll: ' ';
			nextPutAll: each ].
	out lf.
	out
		nextPutAll: 'CALLS ';
		nextPutAll: pharoMajor printString;
		nextPutAll: ' ';
		nextPutAll: vmName;
		nextPutAll: ' ';
		nextPutAll: aScene name;
		nextPutAll: ' ';
		nextPutAll: aScene surfaceSize printString;
		nextPutAll: ' ';
		nextPutAll: aMode;
		nextPutAll: ' ffi:';
		nextPutAll: (self printBag: functions plus: Dictionary new);
		nextPutAll: ' plugin:';
		nextPutAll: (self printBag: Bag new plus: counters);
		nextPutAll: ' times:';
		nextPutAll: (String streamContents: [ :s |
					 someTimes
						 do: [ :t | s nextPutAll: (t printShowingDecimalPlaces: 3) ]
						 separatedBy: [ s nextPut: $, ] ]);
		lf;
		flush
]

{ #category : 'checks' }
CairoPluginBenchmark >> callsByFunction: aCheck [
	"The compared cairo calls of aCheck (the FFI callouts, a Bag, plus the plugin's calls, a Dictionary), by function: a sorted Array of name -> count"

	| counts |
	counts := Dictionary new.
	(aCheck at: 1) do: [ :f |
		(self isCompared: f) ifTrue: [ counts at: f put: (counts at: f ifAbsent: [ 0 ]) + 1 ] ].
	(aCheck at: 3) keysAndValuesDo: [ :f :n |
		((self isCompared: f) and: [ n > 0 ]) ifTrue: [ counts at: f put: (counts at: f ifAbsent: [ 0 ]) + n ] ].
	^ (counts associations asSortedCollection: [ :a :b | a key <= b key ]) asArray
]

{ #category : 'checks' }
CairoPluginBenchmark >> callsDifferenceOf: aCheck from: aReference [
	"The functions whose calls differ, as flags 'name=n/reference' (at most 5)"

	| mine theirs names |
	mine := Dictionary newFrom: (self callsByFunction: aCheck).
	theirs := Dictionary newFrom: (self callsByFunction: aReference).
	names := (mine keys asSet , theirs keys asSet) asSortedCollection select: [ :f |
		         (mine at: f ifAbsent: [ 0 ]) ~= (theirs at: f ifAbsent: [ 0 ]) ].
	^ (names asArray first: (names size min: 5)) collect: [ :f |
		  f , '=' , (mine at: f ifAbsent: [ 0 ]) printString , '/' , (theirs at: f ifAbsent: [ 0 ]) printString ]
]

{ #category : 'printing' }
CairoPluginBenchmark >> printSkip: aName size: n reason: aString [

	out
		nextPutAll: 'SKIP ';
		nextPutAll: pharoMajor printString;
		nextPutAll: ' ';
		nextPutAll: vmName;
		nextPutAll: ' ';
		nextPutAll: aName;
		nextPutAll: ' ';
		nextPutAll: n printString;
		nextPutAll: ' ';
		nextPutAll: aString;
		lf;
		flush
]

{ #category : 'checks' }
CairoPluginBenchmark >> put32: anInteger on: aStream [

	aStream
		nextPut: (anInteger bitShift: -24) \\ 256;
		nextPut: (anInteger bitShift: -16) \\ 256;
		nextPut: (anInteger bitShift: -8) \\ 256;
		nextPut: anInteger \\ 256
]

{ #category : 'accessing' }
CairoPluginBenchmark >> reps: anInteger [

	reps := anInteger
]

{ #category : 'state' }
CairoPluginBenchmark >> restoreState: aState [
	"Put back the groups installed and wanted and the binding of before the run"

	CairoPluginInstaller uninstall: CairoPlugin groups.
	(aState at: 3)
		ifTrue: [ CairoPlugin isBound ifFalse: [ [ CairoPlugin bind ] on: CairoPluginError do: [ :e | ] ] ]
		ifFalse: [ CairoPlugin isBound ifTrue: [ CairoPlugin unbind ] ].
	(aState at: 1) isEmpty ifFalse: [ CairoPluginInstaller install: (aState at: 1) force: CairoPlugin isBound not ].
	CairoPluginInstaller wantedGroups: (aState at: 2)
]

{ #category : 'accessing' }
CairoPluginBenchmark >> roassalScale: aNumber [

	roassalScale := aNumber
]

{ #category : 'scenes' }
CairoPluginBenchmark >> roassalScenesAt: n [

	^ roassalBySize at: n ifAbsentPut: [ CairoPluginScenes scale: roassalScale size: n ]
]

{ #category : 'scenes' }
CairoPluginBenchmark >> rotation: r [
	"The modes in the order of the repetition r: each one first in turn"

	^ (1 to: modes size) collect: [ :i | modes at: i + r - 2 \\ modes size + 1 ]
]

{ #category : 'running' }
CairoPluginBenchmark >> runOn: aStream [
	"Run the benchmark, print its lines on aStream; answer the number of failures (pixels that differ, fallbacks, errors)"

	| state |
	out := aStream.
	failures := 0.
	scenesBySize := Dictionary new.
	roassalBySize := Dictionary new.
	pharoMajor := SystemVersion current major.
	cairoVersion := CairoLibrary uniqueInstance versionString.
	state := {
		         CairoPlugin installedGroups copy.
		         CairoPlugin wantedGroups copy.
		         CairoPlugin isBound }.
	[
	self selectModes.
	self printConditions.
	sizes do: [ :n |
		sceneNames do: [ :each |
			each = 'micro' ifFalse: [
				[ self benchmarkScene: each size: n ]
					on: Error
					do: [ :e | self printError: e scene: each size: n ] ] ] ].
	(sceneNames includes: 'micro') ifTrue: [
		[ self benchmarkMicro ]
			on: Error
			do: [ :e | self printError: e scene: 'micro' size: 1 ] ] ] ensure: [
		self class removeVoidStub.
		self restoreState: state ].
	out flush.
	^ failures
]

{ #category : 'printing' }
CairoPluginBenchmark >> printError: anError scene: aName size: n [

	failures := failures + 1.
	out
		nextPutAll: 'ERROR ';
		nextPutAll: pharoMajor printString;
		nextPutAll: ' ';
		nextPutAll: vmName;
		nextPutAll: ' ';
		nextPutAll: aName;
		nextPutAll: ' ';
		nextPutAll: n printString;
		nextPutAll: ' ';
		nextPutAll: anError class name;
		nextPutAll: ': ';
		nextPutAll: (anError messageText ifNil: [ anError description ]) asString;
		lf;
		flush
]

{ #category : 'accessing' }
CairoPluginBenchmark >> scale: aNumber [

	scale := aNumber
]

{ #category : 'scenes' }
CairoPluginBenchmark >> sceneNamed: aName size: n [
	"The scene aName at the size n, or nil when it has no meaning at that size (an SVG surface, the frame of 800 x 600 at another size than 1000) or cannot run here (a SKIP line says why)"

	| s r |
	s := self scenesAt: n.
	(#( 'a-polyline' 'a2-lines' 'b-rects' 'c-bezier' 'd-transforms' 'e-text' ) includes: aName) ifTrue: [
		| block |
		block := (s benchScenes detect: [ :each | each key = aName ]) value.
		^ CairoPluginBenchmarkScene name: aName size: n run: [ s run: block ] ].
	aName = 'e-text-wide' ifTrue: [
		| wide |
		wide := s wideStrings.
		^ CairoPluginBenchmarkScene name: aName size: n run: [ s run: [ :c | s drawStrings: wide on: c ] ] ].
	aName = 'e-text-long' ifTrue: [
		| long |
		"(the strings of CairoPluginScenes>>#longStrings ten times: 500 strings of 2000 characters at scale 1, 50 at scale 0.1, so that a run takes long enough for the clock of the WebAssembly VMs)"
		long := (1 to: 10) inject: #(  ) into: [ :all :k | all , s longStrings ].
		^ CairoPluginBenchmarkScene name: aName size: n run: [ s run: [ :c | s drawLongStrings: long on: c ] ] ].
	(aName beginsWith: 'f-roassal-') ifTrue: [
		| cv first |
		r := self roassalScenesAt: n.
		cv := self hostedRoassalCanvas: r.
		first := aName = 'f-roassal-first'.
		^ (CairoPluginBenchmarkScene name: aName size: n run: [ r run: [ :c | r renderRoassal: cv on: c ] ])
			  beforeBlock: [
				  first ifTrue: [ cv shapes do: [ :each | each resetPath ] ].
				  cv
					  extent: 1000 @ 1000;
					  invalidate ];
			  yourself ].
	(aName beginsWith: 'g-roassal-svg-') ifTrue: [
		| cv first file |
		n = 1000 ifFalse: [ ^ nil ].
		r := self roassalScenesAt: n.
		cv := self hostedRoassalCanvas: r.
		first := aName = 'g-roassal-svg-first'.
		file := (FileLocator imageDirectory / 'cairo-bench.svg') fullName.
		^ (CairoPluginBenchmarkScene name: aName size: n run: [
			   | svg |
			   svg := AthensCairoSVGSurface extent: 1000 @ 1000 fileName: file.
			   [ svg drawDuring: [ :c | r renderRoassal: cv on: c ] ] ensure: [ svg close ].
			   file ])
			  beforeBlock: [
				  first ifTrue: [ cv shapes do: [ :each | each resetPath ] ].
				  cv
					  extent: 1000 @ 1000;
					  invalidate ];
			  bytesBlock: [ :f | self svgBytesOf: f ];
			  yourself ].
	aName = 'h-morph-frame' ifTrue: [
		| cv morph canvas |
		n = 1000 ifFalse: [ ^ nil ].
		(vmName beginsWith: 'wasm') & self hasWebWindows not ifTrue: [
			self printSkip: aName size: 800 reason: 'no OSWindow-Web methods in this image (no SurfacePlugin on WebAssembly): run it on image/web, or file in tests/web-surface.st'.
			^ nil ].
		r := self roassalScenesAt: n.
		cv := r roassalCanvas.
		morph := cv createMorph.
		morph
			extent: 800 @ 600;
			position: 0 @ 0.
		cv zoomToFit.
		canvas := FormCanvas extent: 800 @ 600.
		^ (CairoPluginBenchmarkScene name: aName size: 800 run: [
			   morph fullDrawOn: canvas.
			   canvas form ])
			  beforeBlock: [ cv invalidate ];
			  bytesBlock: [ :form | form bits asByteArray ];
			  yourself ].
	self printSkip: aName size: n reason: 'no such scene'.
	^ nil
]

{ #category : 'accessing' }
CairoPluginBenchmark >> sceneNames: someStrings [

	sceneNames := someStrings
]

{ #category : 'scenes' }
CairoPluginBenchmark >> scenesAt: n [

	^ scenesBySize at: n ifAbsentPut: [ CairoPluginScenes scale: scale size: n ]
]

{ #category : 'modes' }
CairoPluginBenchmark >> selectModes [
	"Keep the modes this VM can run: #ffi only without the plugin, or when the bound plugin lacks a group (a SKIP line says why)"

	| implemented kept |
	CairoPlugin isAvailable ifTrue: [
		CairoPlugin isBound ifFalse: [ [ CairoPlugin bind ] on: CairoPluginError do: [ :e | ] ] ].
	implemented := CairoPluginTestSupport implementedGroups.
	kept := modes select: [ :mode |
		        | needed ok |
		        needed := mode = #ffi
			                  ifTrue: [ #(  ) ]
			                  ifFalse: [
				                  mode = #basic
					                  ifTrue: [ #( #basic ) ]
					                  ifFalse: [ CairoPlugin groups ] ].
		        ok := needed allSatisfy: [ :g | implemented includes: g ].
		        ok ifFalse: [
			        self
				        printSkip: 'mode-' , mode
				        size: 0
				        reason: (CairoPlugin isAvailable
						         ifTrue: [ 'the plugin implements ' , implemented printString ]
						         ifFalse: [ 'the VM has no CairoPlugin' ]) ].
		        ok ].
	modes := kept asArray
]

{ #category : 'modes' }
CairoPluginBenchmark >> setMode: aMode [

	| installed expected |
	installed := CairoPluginTestSupport setMode: aMode.
	expected := aMode = #ffi
		            ifTrue: [ #(  ) ]
		            ifFalse: [
			            aMode = #basic
				            ifTrue: [ #( #basic ) ]
				            ifFalse: [ CairoPlugin groups ] ].
	installed asArray = expected asArray ifFalse: [
		self error: 'mode ' , aMode , ' installed ' , installed printString , ' ' , CairoPlugin lastReport printString ]
]

{ #category : 'accessing' }
CairoPluginBenchmark >> sizes: someIntegers [

	sizes := someIntegers
]

{ #category : 'scenes' }
CairoPluginBenchmark >> svgBytesOf: aFileName [
	"The bytes of the SVG file, its surface numbers (cairo counts the surfaces of the process) taken out"

	| svg |
	svg := aFileName asFileReference contents.
	svg := svg copyWithRegex: 'surface[0-9]+' matchesReplacedWith: 'surface'.
	^ svg asByteArray
]

{ #category : 'micro' }
CairoPluginBenchmark >> time: aMicro on: aCanvas as: aMode into: results [
	"Time aMicro (after a warm-up of a hundredth of its calls); record its ns per call in results at: name at: aMode"

	| k block t0 t1 around |
	k := self callsOf: aMicro.
	block := aMicro at: 3.
	"(a control may put something in before and take it out after: outside the timing)"
	around := aMicro size >= 5
		          ifTrue: [ aMicro at: 5 ]
		          ifFalse: [ { [  ]. [  ] } ].
	around first value.
	[
	block value: aCanvas value: (k // 100 max: 1).
	Smalltalk garbageCollectMost.
	t0 := Time primUTCMicrosecondsClock.
	block value: aCanvas value: k.
	t1 := Time primUTCMicrosecondsClock ] ensure: [ around last value ].
	((results at: aMicro first ifAbsentPut: [ Dictionary new ]) at: aMode ifAbsentPut: [ OrderedCollection new ])
		add: t1 - t0 * 1000.0 / k
]

{ #category : 'accessing' }
CairoPluginBenchmark >> vmName: aString [

	vmName := aString
]
