"
I check the contract of the primitives of the CairoPlugin (`docs/CairoPlugin.md`, `plugins/CairoPlugin/tests/primitives.txt`), without the fallback of the patched methods (`CairoPluginTestPrimitives`).

## C9, the bind

- a probe of another function fails with `#'inappropriate operation'` and leaves the plugin unbound;
- a nil or NULL probe, or a library that does not load, with `#'not found'`;
- a path of 256 bytes with `#'bad argument'`;
- a bad layout with `#'bad index'`;
- the right probe binds, with the layout of 33 elements (the string classes of the text primitive) or of its 29 integers.

## The admin primitives

The info (7 elements), the names of the 57 cairo functions and of the 69 primitives, the counters.

## Every drawing primitive

Succeeds on what Athens passes, answering what the FFI method answers, and counts its cairo calls.

## C5, failure safety

For each invalid input

- an immediate or short receiver,
- a nil, NULL or wrong-class handle,
- a Fraction, nil or Float where a number or an integer is expected,
- a short ByteArray,
- an ExternalAddress where bytes are expected (its 8 bytes stay unchanged),
- bytes without a NUL for the C strings,
- a read-only object to write,
- a wrong arity,
- a paint of another class,
- a fill outside `drawDuring:`,
- a WideString UTF-8 cannot encode,
- an unbound plugin

the primitive fails with the specified code and calls no cairo function (the counters do not change).

## What I need

