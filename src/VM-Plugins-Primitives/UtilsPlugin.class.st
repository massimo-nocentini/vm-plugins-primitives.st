"
I am the image side of the UtilsPlugin of the Pharo VM (pharo-vm: `plugins/UtilsPlugin`; `docs/UtilsPlugin.md` is the contract).

The plugin has the primitives of:

- `Float>>#times:plus:`, the fused multiply-add (C's `fma`: one rounding);
- `String>>#strtok:inclusive:`, the pieces of a string between delimiters;
- `SequenceableCollection>>#bezierPointsAt:` and my `deCasteljau:into:at:`, the points of a Bezier curve;
- `KnuthRandom`, the lagged Fibonacci generator of Knuth's TAOCP 3.6 (his `rng-double.c`);
- `SplitMix64`, Vigna's generator of 64-bit integers (his `splitmix64.c`), since version 1.1 of the plugin.

Each of them tries the plugin first and, when the VM has no UtilsPlugin or the primitive fails (an argument it does not take), answers through its Smalltalk twin in `UtilsPluginSmalltalk`, which answers the same result, bit for bit, or signals the error. So the code works on any VM, and the plugin only makes it faster.

- `UtilsPlugin isAvailable` tells whether the VM has the plugin, and `UtilsPlugin info` answers `{ protocol. version. platform }` (or nil without it).
- `UtilsPlugin pluginHidden: true` makes everything take the Smalltalk way, as on a VM without the plugin: the tests use it to check both ways (`pluginHidden: false` restores the default).
"
Class {
	#name : 'UtilsPlugin',
	#superclass : 'Object',
	#classVars : [
		'Info',
		'InfoSession',
		'PluginHidden'
	],
	#category : 'VM-Plugins-Primitives',
	#package : 'VM-Plugins-Primitives'
}

{ #category : 'Bezier curves' }
UtilsPlugin class >> deCasteljau: controlPoints into: curvePoints at: parameters [
	"Store at curvePoints at: j the point at parameters at: j of the Bezier curve of controlPoints, for j from 1 to parameters size, and answer curvePoints. controlPoints is a non-empty sequence of Points (of Numbers), parameters a sequence of Numbers, curvePoints a sequence at least as large as parameters, which may be controlPoints itself. Each new point has Float coordinates, computed by the de Casteljau scheme of UtilsPluginSmalltalk class>>#bezierPointOf:at:."

	(self usesPlugin and: [
		 (self primDeCasteljau: controlPoints into: curvePoints at: parameters) notNil ])
		ifTrue: [ ^ curvePoints ].
	^ UtilsPluginSmalltalk
		  deCasteljau: controlPoints
		  into: curvePoints
		  at: parameters
]

{ #category : 'plugin' }
UtilsPlugin class >> info [
	"Answer { protocol. 'UtilsPlugin <version>'. 'native' or 'emscripten' } when the VM has the plugin (and it is not hidden), else nil. Asked once per session."

	InfoSession == Smalltalk session ifFalse: [
		Info := self primInfo.
		InfoSession := Smalltalk session ].
	^ self usesPlugin
		  ifTrue: [ Info ]
		  ifFalse: [ nil ]
]

{ #category : 'plugin' }
UtilsPlugin class >> isAvailable [
	"Whether the VM has the UtilsPlugin, and it is not hidden"

	^ self info notNil
]

{ #category : 'Knuth generator' }
UtilsPlugin class >> newKnuthState [
	"Answer the state of a new KnuthRandom, seeded with 314159: { ByteArray of the 100 doubles of ran_u. ByteArray of the 1009 doubles of the buffer. index of its next fraction }"

	self usesPlugin ifTrue: [ self primKnuthState ifNotNil: [ :state | ^ state ] ].
	^ UtilsPluginSmalltalk newKnuthState
]

{ #category : 'primitives' }
UtilsPlugin class >> primDeCasteljau: controlPoints into: curvePoints at: parameters [
	"Answer self, or nil when the primitive failed (docs/UtilsPlugin.md)"

	<primitive: 'primitive_decasteljau' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'primitives' }
UtilsPlugin class >> primInfo [
	"Answer { protocol. version. platform }, or nil without the plugin"

	<primitive: 'primitive_info' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'primitives' }
UtilsPlugin class >> primKnuthState [
	"Answer a new state seeded with 314159, or nil when the primitive failed"

	<primitive: 'primitive_randomknuth_init' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'plugin' }
UtilsPlugin class >> pluginHidden [

	^ PluginHidden == true
]

{ #category : 'plugin' }
UtilsPlugin class >> pluginHidden: aBoolean [
	"With true, every method takes its Smalltalk way, as on a VM without the plugin (for the tests and the benchmarks)"

	PluginHidden := aBoolean
]

{ #category : 'plugin' }
UtilsPlugin class >> usesPlugin [
	"Whether the methods try the plugin first"

	^ PluginHidden ~~ true
]
