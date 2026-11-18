"
I hold what the tests (and the benchmark) of the CairoPlugin need around Athens, on my class side:

- the pixels of a surface: `bytesOf:` (a copy of the surface's bytes, which the tests compare exactly), `digestOf:` (their SHA-256, in hex), `quickDigestOf:` (their CRC-32, in hex: SHA-256 takes seconds on a surface of 1000 x 1000);
- the modes: `setMode:` puts the image in `#ffi` (nothing installed: stock Athens), `#basic` (the one-for-one primitives), `#all` (basic, shape and text) or `#fallback` (every group installed, the plugin unbound, or `forceInstall:` on a VM without the plugin: every patch runs its FFI original);
- the FFI callouts: `ffiCountsDuring:` answers the Bag of the cairo functions (C names) that the FFI called while a block ran, `ffiCallsDuring:` also the methods that made the calls ('AthensCairoCanvas>>ffiNewPath'): a hook on `TFSameThreadRunner>>#invokeFunction:withArguments:`, put in and taken out quietly (no announcement, nothing logged), around the block only;
- the cairo state of a canvas: `stateOf:` reads it through test-only FFI getters of cairo, declared with C's own types (`int` for the enums, `double *` for the out arguments: the WebAssembly FFI adapts nothing for them, and finds them in its registry of cairo symbols): the matrix (the bits of its 6 doubles), the source (the status of cairo_pattern_get_rgba and, for a solid one, its RGBA), the line width, join and cap, the dashes and their offset, whether there is a current point, the fill rule, the operator, the font matrix, the antialiasing and the scaled font;
- running a primitive of the plugin with no fallback: `primitive:receiver:arguments:` (see `CairoPluginTestPrimitives`);
- `implementedGroups`: the groups whose primitives the bound plugin really implements (the stub plugin of a partial build answers #'unsupported operation' to every drawing primitive);
- `warmUp:` draws every scene once in #ffi mode and collects the garbage, so that uFFI has generated every callout.
"
Class {
	#name : 'CairoPluginTestSupport',
	#superclass : 'Object',
	#classInstVars : [
		'originalInvoke',
		'hookMethod',
		'functionCounts',
		'callerCounts',
		'countLock'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'pixels' }
CairoPluginTestSupport class >> bytesOf: aSurface [
	"A copy of the bytes of aSurface (stride times height, cairo's premultiplied ARGB32), after a flush"

	| bytes |
	aSurface flush.
	bytes := ByteArray new: aSurface stride * aSurface privateHeight.
	LibC memCopy: aSurface getDataPtr to: bytes size: bytes size.
	^ bytes
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoAntialias: cr [

	^ self ffiCall: #(int cairo_get_antialias (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoDash: cr into: dashes offset: offset [

	^ self ffiCall: #(void cairo_get_dash (void* cr, double* dashes, double* offset))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoDashCount: cr [

	^ self ffiCall: #(int cairo_get_dash_count (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoFillRule: cr [

	^ self ffiCall: #(int cairo_get_fill_rule (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoFontMatrix: cr into: aMatrix [

	^ self ffiCall: #(void cairo_get_font_matrix (void* cr, double* aMatrix))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoHasCurrentPoint: cr [

	^ self ffiCall: #(int cairo_has_current_point (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoLineCap: cr [

	^ self ffiCall: #(int cairo_get_line_cap (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoLineJoin: cr [

	^ self ffiCall: #(int cairo_get_line_join (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoLineWidth: cr [

	^ self ffiCall: #(double cairo_get_line_width (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoMatrix: cr into: aMatrix [

	^ self ffiCall: #(void cairo_get_matrix (void* cr, double* aMatrix))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoOperator: cr [

	^ self ffiCall: #(int cairo_get_operator (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoPatternRGBA: pattern r: r g: g b: b a: a [

	^ self ffiCall: #(int cairo_pattern_get_rgba (void* pattern, double* r, double* g, double* b, double* a))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoScaledFont: cr [

	^ self ffiCall: #(void* cairo_get_scaled_font (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoSource: cr [

	^ self ffiCall: #(void* cairo_get_source (void* cr))
]

{ #category : 'state - getters' }
CairoPluginTestSupport class >> cairoVersion [

	^ self ffiCall: #(int cairo_version ())
]

{ #category : 'ffi counts' }
CairoPluginTestSupport class >> ffiCallsDuring: aBlock [
	"Run aBlock with the FFI callouts counted: answer { the Bag of the cairo functions called (C names). the Bag of the methods that called them ('AthensCairoCanvas>>ffiNewPath') }"

	| functions callers |
	"(the finalization process also calls the FFI (the *_destroy functions) and can preempt this one inside the hook: the Bags are only changed under countLock, else a count can be lost while one of them grows)"
	countLock ifNil: [ countLock := Mutex new ].
	functions := functionCounts := Bag new.
	callers := callerCounts := Bag new.
	self installHook.
	[ aBlock value ] ensure: [ self removeHook ].
	^ { functions. callers }
]

{ #category : 'ffi counts' }
CairoPluginTestSupport class >> ffiCountsDuring: aBlock [
	"Run aBlock with the FFI callouts counted: answer the Bag of the cairo functions (C names) the FFI called"

	^ (self ffiCallsDuring: aBlock) first
]

{ #category : 'primitives' }
CairoPluginTestSupport class >> drawingPrimitiveCounters [
	"CairoPlugin primitiveCounters without the admin primitives (reading the counters calls two of them)"

	| d |
	d := CairoPlugin primitiveCounters.
	#( 'primitiveInfo' 'primitiveBind' 'primitiveUnbind' 'primitiveCounters' 'primitiveFunctionNames'
	   'primitiveResetCounters' ) do: [ :each | d removeKey: each ifAbsent: [  ] ].
	^ d
]

{ #category : 'accessing' }
CairoPluginTestSupport class >> ffiLibrary [
	"The library of the state getters: the libcairo of Athens"

	^ CairoLibrary uniqueInstance
]

{ #category : 'accessing' }
CairoPluginTestSupport class >> ffiLibraryName [

	^ CairoLibrary
]

{ #category : 'accessing' }
CairoPluginTestSupport class >> handleOf: anObject [
	"The ExternalAddress in the handle slot of an Athens object (a canvas, a surface, a scaled font, a path, ...)"

	^ anObject instVarNamed: #handle
]

{ #category : 'modes' }
CairoPluginTestSupport class >> implementedGroups [
	"The groups whose primitives the bound plugin implements: a primitive of the stub plugin of a partial build answers #'unsupported operation' while bound, a real one with valid arguments never. Answers #() when the plugin is absent or unbound"

	| surface found |
	CairoPlugin isBound ifFalse: [ ^ #(  ) ].
	found := OrderedCollection new.
	surface := AthensCairoSurface extent: 4 @ 4.
	surface drawDuring: [ :c |
		| renderer probes |
		c setFont: (LogicalFont familyName: 'Source Sans Pro' pointSize: 10).
		c setPaint: Color black.
		renderer := c instVarNamed: #fontRenderer.
		probes := {
			          (#basic -> [ self primitive: #primitiveNewPath receiver: c arguments: #(  ) ]).
			          (#shape -> [
			           self
				           primitive: #primitiveFillRectangleColor:with:
				           receiver: c
				           arguments: {
						           (0 @ 0 corner: 1 @ 1).
						           Color red } ]).
			          (#text -> [
			           self
				           primitive: #primitiveShowString:with:with:with:with:
				           receiver: renderer
				           arguments: {
						           'a'.
						           1.
						           1.
						           (renderer instVarNamed: #originalFont) pixelSize.
						           Color } ]) }.
		probes do: [ :probe |
			| answer |
			answer := probe value value.
			((answer isKindOf: CairoPluginPrimitiveFailure) and: [
				 answer code = #'unsupported operation' ]) ifFalse: [
				found add: probe key ] ] ].
	^ found asArray
]

{ #category : 'ffi counts' }
CairoPluginTestSupport class >> installHook [

	| proto current |
	current := TFSameThreadRunner compiledMethodAt: #invokeFunction:withArguments:.
	"(the original is kept after removeHook: another process, the finalizer's, can be inside the hook when it is removed)"
	(current == hookMethod and: [ hookMethod notNil ]) ifFalse: [ originalInvoke := current ].
	proto := TFSameThreadRunner protocolNameOfSelector: #invokeFunction:withArguments:.
	CairoPluginInstaller quietly: [
		hookMethod
			ifNil: [
				TFSameThreadRunner
					compile: 'invokeFunction: function withArguments: aCollection
	"Installed by CairoPluginTestSupport class>>#ffiCallsDuring: while it counts the FFI callouts (tests only)"

	^ CairoPluginTestSupport
		  runner: self
		  invoke: function
		  withArguments: aCollection
		  caller: thisContext sender method'
					classified: proto
					withStamp: nil
					notifying: nil
					logSource: false.
				hookMethod := TFSameThreadRunner compiledMethodAt: #invokeFunction:withArguments: ]
			ifNotNil: [
				CairoPluginInstaller
					put: hookMethod
					in: TFSameThreadRunner
					at: #invokeFunction:withArguments:
					protocol: proto ] ]
]

{ #category : 'modes' }
CairoPluginTestSupport class >> modes [
	"The modes whose pixels, answers and cairo calls must be the same"

	^ #( #ffi #basic #all #fallback )
]

{ #category : 'primitives' }
CairoPluginTestSupport class >> primitive: aSelector receiver: anObject arguments: anArray [
	"Run the method aSelector of CairoPluginTestPrimitives with anObject as its receiver: what its primitive answers, or a CairoPluginPrimitiveFailure with the failure code"

	^ (CairoPluginTestPrimitives >> aSelector) valueWithReceiver: anObject arguments: anArray
]

{ #category : 'pixels' }
CairoPluginTestSupport class >> quickDigestOf: aSurface [
	"The CRC-32 of the bytes of aSurface, in hex (for messages: the tests compare the bytes)"

	^ self quickDigestOfBytes: (self bytesOf: aSurface)
]

{ #category : 'pixels' }
CairoPluginTestSupport class >> quickDigestOfBytes: aByteArray [

	^ ((ZipWriteStream updateCrc: 16rFFFFFFFF from: 1 to: aByteArray size in: aByteArray)
		   bitXor: 16rFFFFFFFF) printStringBase: 16 length: 8 padded: true
]

{ #category : 'pixels' }
CairoPluginTestSupport class >> digestOf: aSurface [
	"The SHA-256 of the bytes of aSurface, in hex"

	^ (SHA256 hashMessage: (self bytesOf: aSurface)) hex
]

{ #category : 'ffi counts' }
CairoPluginTestSupport class >> removeHook [

	originalInvoke ifNil: [ ^ self ].
	CairoPluginInstaller quietly: [
		CairoPluginInstaller
			put: originalInvoke
			in: TFSameThreadRunner
			at: #invokeFunction:withArguments:
			protocol: (TFSameThreadRunner protocolNameOfSelector: #invokeFunction:withArguments:) ].
	functionCounts := nil.
	callerCounts := nil
]

{ #category : 'ffi counts' }
CairoPluginTestSupport class >> runner: aRunner invoke: aFunction withArguments: aCollection caller: aMethod [
	"The hook (see #installHook): count the call, then make it with the original method"

	| original |
	original := originalInvoke.
	(countLock ifNil: [ Mutex new ]) critical: [
		functionCounts ifNotNil: [ :bag | bag add: aFunction functionName asString ].
		callerCounts ifNotNil: [ :bag |
			bag add: aMethod methodClass name , '>>' , aMethod selector ] ].
	^ original valueWithReceiver: aRunner arguments: {
			  aFunction.
			  aCollection }
]

{ #category : 'modes' }
CairoPluginTestSupport class >> setMode: aMode [
	"Put the image in aMode (see the class comment); answer the groups installed"

	| groups |
	aMode = #ffi ifTrue: [
		CairoPluginInstaller uninstall: CairoPlugin groups.
		^ CairoPlugin installedGroups ].
	groups := aMode = #basic
		          ifTrue: [ #( #basic ) ]
		          ifFalse: [ CairoPlugin groups ].
	CairoPluginInstaller uninstall: (CairoPlugin groups reject: [ :g | groups includes: g ]).
	CairoPlugin isAvailable
		ifTrue: [
			CairoPlugin isBound ifFalse: [ CairoPlugin bind ].
			CairoPluginInstaller install: groups force: false ]
		ifFalse: [ CairoPluginInstaller install: groups force: true ].
	(aMode = #fallback and: [ CairoPlugin isAvailable ]) ifTrue: [ CairoPlugin unbind ].
	^ CairoPlugin installedGroups
]

{ #category : 'state' }
CairoPluginTestSupport class >> stateOf: aCanvas [
	"The cairo state of aCanvas, an Array of name -> value, comparable with ="

	| cr m source rgba status dashes offset n fm state |
	cr := self handleOf: aCanvas.
	state := OrderedCollection new.
	m := ByteArray new: 48.
	self cairoMatrix: cr into: m.
	state add: #matrix -> ((1 to: 6) collect: [ :i | (m doubleAt: i - 1 * 8 + 1) asIEEE64BitWord ]).
	"the RGBA of a solid source; another pattern answers a status (CAIRO_STATUS_PATTERN_TYPE_MISMATCH) and leaves the doubles alone"
	source := self cairoSource: cr.
	rgba := (1 to: 4) collect: [ :i | ByteArray new: 8 ].
	status := self cairoPatternRGBA: source r: (rgba at: 1) g: (rgba at: 2) b: (rgba at: 3) a: (rgba at: 4).
	state add: #sourceStatus -> status.
	state add: #sourceRGBA -> (rgba collect: [ :b | (b doubleAt: 1) asIEEE64BitWord ]).
	state add: #lineWidth -> (self cairoLineWidth: cr) asIEEE64BitWord.
	state add: #lineJoin -> (self cairoLineJoin: cr).
	state add: #lineCap -> (self cairoLineCap: cr).
	n := self cairoDashCount: cr.
	dashes := ByteArray new: (n max: 1) * 8.
	offset := ByteArray new: 8.
	self cairoDash: cr into: dashes offset: offset.
	state add: #dashes -> ((1 to: n) collect: [ :i | (dashes doubleAt: i - 1 * 8 + 1) asIEEE64BitWord ]).
	state add: #dashOffset -> (offset doubleAt: 1) asIEEE64BitWord.
	state add: #hasCurrentPoint -> (self cairoHasCurrentPoint: cr).
	state add: #fillRule -> (self cairoFillRule: cr).
	state add: #operator -> (self cairoOperator: cr).
	fm := ByteArray new: 48.
	self cairoFontMatrix: cr into: fm.
	state add: #fontMatrix -> ((1 to: 6) collect: [ :i | (fm doubleAt: i - 1 * 8 + 1) asIEEE64BitWord ]).
	state add: #antialias -> (self cairoAntialias: cr).
	state add: #scaledFont -> (self cairoScaledFont: cr) asInteger.
	^ state asArray
]

{ #category : 'modes' }
CairoPluginTestSupport class >> warmUp: someScenes [
	"Draw every parity scene of someScenes once in #ffi mode and collect the garbage, so that uFFI has generated the callout of every FFI method they use (an uninstall puts the stubs back: warm up after it)"

	| previous |
	previous := CairoPlugin installedGroups.
	CairoPluginInstaller uninstall: CairoPlugin groups.
	[ someScenes paritySceneNames do: [ :name | someScenes runScene: name ].
	Smalltalk garbageCollect ] ensure: [
		previous isEmpty ifFalse: [
			CairoPluginInstaller install: previous force: CairoPlugin isBound not ] ]
]