I need the plugin, bound, with its drawing primitives (the stub plugin of a partial build has only the admin ones: then only the bind and admin tests run).
"
Class {
	#name : 'CairoPluginPrimitiveTest',
	#superclass : 'CairoPluginTestCase',
	#instVars : [
		'problems',
		'surface',
		'canvas'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> assertNoProblems [

	self assert: problems isEmpty description: [ problems size printString , ' problems: ' , problems asArray printString ]
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> bindError: aBlock [
	"The code of the CairoPluginError aBlock signals, or #none"

	^ [
	  aBlock value.
	  #none ]
		  on: CairoPluginError
		  do: [ :e | e return: e code ]
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> call: aSelector receiver: anObject arguments: anArray fails: codes [
	"Record a problem unless the primitive fails with one of codes (a Symbol or an Array of them) and calls no cairo function"

	| before primBefore answer accepted |
	accepted := codes isSymbol
		            ifTrue: [ { codes } ]
		            ifFalse: [ codes ].
	before := CairoPlugin counters.
	primBefore := CairoPluginTestSupport drawingPrimitiveCounters.
	answer := CairoPluginTestSupport primitive: aSelector receiver: anObject arguments: anArray.
	(self isFailure: answer)
		ifFalse: [
			^ problems add: aSelector , ' ' , (self describe: anArray) , ': answered ' , answer printString , ', expected a failure '
				  , accepted printString ].
	(accepted includes: answer code) ifFalse: [
		problems add: aSelector , ' ' , (self describe: anArray) , ': failed with ' , answer code printString , ', expected '
			, accepted printString ].
	CairoPlugin counters = before ifFalse: [
		problems add: aSelector , ' ' , (self describe: anArray) , ': called cairo before failing' ].
	CairoPluginTestSupport drawingPrimitiveCounters = primBefore ifFalse: [
		problems add: aSelector , ' ' , (self describe: anArray) , ': counted a call while failing' ].
	^ answer
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> call: aSelector receiver: anObject arguments: anArray succeeds: aBlock [
	"Record a problem unless the primitive succeeds and its answer satisfies aBlock (a one-argument block)"

	| answer |
	answer := CairoPluginTestSupport primitive: aSelector receiver: anObject arguments: anArray.
	(self isFailure: answer) ifTrue: [
		^ problems add: aSelector , ' ' , (self describe: anArray) , ': ' , answer printString ].
	(aBlock value: answer) ifFalse: [
		problems add: aSelector , ' ' , (self describe: anArray) , ': unexpected answer ' , answer printString ].
	^ answer
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> canvasWithHandle: anObject [

	^ canvas shallowCopy
		  instVarNamed: #handle put: anObject;
		  yourself
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> describe: anArray [
	"anArray printString, or the classes of its elements when one cannot be printed (a Color with nil slots)"

	^ [ anArray printString ]
		  on: Error
		  do: [ :e | e return: (anArray collect: [ :each | each class name ]) printString ]
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> extents: aClass bytes: anInteger [
	"A CairoTextExtents or CairoFontExtents (aClass) whose handle is a ByteArray of anInteger bytes"

	^ aClass basicNew
		  instVarNamed: #handle put: (ByteArray new: anInteger);
		  yourself
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> eaBytesUnchanged: anExternalAddress after: aBlock label: aString [

	| before |
	before := anExternalAddress asByteArray copy.
	aBlock value.
	anExternalAddress asByteArray = before ifFalse: [
		problems add: aString , ': the bytes of the ExternalAddress changed' ]
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> font [

	^ (canvas instVarNamed: #fontRenderer) instVarNamed: #font
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> readOnly: anObject [

	anObject beReadOnlyObject.
	^ anObject
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> renderer [

	^ canvas instVarNamed: #fontRenderer
]

{ #category : 'running' }
CairoPluginPrimitiveTest >> setUp [

	super setUp.
	problems := OrderedCollection new
]

{ #category : 'helpers' }
CairoPluginPrimitiveTest >> withCanvas: aBlock [
	"Run aBlock inside drawDuring: of a new 32 x 32 surface, with canvas set, a font and a black paint"

	self setMode: #ffi.
	surface := AthensCairoSurface extent: 32 @ 32.
	surface drawDuring: [ :c |
		canvas := c.
		c setFont: self scenes font.
		c setPaint: Color black.
		aBlock value ]
]

{ #category : 'tests - admin' }
CairoPluginPrimitiveTest >> testBind [
	"C9"

	| library probe layout version longPath |
	self skipUnlessBound.
	library := CairoPlugin libraryName.
	probe := CairoPlugin probeAddress.
	layout := CairoPluginLayout current.
	self assert: probe notNil.
	self assert: layout size equals: 33.
	version := CairoPlugin primBind: library probe: probe layout: layout.
	self assert: version isInteger.
	self assert: version >= 11600.
	self assert: CairoPlugin isBound.
	self assert: CairoPlugin cairoVersion equals: version.
	"a probe of another function: the bound cairo is not the FFI's"
	self
		assert: (self bindError: [
				 CairoPlugin
					 primBind: library
					 probe: (ExternalAddress loadSymbol: 'cairo_destroy' module: library)
					 layout: layout ])
		equals: #'inappropriate operation'.
	self deny: CairoPlugin isBound.
	self assert: (self bindError: [ CairoPlugin primBind: library probe: nil layout: layout ]) equals: #'not found'.
	self deny: CairoPlugin isBound.
	self assert: (self bindError: [ CairoPlugin primBind: library probe: ExternalAddress new layout: layout ]) equals: #'not found'.
	(CairoPlugin info at: 5) = 'loader' ifTrue: [
		self
			assert: (self bindError: [ CairoPlugin primBind: '/nonexistent/CairoPluginTest/libcairo.so.2' probe: probe layout: layout ])
			equals: #'not found'.
		self deny: CairoPlugin isBound ].
	longPath := String new: 256 withAll: $a.
	self assert: (self bindError: [ CairoPlugin primBind: longPath probe: probe layout: layout ]) equals: #'bad argument'.
	self
		assert: (self bindError: [ CairoPlugin primBind: library probe: probe layout: (layout copyWith: 0) ])
		equals: #'bad index'.
	self
		assert: (self bindError: [
				 CairoPlugin primBind: library probe: probe layout: (layout copy
						  at: 1 put: 2;
						  yourself) ])
		equals: #'bad index'.
	self assert: (CairoPlugin primBind: library probe: probe layout: (layout first: 29)) equals: version.
	self assert: CairoPlugin isBound.
	self assert: CairoPlugin bind equals: version
]

{ #category : 'tests - admin' }
CairoPluginPrimitiveTest >> testCountersAndNames [

	| names counters |
	self skipUnlessBound.
	names := CairoPlugin primFunctionNames.
	self assert: names size equals: 2.
	self assert: names first size equals: 57.
	self assert: names last size equals: 69.
	self assert: (names first includes: 'cairo_new_path').
	self assert: (names first includes: 'cairo_text_path').
	self assert: (names last includes: 'primitiveShowString').
	CairoPluginTestPrimitives methods do: [ :m |
		| name |
		name := (m pragmaAt: #primitive:module:error:) arguments first.
		self assert: (names last includes: name) description: name , ' is not a primitive of the plugin' ].
	counters := CairoPlugin primCounters.
	self assert: counters first size equals: 57.
	self assert: counters last size equals: 69.
	CairoPlugin resetCounters.
	self assert: (CairoPlugin counters values allSatisfy: [ :n | n = 0 ]).
	self assert: (CairoPluginTestSupport drawingPrimitiveCounters values allSatisfy: [ :n | n = 0 ])
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresOfBuilderAndMatrix [

	self skipUnlessImplemented: #( #basic ).
	self withCanvas: [
		| builder matrix short ro ea x |
		builder := canvas surface instVarNamed: #builder.
		self call: #primitiveBuilderMoveTo:with: receiver: builder arguments: { 1 / 2. 1.0 } fails: #'bad argument'.
		self call: #primitiveBuilderLineTo:with: receiver: builder arguments: { 1.0. nil } fails: #'bad argument'.
		self call: #primitiveBuilderCurveTo:with:with:with:with:with: receiver: builder arguments: { 1. 2. 3. 4. 5. '6' } fails: #'bad argument'.
		self call: #primitiveBuilderClosePath receiver: (builder shallowCopy instVarNamed: #context put: nil; yourself) arguments: #(  ) fails: #'bad receiver'.
		self call: #primitiveBuilderNewPath receiver: (builder shallowCopy instVarNamed: #context put: (self canvasWithHandle: ExternalAddress new); yourself) arguments: #(  ) fails: #'bad receiver'.
		self call: #primitiveBuilderCopyPath: receiver: builder arguments: { self readOnly: AthensCairoPath basicNew } fails: #'no modification'.
		self call: #primitiveBuilderCopyPath: receiver: builder arguments: { 3 } fails: #'bad argument'.
		self call: #primitiveBuilderArc:with:with:with:with: receiver: builder arguments: { 1. 2. 3. 4. 1 / 3 } fails: #'bad argument'.
		self call: #primitivePathDestroy: receiver: AthensCairoPath arguments: { ExternalAddress new } fails: #'bad argument'.
		self call: #primitivePathDestroy: receiver: AthensCairoPath arguments: { ByteArray new: 8 } fails: #'bad argument'.
		matrix := AthensCairoMatrix new.
		short := AthensCairoMatrix basicNew.
		short instVarNamed: #handle put: (ByteArray new: 40).
		self call: #primitiveMatrixInitIdentity receiver: short arguments: #(  ) fails: #'bad receiver'.
		ro := AthensCairoMatrix new.
		ro getHandle beReadOnlyObject.
		self call: #primitiveMatrixInitIdentity receiver: ro arguments: #(  ) fails: #'no modification'.
		self call: #primitiveMatrixTranslate:with: receiver: ro arguments: #( 1 2 ) fails: #'no modification'.
		ro getHandle beWritableObject.
		self call: #primitiveMatrixScale:with: receiver: matrix arguments: { 2. 1 / 2 } fails: #'bad argument'.
		self call: #primitiveMatrixMultiply: receiver: matrix arguments: { short } fails: #'bad argument'.
		self call: #primitiveMatrixMultiply: receiver: matrix arguments: { nil } fails: #'bad argument'.
		self call: #primitiveMatrixInit:with:with:with:with:with: receiver: matrix arguments: { 1. 2. 3. 4. 5. nil } fails: #'bad argument'.
		"#44: the out arguments are bytes: an ExternalAddress (8 bytes, a pointer) fails, its bytes unchanged"
		ea := ExternalAddress fromAddress: 16r1234.
		x := ByteArray new: 8.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveMatrixTransformPoint:with: receiver: matrix arguments: { ea. x } fails: #'bad argument' ]
			label: 'primitiveMatrixTransformPoint'.
		self call: #primitiveMatrixTransformPoint:with: receiver: matrix arguments: { ByteArray new: 4. x } fails: #'bad argument'.
		self call: #primitiveMatrixTransformPoint:with: receiver: matrix arguments: { x. self readOnly: (ByteArray new: 8) } fails: #'no modification' ].
	self assertNoProblems
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresOfCanvasPrimitives [

	self skipUnlessImplemented: #( #basic ).
	self withCanvas: [
		| ea |
		"receivers"
		{ 3. 'abc'. nil. Array new: 2. self canvasWithHandle: nil. self canvasWithHandle: ExternalAddress new.
		  self canvasWithHandle: (ByteArray new: 8). self canvasWithHandle: 42 } do: [ :bad |
			self call: #primitiveNewPath receiver: bad arguments: #(  ) fails: #'bad receiver' ].
		self call: #primitiveSetPathMatrix receiver: (canvas shallowCopy instVarNamed: #pathTransform put: nil; yourself) arguments: #(  ) fails: #'bad receiver'.
		"numbers and integers"
		{ 1 / 2. nil. '1'. 2 raisedTo: 100 } do: [ :bad |
			self call: #primitiveSetLineWidth: receiver: canvas arguments: { bad } fails: #'bad argument' ].
		{ 1.0. nil. 1 / 2 } do: [ :bad |
			self call: #primitiveSetLineJoin: receiver: canvas arguments: { bad } fails: #'bad argument' ].
		self call: #primitiveSetSourceRGBA:with:with:with: receiver: canvas arguments: { 0.5. 1 / 3. 0. 1 } fails: #'bad argument'.
		self call: #primitiveRectangle:with:with:with: receiver: canvas arguments: { 1. 2. 3. 1 / 4 } fails: #'bad argument'.
		self call: #primitiveSetMatrix: receiver: canvas arguments: { nil } fails: #'bad argument'.
		self call: #primitiveSetSource: receiver: canvas arguments: { AthensCairoPatternPaint basicNew } fails: #'bad argument'.
		self call: #primitiveAppendPath: receiver: canvas arguments: { AthensCairoPath basicNew instVarNamed: #handle put: ExternalAddress new; yourself } fails: #'bad argument'.
		self call: #primitiveSetScaledFont: receiver: canvas arguments: { CairoScaledFont basicNew instVarNamed: #handle put: ExternalAddress new; yourself } fails: #'bad argument'.
		self call: #primitiveGetScaledFont: receiver: canvas arguments: { self readOnly: CairoScaledFont basicNew } fails: #'no modification'.
		self call: #primitiveGetScaledFont: receiver: canvas arguments: { 'bytes' } fails: #'bad argument'.
		"#15 set_dash: the lengths are bytes (an ExternalAddress fails, unchanged), n within them"
		ea := ExternalAddress fromAddress: 16r1234.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveSetDash:with:with: receiver: canvas arguments: { ea. 1. 0.0 } fails: #'bad argument' ]
			label: 'primitiveSetDash'.
		self call: #primitiveSetDash:with:with: receiver: canvas arguments: { ByteArray new: 16. 3. 0.0 } fails: #'bad argument'.
		self call: #primitiveSetDash:with:with: receiver: canvas arguments: { ByteArray new: 16. -1. 0.0 } fails: #'bad argument'.
		self call: #primitiveSetDash:with:with: receiver: canvas arguments: { ByteArray new: 16. 2. nil } fails: #'bad argument'.
		"#25 show_glyphs: n * 24 bytes at most"
		self call: #primitiveShowGlyphs:with: receiver: canvas arguments: { ByteArray new: 24. 2 } fails: #'bad argument'.
		self call: #primitiveShowGlyphs:with: receiver: canvas arguments: { ByteArray new: 24. -1 } fails: #'bad argument'.
		self call: #primitiveShowGlyphs:with: receiver: canvas arguments: { ExternalAddress new. 1 } fails: #'bad argument'.
		"#58 text_path: a C string in the bytes (no NUL in the body, an ExternalAddress, nothing)"
		self call: #primitiveTextPath: receiver: canvas arguments: { ByteArray new: 8 withAll: 65 } fails: #'bad argument'.
		self call: #primitiveTextPath: receiver: canvas arguments: { ByteArray new } fails: #'bad argument'.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveTextPath: receiver: canvas arguments: { ea } fails: #'bad argument' ]
			label: 'primitiveTextPath'.
		"paint mode, surface"
		self call: #primitiveGetOperator receiver: (AthensCairoPaintMode basicNew instVarNamed: #canvas put: nil; yourself) arguments: #(  ) fails: #'bad receiver'.
		self call: #primitiveSetOperator: receiver: canvas paintMode arguments: { nil } fails: #'bad argument'.
		self call: #primitiveSurfaceFlush receiver: (AthensCairoSurface basicNew instVarNamed: #handle put: ExternalAddress new; yourself) arguments: #(  ) fails: #'bad receiver'.
		"arity"
		self call: #primitiveNewPathWrongArity: receiver: canvas arguments: #( 1 ) fails: #'bad number of arguments'.
		self call: #primitiveSetLineWidthWrongArity receiver: canvas arguments: #(  ) fails: #'bad number of arguments'.
		self call: #primitiveBuilderMoveToWrongArity:with:with: receiver: canvas arguments: #( 1 2 3 ) fails: #'bad number of arguments' ].
	self assertNoProblems
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresOfFontPrimitives [

	self skipUnlessImplemented: #( #basic ).
	self withCanvas: [
		| font ea extents nullFont utf8 |
		font := self font.
		nullFont := CairoScaledFont basicNew instVarNamed: #handle put: ExternalAddress new; yourself.
		ea := ExternalAddress fromAddress: 16r1234.
		extents := self extents: CairoTextExtents bytes: 48.
		self call: #primitiveScaledFontLockFace receiver: nullFont arguments: #(  ) fails: #'bad receiver'.
		self call: #primitiveScaledFontExtents: receiver: font arguments: { self extents: CairoFontExtents bytes: 16 } fails: #'bad argument'.
		self call: #primitiveScaledFontExtents: receiver: font arguments: { CairoFontExtents basicNew instVarNamed: #handle put: (self readOnly: (ByteArray new: 48)); yourself } fails: #'no modification'.
		self call: #primitiveScaledFontExtents: receiver: font arguments: { ByteArray new: 48 } fails: #'bad argument'.
		self call: #primitiveScaledFontExtents: receiver: font arguments: { CairoFontExtents basicNew instVarNamed: #handle put: ExternalAddress new; yourself } fails: #'bad argument'.
		self call: #primitiveScaledFontGlyphExtents:with:with: receiver: font arguments: { ByteArray new: 24. 2. extents } fails: #'bad argument'.
		self call: #primitiveScaledFontGlyphExtents:with:with: receiver: font arguments: { ByteArray new: 24. 1. self extents: CairoTextExtents bytes: 8 } fails: #'bad argument'.
		self call: #primitiveScaledFontGlyphExtents:with:with: receiver: font arguments: { ByteArray new: 24. 1. CairoTextExtents basicNew instVarNamed: #handle put: (self readOnly: (ByteArray new: 48)); yourself } fails: #'no modification'.
		"#54: a C string, never read past its object"
		self call: #primitiveScaledFontTextExtents:with: receiver: font arguments: { ByteArray new: 8 withAll: 65. extents } fails: #'bad argument'.
		self call: #primitiveScaledFontTextExtents:with: receiver: font
			arguments: { #[65 0]. CairoTextExtents basicNew instVarNamed: #handle put: (self readOnly: (ByteArray new: 48)); yourself } fails: #'no modification'.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveScaledFontTextExtents:with: receiver: font arguments: { ea. extents } fails: #'bad argument' ]
			label: 'primitiveScaledFontTextExtents'.
		"#56 text_to_glyphs: utf8 and numGlyphs are bytes, the glyphs an ExternalAddress (in/out)"
		utf8 := 'abc' asByteArray.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
				arguments: { ea. 3. font. ExternalAddress new. ByteArray new: 4. 0.0. 0.0 } fails: #'bad argument' ]
			label: 'primitiveTextToGlyphs utf8'.
		self eaBytesUnchanged: ea after: [
			self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
				arguments: { utf8. 3. font. ExternalAddress new. ea. 0.0. 0.0 } fails: #'bad argument' ]
			label: 'primitiveTextToGlyphs numGlyphs'.
		self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
			arguments: { utf8. 4. font. ExternalAddress new. ByteArray new: 4. 0.0. 0.0 } fails: #'bad argument'.
		self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
			arguments: { utf8. 3. nullFont. ExternalAddress new. ByteArray new: 4. 0.0. 0.0 } fails: #'bad argument'.
		self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
			arguments: { utf8. 3. font. ExternalAddress new. self readOnly: (ByteArray new: 4). 0.0. 0.0 } fails: #'no modification'.
		self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: self renderer
			arguments: { utf8. 3. font. self readOnly: ExternalAddress new. ByteArray new: 4. 0.0. 0.0 } fails: #'no modification'.
		self call: #primitiveGlyphFree: receiver: self renderer arguments: { ByteArray new: 8 } fails: #'bad argument' ].
	self assertNoProblems
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresOfShapePrimitives [

	| outside |
	self skipUnlessImplemented: #( #shape ).
	self withCanvas: [
		| rect stroke |
		rect := 1 @ 2 corner: 10 @ 12.
		stroke := canvas setStrokePaint: Color red.
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { 1 @ 2 corner: 10 @ (1 / 2). Color red } fails: #'bad argument'.
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { rect. nil } fails: #'bad argument'.
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { rect. Color basicNew } fails: #'bad argument'.
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { 3. Color red } fails: #'bad argument'.
		self call: #primitiveFillPathColor:with: receiver: canvas arguments: { AthensCairoPath basicNew instVarNamed: #handle put: ExternalAddress new; yourself. Color red } fails: #'bad argument'.
		self call: #primitiveStrokeRectangle:with:with: receiver: canvas arguments: { rect. stroke. Object } fails: #'bad argument'.
		self call: #primitiveStrokeRectangle:with:with: receiver: canvas
			arguments: { rect. stroke copy dashes: { 1. 1 / 2 } offset: 0; yourself. Color } fails: #'bad argument'.
		self call: #primitiveStrokeRectangle:with:with: receiver: canvas
			arguments: { rect. stroke copy dashes: (Array new: 5000 withAll: 1) offset: 0; yourself. Color } fails: #'bad argument'.
		self call: #primitiveStrokeRectangle:with:with: receiver: canvas
			arguments: { rect. stroke copy instVarNamed: #width put: 1 / 2; yourself. Color } fails: #'bad argument'.
		self call: #primitiveStrokePath:with:with: receiver: canvas
			arguments: { AthensCairoPath basicNew instVarNamed: #handle put: ExternalAddress new; yourself. stroke. Color } fails: #'bad argument'.
		self call: #primitiveFillRectangleColorWrongArity: receiver: canvas arguments: { rect } fails: #'bad number of arguments' ].
	"a fill outside drawDuring: (the surface's current canvas is not the receiver)"
	outside := canvas.
	self call: #primitiveFillRectangleColor:with: receiver: outside arguments: { 1 @ 1 corner: 5 @ 5. Color red } fails: #'bad receiver'.
	self assertNoProblems
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresOfTextPrimitive [

	self skipUnlessImplemented: #( #text ).
	self withCanvas: [
		| renderer size |
		renderer := self renderer.
		size := (renderer instVarNamed: #originalFont) pixelSize.
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 1. 3. size. Object } fails: #'bad receiver'.
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { #( 1 2 3 ). 1. 3. size. Color } fails: #'bad argument'.
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc' asByteArray. 1. 3. size. Color } fails: #'bad argument'.
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 0. 3. size. Color } fails: #( #'bad argument' #'bad index' ).
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 1. 4. size. Color } fails: #( #'bad argument' #'bad index' ).
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 3. 1. size. Color } fails: #( #'bad argument' #'bad index' ).
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 1. 3. 1 / 2. Color } fails: #'bad argument'.
		self scenes invalidWideStrings do: [ :s |
			self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { s. 1. s size. size. Color } fails: #'bad argument' ].
		canvas setPaint: (canvas surface createLinearGradient: { 0 -> Color red. 1 -> Color blue } start: 0 @ 0 stop: 1 @ 1).
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 1. 3. size. Color } fails: #'bad receiver'.
		canvas setPaint: Color black.
		self call: #primitiveShowString:with:with:with:with: receiver: (renderer shallowCopy instVarNamed: #font put: nil; yourself) arguments: { 'abc'. 1. 3. size. Color } fails: #'bad receiver'.
		self call: #primitiveShowStringWrongArity:with:with:with: receiver: renderer arguments: { 'abc'. 1. 3. size } fails: #'bad number of arguments' ].
	self assertNoProblems
]

{ #category : 'tests - failures' }
CairoPluginPrimitiveTest >> testFailuresWhenUnbound [

	self skipUnlessImplemented: #( #basic #shape #text ).
	self withCanvas: [
		CairoPlugin unbind.
		self call: #primitiveNewPath receiver: canvas arguments: #(  ) fails: #'unsupported operation'.
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { 0 @ 0 corner: 2 @ 2. Color red } fails: #'unsupported operation'.
		self call: #primitiveShowString:with:with:with:with: receiver: self renderer arguments: { 'a'. 1. 1. 10. Color } fails: #'unsupported operation'.
		self call: #primitiveMatrixInitIdentity receiver: AthensCairoMatrix new arguments: #(  ) fails: #'unsupported operation' ].
	self assertNoProblems
]

{ #category : 'tests - answers' }
CairoPluginPrimitiveTest >> testSuccesses [
	"Every drawing primitive succeeds on what Athens passes and answers what the FFI method answers"

	self skipUnlessImplemented: #( #basic #shape #text ).
	self withCanvas: [
		| builder matrix other path font renderer stroke glyphs num ptr extents xb yb |
		builder := canvas surface instVarNamed: #builder.
		matrix := AthensCairoMatrix new.
		other := AthensCairoMatrix new.
		font := self font.
		renderer := self renderer.
		stroke := canvas setStrokePaint: Color red.
		canvas setPaint: Color black.
		#( #primitiveNewPath #primitiveSave #primitiveRestore #primitiveResetClip #primitiveSetPathMatrix #primitiveFill
		   #primitiveFillPreserve #primitiveStroke #primitivePaint #primitiveClip ) do: [ :sel |
			self call: sel receiver: canvas arguments: #(  ) succeeds: [ :a | a == canvas ] ].
		self call: #primitiveSetMatrix: receiver: canvas arguments: { matrix } succeeds: [ :a | a == canvas ].
		self call: #primitiveSetSourceRGBA:with:with:with: receiver: canvas arguments: #( 0.25 1 0 0.5 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveResetDash: receiver: canvas arguments: #( 0 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetDash:with:with: receiver: canvas arguments: { ByteArray new: 16. 0. 1.5 } succeeds: [ :a | a == canvas ].
		self call: #primitiveRectangle:with:with:with: receiver: canvas arguments: #( 1 2 3.5 4 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetLineWidth: receiver: canvas arguments: #( 2 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetLineJoin: receiver: canvas arguments: #( 1 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetLineCap: receiver: canvas arguments: #( 2 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetAntialias: receiver: canvas arguments: #( 2 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetFillRule: receiver: canvas arguments: #( 1 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetFontSize: receiver: canvas arguments: #( 12 ) succeeds: [ :a | a == canvas ].
		self call: #primitiveSetScaledFont: receiver: canvas arguments: { font } succeeds: [ :a | a == canvas ].
		self call: #primitiveGetScaledFont: receiver: canvas arguments: { CairoScaledFont basicNew }
			succeeds: [ :a | a class == CairoScaledFont and: [ (CairoPluginTestSupport handleOf: a) asInteger = (CairoPluginTestSupport handleOf: canvas getScaledFont) asInteger ] ].
		self call: #primitiveBuilderNewPath receiver: builder arguments: #(  ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderMoveTo:with: receiver: builder arguments: #( 1 2.5 ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderLineTo:with: receiver: builder arguments: #( 10 12 ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderCurveTo:with:with:with:with:with: receiver: builder arguments: #( 1 2 3 4 5 6 ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderArc:with:with:with:with: receiver: builder arguments: #( 10 10 5 0 3 ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderArcNegative:with:with:with:with: receiver: builder arguments: #( 10 10 5 0 3 ) succeeds: [ :a | a == builder ].
		self call: #primitiveBuilderClosePath receiver: builder arguments: #(  ) succeeds: [ :a | a == builder ].
		self call: #primitiveGetCurrentPoint receiver: canvas arguments: #(  ) succeeds: [ :a | a class == Point and: [ a x class == SmallFloat64 or: [ a x isFloat ] ] ].
		path := self call: #primitiveBuilderCopyPath: receiver: builder arguments: { AthensCairoPath basicNew }
			        succeeds: [ :a | a class == AthensCairoPath and: [ (CairoPluginTestSupport handleOf: a) isNull not ] ].
		(self isFailure: path) ifFalse: [
			self call: #primitiveAppendPath: receiver: canvas arguments: { path } succeeds: [ :a | a == canvas ].
			self call: #primitivePathDestroy: receiver: AthensCairoPath arguments: { CairoPluginTestSupport handleOf: path } succeeds: [ :a | a == AthensCairoPath ].
			path instVarNamed: #handle put: ExternalAddress new ].
		self call: #primitiveMatrixInit:with:with:with:with:with: receiver: matrix arguments: #( 1 2 3 4 5 6 ) succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixInitIdentity receiver: matrix arguments: #(  ) succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixTranslate:with: receiver: matrix arguments: #( 3 4 ) succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixScale:with: receiver: matrix arguments: #( 2 2 ) succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixRotate: receiver: matrix arguments: #( 0.5 ) succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixMultiply: receiver: matrix arguments: { other } succeeds: [ :a | a == matrix ].
		self call: #primitiveMatrixInvert receiver: matrix arguments: #(  ) succeeds: [ :a | a = 0 ].
		self call: #primitiveMatrixInitTranslate:with: receiver: other arguments: #( 1 1 ) succeeds: [ :a | a == other ].
		self call: #primitiveMatrixInitScale:with: receiver: other arguments: #( 0 0 ) succeeds: [ :a | a == other ].
		self call: #primitiveMatrixInvert receiver: other arguments: #(  ) succeeds: [ :a | a isInteger and: [ a ~= 0 ] ].
		self call: #primitiveMatrixInitRotate: receiver: other arguments: #( 1 ) succeeds: [ :a | a == other ].
		xb := ByteArray new: 8.
		yb := ByteArray new: 8.
		xb doubleAt: 1 put: 1.0.
		yb doubleAt: 1 put: 2.0.
		self call: #primitiveMatrixTransformPoint:with: receiver: matrix arguments: { xb. yb } succeeds: [ :a | a == matrix ].
		self call: #primitiveGetOperator receiver: canvas paintMode arguments: #(  ) succeeds: [ :a | a isInteger ].
		self call: #primitiveSetOperator: receiver: canvas paintMode arguments: #( 2 ) succeeds: [ :a | a == canvas paintMode ].
		self call: #primitiveSurfaceFlush receiver: canvas surface arguments: #(  ) succeeds: [ :a | a == canvas surface ].
		self call: #primitiveTextPath: receiver: canvas arguments: { 'ab' asByteArray , #[ 0 ] } succeeds: [ :a | a == canvas ].
		self call: #primitiveTextPath: receiver: canvas arguments: { 'abc' } succeeds: [ :a | a == canvas ].
		self call: #primitiveScaledFontLockFace receiver: font arguments: #(  ) succeeds: [ :a | a == font ].
		self call: #primitiveScaledFontUnlockFace receiver: font arguments: #(  ) succeeds: [ :a | a == font ].
		self call: #primitiveScaledFontExtents: receiver: font arguments: { CairoFontExtents new } succeeds: [ :a | a = 0 ].
		extents := CairoTextExtents new.
		self call: #primitiveScaledFontTextExtents:with: receiver: font arguments: { 'abc' asByteArray , #[ 0 ]. extents } succeeds: [ :a | a == font ].
		self assert: extents width > 0.
		"#56 then #53, #25, #57 on the glyphs cairo allocated"
		ptr := ExternalAddress new.
		num := ByteArray new: 4.
		num unsignedLongAt: 1 put: 3.
		self call: #primitiveTextToGlyphs:with:with:with:with:with:with: receiver: renderer
			arguments: { 'abc' asByteArray. 3. font. ptr. num. 0.0. 0.0 } succeeds: [ :a | a = 0 ].
		self assert: (num unsignedLongAt: 1) equals: 3.
		self deny: ptr isNull.
		self call: #primitiveScaledFontGlyphExtents:with:with: receiver: font arguments: { ptr. 3. extents } succeeds: [ :a | a == font ].
		glyphs := ByteArray new: 72.
		LibC memCopy: ptr to: glyphs size: 72.
		self call: #primitiveShowGlyphs:with: receiver: canvas arguments: { glyphs. 3 } succeeds: [ :a | a == canvas ].
		self call: #primitiveGlyphFree: receiver: renderer arguments: { ptr } succeeds: [ :a | a == renderer ].
		self call: #primitiveGlyphFree: receiver: renderer arguments: { ExternalAddress new } succeeds: [ :a | a == renderer ].
		"shape and text"
		self call: #primitiveFillRectangleColor:with: receiver: canvas arguments: { 1 @ 1 corner: 9 @ 9. Color red } succeeds: [ :a | a == canvas surface ].
		self call: #primitiveStrokeRectangle:with:with: receiver: canvas arguments: { 1 @ 1 corner: 9 @ 9. stroke. Color } succeeds: [ :a | a == stroke ].
		path := canvas createPath: [ :b | b moveTo: 2 @ 2; lineTo: 8 @ 9 ].
		self call: #primitiveFillPathColor:with: receiver: canvas arguments: { path. Color blue } succeeds: [ :a | a == canvas surface ].
		self call: #primitiveStrokePath:with:with: receiver: canvas arguments: { path. stroke. Color } succeeds: [ :a | a == stroke ].
		canvas setPaint: Color black.
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { 'abc'. 1. 3. 10. Color } succeeds: [ :a | a == true ].
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { #abc. 2. 3. 10. Color } succeeds: [ :a | a == true ].
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { self scenes wideScripts last. 1. 3. 10. Color } succeeds: [ :a | a == true ].
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { self scenes wideScripts last asSymbol. 1. 3. 10. Color } succeeds: [ :a | a == true ].
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { ''. 1. 0. 10. Color } succeeds: [ :a | a == true ].
		self call: #primitiveShowString:with:with:with:with: receiver: renderer arguments: { self scenes longStrings first. 1. 2000. 10. Color } succeeds: [ :a | a == true ] ].
	self assertNoProblems
]

{ #category : 'tests - admin' }
CairoPluginPrimitiveTest >> testInfo [

	| info |
	self skipUnlessPlugin.
	info := CairoPlugin info.
	self assert: info size equals: 7.
	self assert: (info at: 1) equals: 1.
	self assert: (info at: 2) equals: 'CairoPlugin 1.0'.
	self assert: (#( 'native' 'emscripten' ) includes: (info at: 3)).
	self assert: (#( 'loader' 'static' ) includes: (info at: 5)).
	self assert: (info at: 7) isArray.
	CairoPlugin isBound ifTrue: [
		self assert: (info at: 4) >= 11600.
		self assert: (info at: 6) isNil ]
]

{ #category : 'tests - admin' }
CairoPluginPrimitiveTest >> testPluginImplementsEveryGroup [
	"The bound plugin implements the primitives of every group (a stub plugin answers #'unsupported operation' to all of them)"

	self skipUnlessImplemented: CairoPlugin groups.
	self assert: self implementedGroups equals: CairoPlugin groups
]
