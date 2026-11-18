"
I check criterion C4 of the CairoPlugin (docs/CairoPlugin.md): for every scene, the calls of each cairo function in #basic and #all (the calls the plugin made, `CairoPlugin counters`, plus the FFI callouts left) equal the FFI callouts of #ffi; no patched method fell back to its FFI copy (the no-fallback check of the benchmark); and in #basic the successful calls of each one-for-one primitive equal the FFI callouts of the method it replaces.

`testEveryBasicPatchReachesItsPrimitive` checks the wiring of #basic method by method, scenes or not (Athens sends some of its methods from nowhere: primPaint, setPathMatrix:, the matrix initializers): each patched method, sent once (`wiringScenarios`), makes exactly one successful call, of the primitive its row of the table names, calls the cairo functions of its row and no other, and leaves the same answer, matrix, cairo state and pixels as its ffi copy.

Each scene is drawn once in #ffi before it is counted (its fonts, renderers and callouts are then made: their cairo calls happen once); then every scene is counted in #ffi, and in each other mode in turn. The `*_destroy` functions are left out (finalization calls them when the garbage collector runs, which differs between runs), and so are the callouts that are not cairo's (LibC's memcpy). Without the plugin I compare #ffi with #fallback (the plugin counts nothing there), then skip myself saying so.
"
Class {
	#name : 'CairoPluginCallCountTest',
	#superclass : 'CairoPluginTestCase',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginCallCountTest >> callsOf: aName [
	"Draw the scene aName in the current mode: { the FFI callouts by cairo function (Bag). by calling method (Bag). the plugin's cairo calls by function (Dictionary). its successful calls by primitive (Dictionary) }"

	| ffi |
	CairoPlugin resetCounters.
	ffi := CairoPluginTestSupport ffiCallsDuring: [ self scenes runScene: aName ].
	^ {
		  ffi first.
		  ffi last.
		  CairoPlugin counters.
		  CairoPlugin primitiveCounters }
]

{ #category : 'helpers' }
CairoPluginCallCountTest >> referenceCalls [
	"The calls of every parity scene in #ffi, each scene drawn once before (its fonts and renderers are then made, uFFI has generated its callouts)"

	| names reference |
	names := self scenes paritySceneNames.
	self setMode: #ffi.
	names do: [ :name | self scenes runScene: name ].
	reference := Dictionary new.
	names do: [ :name | reference at: name put: (self callsOf: name) ].
	^ reference
]

{ #category : 'helpers' }
CairoPluginCallCountTest >> comparedFunctions: aBag [

	^ aBag asSet select: [ :f | self isCompared: f ]
]

{ #category : 'helpers' }
CairoPluginCallCountTest >> ffiCopyNames [
	"The ffi copies of the installed patches, as the hook names their callouts ('AthensCairoCanvas>>ffiNewPath')"

	| names |
	names := Set new.
	CairoPluginInstaller records do: [ :recs |
		recs do: [ :r |
			names add: r targetClassName , (r isMeta
					  ifTrue: [ ' class' ]
					  ifFalse: [ '' ]) , '>>' , r ffiSelector ] ].
	^ names
]

{ #category : 'helpers' }
CairoPluginCallCountTest >> ffiCopyNameOf: aMethodName [
	"'AthensCairoCanvas>>newPath' -> 'AthensCairoCanvas>>ffiNewPath'"

	| i |
	i := aMethodName indexOfSubCollection: '>>'.
	^ (aMethodName first: i + 1) , (CairoPluginInstaller ffiSelectorFor: (aMethodName allButFirst: i + 1) asSymbol)
]

{ #category : 'helpers' }
CairoPluginCallCountTest >> isCompared: aFunctionName [

	^ (aFunctionName beginsWith: 'cairo_') and: [ (aFunctionName endsWith: '_destroy') not ]
]

{ #category : 'tests' }
CairoPluginCallCountTest >> testCallsPerFunction [

	| modes failures references copies |
	modes := self comparableModes.
	failures := OrderedCollection new.
	references := self referenceCalls.
	modes do: [ :mode |
		self setMode: mode.
		copies := self ffiCopyNames.
		self scenes paritySceneNames do: [ :name |
			| reference calls functions fallbacks |
			reference := references at: name.
			calls := self callsOf: name.
			functions := Set new.
			functions
				addAll: (self comparedFunctions: reference first);
				addAll: (self comparedFunctions: calls first).
			(calls at: 3) keysAndValuesDo: [ :f :n | (n > 0 and: [ self isCompared: f ]) ifTrue: [ functions add: f ] ].
			functions do: [ :f |
				| expected got |
				expected := reference first occurrencesOf: f.
				got := (calls first occurrencesOf: f) + ((calls at: 3) at: f ifAbsent: [ 0 ]).
				got = expected ifFalse: [
					failures add: name , ' ' , mode , ' ' , f , ' ' , got printString , ' (ffi '
						, expected printString , ')' ] ].
			fallbacks := (calls at: 2) asSet select: [ :m | copies includes: m ].
			(mode ~= #fallback and: [ fallbacks notEmpty ]) ifTrue: [
				failures add: name , ' ' , mode , ' FALLBACK '
					, (fallbacks asSortedCollection asArray collect: [ :m | m , '=' , ((calls at: 2) occurrencesOf: m) printString ]) printString ] ] ].
	self assert: failures isEmpty description: [ 'cairo calls differ: ' , failures asArray printString ].
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginCallCountTest >> testPrimitiveCallsPerMethod [
	"In #basic, each one-for-one primitive succeeded as many times as the FFI method it replaces was called in #ffi"

	| failures primitiveOf references |
	self skipUnlessImplemented: #( #basic ).
	primitiveOf := Dictionary new.
	CairoPluginInstaller basicTable do: [ :row |
		primitiveOf
			at: (row at: 1) , ((row at: 2) ifTrue: [ ' class' ] ifFalse: [ '' ]) , '>>' , (row at: 3)
			put: (row at: 4) ].
	primitiveOf at: 'AthensCairoCanvas>>getScaledFont' put: 'primitiveGetScaledFont'.
	primitiveOf at: 'AthensCairoPathBuilder>>copyPath' put: 'primitiveBuilderCopyPath'.
	primitiveOf removeKey: 'AthensCairoPath class>>primDestroyPath:'.
	"getCurrentPoint calls its callout primGetCurrentPointX:Y:"
	primitiveOf removeKey: 'AthensCairoCanvas>>getCurrentPoint'.
	primitiveOf at: 'AthensCairoCanvas>>primGetCurrentPointX:Y:' put: 'primitiveGetCurrentPoint'.
	failures := OrderedCollection new.
	references := self referenceCalls.
	self setMode: #basic.
	self scenes paritySceneNames do: [ :name |
		| reference calls expected |
		reference := references at: name.
		calls := self callsOf: name.
		expected := Dictionary new.
		primitiveOf keysAndValuesDo: [ :method :prim |
			| fellBack |
			"the calls of the known fallbacks went through the FFI copy, not the primitive"
			fellBack := (calls at: 2) occurrencesOf: (self ffiCopyNameOf: method).
			expected at: prim put: (expected at: prim ifAbsent: [ 0 ]) + ((reference at: 2) occurrencesOf: method) - fellBack ].
		expected keysAndValuesDo: [ :prim :n |
			| got |
			got := (calls at: 4) at: prim ifAbsent: [ 0 ].
			got = n ifFalse: [
				failures add: name , ' ' , prim , ' ' , got printString , ' (ffi calls ' , n printString , ')' ] ] ].
	self assert: failures isEmpty description: [ 'primitive calls differ: ' , failures asArray printString ]
]

{ #category : 'tests' }
CairoPluginCallCountTest >> testEveryBasicPatchReachesItsPrimitive [
	"In #basic every patched method of the group, sent once on what Athens passes, makes one successful call of the primitive its row names and the cairo calls its row names, and leaves what its ffi copy leaves: a patch wired to another primitive fails here even when no scene sends it"

	| failures |
	self skipUnlessImplemented: #( #basic ).
	self setMode: #basic.
	failures := OrderedCollection new.
	self wiringRows do: [ :row | failures addAll: (self wiringFailuresOf: row) ].
	self assert: failures isEmpty description: [ 'wiring: ' , failures asArray printString ]
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringRows [
	"The rows of #basic: the generated patches of the table and the two mirror patches, { className. isMeta. selector. primitive name. cairo functions }"

	^ CairoPluginInstaller basicTable , #(
	  #( #AthensCairoCanvas false #getScaledFont 'primitiveGetScaledFont' #( 'cairo_get_scaled_font' ) )
	  #( #AthensCairoPathBuilder false #copyPath 'primitiveBuilderCopyPath' #( 'cairo_copy_path' ) ) )
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringNameOf: row [

	^ (row at: 1) , ((row at: 2) ifTrue: [ ' class>>' ] ifFalse: [ '>>' ]) , (row at: 3)
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringFailuresOf: row [
	"What is wrong with the patch of row: its primitive, its cairo calls, or what it leaves compared with its ffi copy"

	| name cls current patched copy failures expected primitives |
	name := self wiringNameOf: row.
	cls := CairoPluginInstaller targetClassOf: row.
	current := cls compiledMethodAt: (row at: 3) ifAbsent: [ nil ].
	(CairoPluginInstaller isPatch: current) ifFalse: [
		((#( #lock #unlock ) includes: (row at: 3)) and: [ CairoPluginInstaller missingOptionalSymbols notEmpty ])
			ifTrue: [ ^ #(  ) ].
		^ { name , ': not patched' } ].
	(self wiringScenarios includesKey: name) ifFalse: [ ^ { name , ': no scenario' } ].
	failures := OrderedCollection new.
	patched := self wiringRun: row selector: (row at: 3).
	copy := self wiringRun: row selector: (CairoPluginInstaller ffiSelectorFor: (row at: 3)).
	"one successful call, of the primitive of the row (the finalization of a path, which the garbage collector may start during any call, destroys it through the patch of #primDestroyPath:: those calls are left out, as the destroy functions)"
	primitives := (patched at: 2) associations select: [ :a |
		              a value > 0 and: [ a key ~= 'primitivePathDestroy' or: [ a key = (row at: 4) ] ] ].
	(primitives size = 1 and: [
		 primitives first key = (row at: 4) and: [
			 primitives first value = 1 or: [ (row at: 4) = 'primitivePathDestroy' ] ] ]) ifFalse: [
			failures add: name , ': primitives ' , (primitives collect: [ :a | a key , '=' , a value printString ]) asArray printString
				, ' instead of ' , (row at: 4) ].
	"the cairo functions of the row, and no other"
	expected := (row at: 5) asSet.
	(patched at: 3) keysAndValuesDo: [ :f :n |
		((f endsWith: '_destroy') and: [ (expected includes: f) not ]) ifFalse: [
			(expected includes: f) = (n > 0) ifFalse: [
				failures add: name , ': ' , f , ' called ' , n printString , ' times' ] ] ].
	"the copy goes through the FFI"
	((copy at: 2) associations anySatisfy: [ :a | a value > 0 and: [ a key ~= 'primitivePathDestroy' ] ]) ifTrue: [
		failures add: name , ': its ffi copy called a primitive' ].
	(patched at: 1) = (copy at: 1) ifFalse: [
		failures add: name , ': leaves ' , (patched at: 1) printString , ', its ffi copy ' , (copy at: 1) printString ].
	^ failures
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringRun: row selector: aSelector [
	"Make the call of the scenario of row through aSelector (the patch or its ffi copy) on a new 16 x 16 surface: { what it left. the successful calls of the drawing primitives during the call. the plugin's cairo calls during the call }"

	| scenario surface result primitives functions |
	scenario := self wiringScenarios at: (self wiringNameOf: row).
	surface := AthensCairoSurface extent: 16 @ 16.
	surface drawDuring: [ :c |
		| fx renderer |
		c setFont: self scenes font.
		c setPaint: Color black.
		renderer := c instVarNamed: #fontRenderer.
		fx := Dictionary new.
		fx
			at: #canvas put: c;
			at: #builder put: (c surface instVarNamed: #builder);
			at: #renderer put: renderer;
			at: #font put: (renderer instVarNamed: #font).
		result := scenario value: fx value: [ :receiver :arguments |
			          | answer |
			          CairoPlugin resetCounters.
			          answer := receiver perform: aSelector withArguments: arguments asArray.
			          primitives := CairoPluginTestSupport drawingPrimitiveCounters.
			          functions := CairoPlugin counters.
			          answer ] ].
	^ { result. primitives. functions }
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringValue: anObject in: fx [
	"anObject, comparable between two fixtures: the role of a fixture object, a number, a point, the address of a scaled font, a class name"

	fx keysAndValuesDo: [ :k :v | v == anObject ifTrue: [ ^ k ] ].
	anObject == (fx at: #canvas) surface ifTrue: [ ^ #surface ].
	anObject == (fx at: #canvas) paintMode ifTrue: [ ^ #paintMode ].
	(anObject isNumber or: [ anObject isPoint ]) ifTrue: [ ^ anObject ].
	(anObject isKindOf: CairoScaledFont) ifTrue: [
		^ #scaledFont -> (CairoPluginTestSupport handleOf: anObject) asInteger ].
	anObject isBehavior ifTrue: [ ^ anObject name ].
	^ anObject class name
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringCanvasState: answer in: fx [
	"The answer, the cairo state and the pixels of the canvas of fx, then the pixels once its current path and a rectangle are filled with its source and stroked translucent (its source, clip, path and matrix show)"

	| c state |
	c := fx at: #canvas.
	state := OrderedCollection new.
	state
		add: (self wiringValue: answer in: fx);
		add: ((CairoPluginTestSupport stateOf: c) reject: [ :a | a key = #scaledFont ]);
		add: (CairoPluginTestSupport bytesOf: c surface).
	c primRectangleX: 3 y: 3 width: 10 height: 10.
	c fillPreserve.
	c primSetSourceR: 0 g: 0.5 b: 1 a: 0.5.
	c stroke.
	state add: (CairoPluginTestSupport bytesOf: c surface).
	^ state asArray
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringDoubles: anArray [

	| bytes |
	bytes := ByteArray new: anArray size * 8.
	anArray doWithIndex: [ :d :i | bytes doubleAt: i - 1 * 8 + 1 put: d asFloat ].
	^ bytes
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringGlyphsIn: fx [
	"The glyphs of 'abc' in the font of fx at 2 @ 12 (3 cairo_glyph_t, 72 bytes), made through the FFI"

	| ptr num glyphs |
	ptr := ExternalAddress new.
	num := ByteArray new: 4.
	num unsignedLongAt: 1 put: 3.
	(fx at: #renderer)
		ffiConvertString: 'abc' asByteArray
		len: 3
		ofFont: (fx at: #font)
		toGlyphs: ptr
		numGlyphs: num
		x: 2.0
		y: 12.0.
	glyphs := ByteArray new: 72.
	LibC memCopy: ptr to: glyphs size: 72.
	(fx at: #renderer) ffiFreeGlyphs: ptr.
	^ glyphs
]

{ #category : 'wiring' }
CairoPluginCallCountTest >> wiringScenarios [
	"Method name -> [ :fx :send | ... ]: prepare the call of that patched method of #basic on the canvas, builder, font and renderer of fx, make it with send ([ :receiver :arguments | ... ], which counts the plugin's calls during it) and answer what it left, to compare with the call of the ffi copy"

	| d canvas builder matrix font renderer path |
	d := Dictionary new.
	canvas := [ :setup :arguments |
	          [ :fx :send |
	          | c |
	          c := fx at: #canvas.
	          setup value: c value: fx.
	          self wiringCanvasState: (send value: c value: (arguments value: fx)) in: fx ] ].
	builder := [ :setup :arguments |
	           [ :fx :send |
	           | b |
	           b := fx at: #builder.
	           setup value: b value: fx.
	           self wiringCanvasState: (send value: b value: arguments) in: fx ] ].
	matrix := [ :arguments :more |
	          [ :fx :send |
	          | m args answer |
	          m := AthensCairoMatrix new.
	          m initx: 1 y: 2 sx: 3 sy: 4 shx: 0.5 shy: 0.25.
	          args := arguments value.
	          answer := send value: m value: args.
	          { self wiringValue: answer in: fx. m sx. m shx. m x. m shy. m sy. m y. more value: args } ] ].
	font := [ :arguments :more :after |
	        [ :fx :send |
	        | f args answer left |
	        f := fx at: #font.
	        args := arguments value: fx.
	        answer := send value: f value: args.
	        left := { self wiringValue: answer in: fx. more value: args }.
	        after value: f.
	        left ] ].
	renderer := [ :receiver |
	            { [ :fx :send |
	              | ptr num answer left |
	              ptr := ExternalAddress new.
	              num := ByteArray new: 4.
	              num unsignedLongAt: 1 put: 3.
	              answer := send value: (receiver value: fx) value: { 'abc' asByteArray. 3. fx at: #font. ptr. num. 2.0. 12.0 }.
	              left := { self wiringValue: answer in: fx. num unsignedLongAt: 1. (ByteArray new: 72) in: [ :g | LibC memCopy: ptr to: g size: 72. g ] }.
	              (fx at: #renderer) ffiFreeGlyphs: ptr.
	              left ].
	              [ :fx :send |
	              | ptr num |
	              ptr := ExternalAddress new.
	              num := ByteArray new: 4.
	              num unsignedLongAt: 1 put: 3.
	              (fx at: #renderer) ffiConvertString: 'abc' asByteArray len: 3 ofFont: (fx at: #font) toGlyphs: ptr numGlyphs: num x: 0.0 y: 0.0.
	              { self wiringValue: (send value: (receiver value: fx) value: { ptr }) in: fx } ] } ].
	path := [ :c | c primRectangleX: 2 y: 2 width: 6 height: 6 ].
	"AthensCairoCanvas"
	#( #newPath #fill #fillPreserve #stroke #primClip ) do: [ :sel |
		d at: 'AthensCairoCanvas>>' , sel put: (canvas value: [ :c :fx | path value: c ] value: [ :fx | #(  ) ]) ].
	d at: 'AthensCairoCanvas>>primPaint' put: (canvas value: [ :c :fx | c primSetSourceR: 1 g: 0 b: 0 a: 0.75 ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>primSaveState' put: (canvas value: [ :c :fx | path value: c ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>primRestoreState' put: (canvas value: [ :c :fx | c primSaveState; primSetLineWidth: 7; primSetSourceR: 0 g: 1 b: 0 a: 1 ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>resetClip' put: (canvas value: [ :c :fx | path value: c. c primClip ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>setPathMatrix' put: (canvas value: [ :c :fx | c pathTransform translateBy: 3 @ 2 ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>setPathMatrix:' put: (canvas value: [ :c :fx | ] value: [ :fx |
		 { AthensCairoMatrix new initx: 3 y: 4 sx: 2 sy: 1.5 shx: 0 shy: 0; yourself } ]).
	d at: 'AthensCairoCanvas>>primSetSourceR:g:b:a:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 0.25 0.5 0.75 0.875 ) ]).
	d at: 'AthensCairoCanvas>>primSetSource:' put: (canvas value: [ :c :fx | ] value: [ :fx |
		 { (fx at: #canvas) surface createLinearGradient: { 0 -> Color red. 1 -> Color blue } start: 0 @ 0 stop: 16 @ 0 } ]).
	d at: 'AthensCairoCanvas>>primResetDashes:' put: (canvas value: [ :c :fx |
		 c primSetDashesLengths: (self wiringDoubles: #( 2 1 )) count: 2 offset: 0.5 ] value: [ :fx | #( 1.5 ) ]).
	d at: 'AthensCairoCanvas>>primSetDashesLengths:count:offset:' put: (canvas value: [ :c :fx | ] value: [ :fx |
		 { self wiringDoubles: #( 2 1 ). 2. 0.5 } ]).
	d at: 'AthensCairoCanvas>>primRectangleX:y:width:height:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 2 3 5.5 4 ) ]).
	d at: 'AthensCairoCanvas>>primSetLineWidth:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 3.5 ) ]).
	d at: 'AthensCairoCanvas>>primSetLineJoin:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 1 ) ]).
	d at: 'AthensCairoCanvas>>primSetLineCap:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 2 ) ]).
	d at: 'AthensCairoCanvas>>loadPath:' put: (canvas value: [ :c :fx | ] value: [ :fx |
		 { (fx at: #canvas) createPath: [ :b | b absolute; moveTo: 1 @ 1; lineTo: 9 @ 12; lineTo: 3 @ 14 ] } ]).
	d at: 'AthensCairoCanvas>>getCurrentPoint' put: (canvas value: [ :c :fx | c primRectangleX: 1.5 y: 2 width: 3 height: 4 ] value: [ :fx | #(  ) ]).
	d at: 'AthensCairoCanvas>>setAA:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 2 ) ]).
	d at: 'AthensCairoCanvas>>setFillRule:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 1 ) ]).
	d at: 'AthensCairoCanvas>>setScaledFont:' put: (canvas value: [ :c :fx | ] value: [ :fx | { fx at: #font } ]).
	d at: 'AthensCairoCanvas>>showGlyphs:size:' put: (canvas value: [ :c :fx | c setScaledFont: (fx at: #font) ] value: [ :fx |
		 { self wiringGlyphsIn: fx. 3 } ]).
	d at: 'AthensCairoCanvas>>primSetFontSize:' put: (canvas value: [ :c :fx | ] value: [ :fx | #( 9.5 ) ]).
	d at: 'AthensCairoCanvas>>textPath:' put: (canvas value: [ :c :fx |
		 c setScaledFont: (fx at: #font).
		 (fx at: #builder) moveToX: 2 Y: 12 ] value: [ :fx | { 'ab' asByteArray , #[ 0 ] } ]).
	d at: 'AthensCairoCanvas>>getScaledFont' put: (canvas value: [ :c :fx | c setScaledFont: (fx at: #font) ] value: [ :fx | #(  ) ]).
	"AthensCairoPathBuilder"
	d at: 'AthensCairoPathBuilder>>moveToX:Y:' put: (builder value: [ :b :fx | ] value: #( 3 4.5 )).
	d at: 'AthensCairoPathBuilder>>lineToX:Y:' put: (builder value: [ :b :fx | b moveToX: 1 Y: 1 ] value: #( 12 13 )).
	d at: 'AthensCairoPathBuilder>>primCurveViaX:Y:viaX:Y:toX:Y:' put: (builder value: [ :b :fx | b moveToX: 1 Y: 1 ] value: #( 1 12 8 2 14 14 )).
	d at: 'AthensCairoPathBuilder>>closePath' put: (builder value: [ :b :fx | b moveToX: 1 Y: 1; lineToX: 12 Y: 3; lineToX: 6 Y: 14 ] value: #(  )).
	d at: 'AthensCairoPathBuilder>>newPath' put: (builder value: [ :b :fx | b moveToX: 1 Y: 1; lineToX: 12 Y: 3; lineToX: 6 Y: 14 ] value: #(  )).
	d at: 'AthensCairoPathBuilder>>arcCenterX:centerY:radius:startAngle:endAngle:' put: (builder value: [ :b :fx | ] value: #( 8 8 5 0 3 )).
	d at: 'AthensCairoPathBuilder>>arcNegativeCenterX:centerY:radius:startAngle:endAngle:' put: (builder value: [ :b :fx | ] value: #( 8 8 5 0 3 )).
	d at: 'AthensCairoPathBuilder>>copyPath' put: [ :fx :send |
		| b answer |
		b := fx at: #builder.
		b moveToX: 1 Y: 1; lineToX: 12 Y: 3.
		answer := send value: b value: #(  ).
		AthensCairoPath ffiPrimDestroyPath: (CairoPluginTestSupport handleOf: answer).
		answer instVarNamed: #handle put: ExternalAddress new.
		{ self wiringValue: answer in: fx } ].
	d at: 'AthensCairoPath class>>primDestroyPath:' put: [ :fx :send |
		| b p answer |
		b := fx at: #builder.
		b moveToX: 1 Y: 1; lineToX: 12 Y: 3.
		p := b ffiCopyPath.
		answer := send value: AthensCairoPath value: { CairoPluginTestSupport handleOf: p }.
		p instVarNamed: #handle put: ExternalAddress new.
		{ self wiringValue: answer in: fx } ].
	"AthensCairoMatrix"
	d at: 'AthensCairoMatrix>>initx:y:sx:sy:shx:shy:' put: (matrix value: [ #( 1.5 2 3 4 5 6 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primLoadIdentity' put: (matrix value: [ #(  ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primTranslateX:Y:' put: (matrix value: [ #( 3 4 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primScaleX:Y:' put: (matrix value: [ #( 2 3 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primRotateByRadians:' put: (matrix value: [ #( 0.5 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primMultiplyBy:' put: (matrix value: [
		 { AthensCairoMatrix new initx: 1 y: 1 sx: 2 sy: 1 shx: 0.25 shy: 0; yourself } ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>invert' put: (matrix value: [ #(  ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primTransformX:Y:' put: (matrix value: [
		 { self wiringDoubles: #( 1.5 ). self wiringDoubles: #( -2 ) } ] value: [ :args |
		 args collect: [ :b | b doubleAt: 1 ] ]).
	d at: 'AthensCairoMatrix>>primSetTranslateX:Y:' put: (matrix value: [ #( 7 -4 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primSetScaleX:Y:' put: (matrix value: [ #( 2.5 3 ) ] value: [ :args | nil ]).
	d at: 'AthensCairoMatrix>>primSetRotationInRadians:' put: (matrix value: [ #( 0.7 ) ] value: [ :args | nil ]).
	"AthensCairoPaintMode, AthensCairoSurface"
	d at: 'AthensCairoPaintMode>>getOperator' put: [ :fx :send |
		{ self wiringValue: (send value: (fx at: #canvas) paintMode value: #(  )) in: fx } ].
	d at: 'AthensCairoPaintMode>>setOperator:' put: [ :fx :send |
		self wiringCanvasState: (send value: (fx at: #canvas) paintMode value: #( 2 )) in: fx ].
	d at: 'AthensCairoSurface>>flush' put: [ :fx :send |
		(fx at: #canvas) primRectangleX: 2 y: 2 width: 6 height: 6; fill.
		self wiringCanvasState: (send value: (fx at: #canvas) surface value: #(  )) in: fx ].
	"CairoScaledFont"
	d at: 'CairoScaledFont>>lock' put: (font value: [ :fx | #(  ) ] value: [ :args | nil ] value: [ :f | f ffiUnlock ]).
	d at: 'CairoScaledFont>>unlock' put: [ :fx :send |
		(fx at: #font) ffiLock.
		{ self wiringValue: (send value: (fx at: #font) value: #(  )) in: fx } ].
	d at: 'CairoScaledFont>>getExtentsOfGlyphs:ofLength:into:' put: (font
		 value: [ :fx | { self wiringGlyphsIn: fx. 3. CairoTextExtents new } ]
		 value: [ :args | (CairoPluginTestSupport handleOf: args last) copy ]
		 value: [ :f | ]).
	d at: 'CairoScaledFont>>getExtentsOf:into:' put: (font
		 value: [ :fx | { 'abc' asByteArray , #[ 0 ]. CairoTextExtents new } ]
		 value: [ :args | (CairoPluginTestSupport handleOf: args last) copy ]
		 value: [ :f | ]).
	d at: 'CairoScaledFont>>getExtents:' put: (font
		 value: [ :fx | { CairoFontExtents new } ]
		 value: [ :args | (CairoPluginTestSupport handleOf: args last) copy ]
		 value: [ :f | ]).
	"CairoFreetypeFontRenderer, CairoFontMetricsProvider"
	{ 'CairoFreetypeFontRenderer' -> [ :fx | fx at: #renderer ]. 'CairoFontMetricsProvider' -> [ :fx | CairoFontMetricsProvider basicNew ] } do: [ :a |
		| blocks |
		blocks := renderer value: a value.
		d at: a key , '>>convertString:len:ofFont:toGlyphs:numGlyphs:x:y:' put: blocks first.
		d at: a key , '>>freeGlyphs:' put: blocks last ].
	^ d
]
