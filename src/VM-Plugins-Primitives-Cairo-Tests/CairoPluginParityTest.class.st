"
I check criteria C1 and C3 of the CairoPlugin (docs/CairoPlugin.md): every scene of `CairoPluginScenes` draws the same pixels (the same bytes of the surface) in the modes `#ffi` (stock Athens), `#basic`, `#all` and `#fallback` (installed, the plugin unbound), and the patched methods answer what the stock ones answer. The text tests (Amendment A1) draw ByteStrings, ByteSymbols, WideStrings and WideSymbols of several scripts, random valid WideStrings, WideStrings that UTF-8 cannot encode (every mode signals the stock error), and the kerning path (forced: the stock fonts have no kerning).

On a VM without the plugin I compare #fallback only, and with a plugin that does not implement every group the modes it can draw; then I skip myself, saying which modes I left out.
"
Class {
	#name : 'CairoPluginParityTest',
	#superclass : 'CairoPluginTestCase',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginParityTest >> answersIn: aMode [
	"What the patched methods answer in aMode, as comparable values (identities as Booleans, numbers as their bits, classes)"

	| results surface font |
	self setMode: aMode.
	results := OrderedCollection new.
	font := self scenes font.
	surface := AthensCairoSurface extent: 60 @ 60.
	surface drawDuring: [ :c |
		| path m sp point scaledFont r tp |
		results add: #newPath -> (c newPath == c).
		results add: #fillRectangle -> ((c
				  setPaint: Color red;
				  setShape: (1 @ 1 corner: 20 @ 20);
				  draw) == surface).
		sp := c setStrokePaint: Color blue.
		results add: #strokeRectangle -> ((c
				  setShape: (2 @ 2 corner: 30 @ 25.5);
				  draw) == sp).
		path := c createPath: [ :b |
			        b
				        absolute;
				        moveTo: 5 @ 5;
				        lineTo: 40 @ 10;
				        curveVia: 50 @ 30 and: 20 @ 50 to: 10 @ 40;
				        close ].
		results add: #copyPathClass -> path class name.
		results add: #copyPathHandle -> (path getHandle notNil and: [ path getHandle isNull not ]).
		results add: #strokePath -> ((c
				  setShape: path;
				  draw) == sp).
		c setPaint: Color green.
		results add: #fillPath -> ((c
				  setShape: path;
				  draw) == surface).
		c newPath.
		c surface createPath: [ :b |
			b
				absolute;
				moveTo: 3.5 @ 7.25;
				lineTo: 11 @ 13 ].
		point := c getCurrentPoint.
		results add: #currentPoint -> {
				point class name.
				point x class name.
				point x asIEEE64BitWord.
				point y asIEEE64BitWord }.
		m := AthensCairoMatrix new.
		m
			translateBy: 3 @ 4;
			scaleBy: 2;
			rotateByDegrees: 30.
		results add: #invert -> m invert.
		results add: #inverted -> ((1 to: 6) collect: [ :i | (m getHandle doubleAt: i - 1 * 8 + 1) asIEEE64BitWord ]).
		tp := m transform: 10 @ 20.
		results add: #transformPoint -> {
				tp x asIEEE64BitWord.
				tp y asIEEE64BitWord }.
		results add: #singular -> (AthensCairoMatrix new
				 scaleBy: 0;
				 invert).
		results add: #getOperator -> c paintMode getOperator.
		results add: #setOperator -> (c paintMode add == c paintMode).
		c paintMode over.
		c setFont: font.
		c setPaint: Color black.
		r := c drawString: 'abc'.
		results add: #advanceByteString -> {
				r x asIEEE64BitWord.
				r y asIEEE64BitWord }.
		r := c drawString: (self scenes wideScripts at: 1).
		results add: #advanceWideString -> {
				r x asIEEE64BitWord.
				r y asIEEE64BitWord }.
		r := c drawString: ''.
		results add: #advanceEmpty -> {
				r x asIEEE64BitWord.
				r y asIEEE64BitWord }.
		scaledFont := c getScaledFont.
		results add: #getScaledFont -> {
				scaledFont class name.
				(CairoPluginTestSupport handleOf: scaledFont) class name.
				(CairoPluginTestSupport handleOf: scaledFont) asInteger }.
		results add: #textPath -> ((c textPath: 'ab' utf8Encoded , #[ 0 ]) == c).
		c newPath.
		results add: #flush -> (surface flush == surface) ].
	^ results asArray
]

{ #category : 'helpers' }
CairoPluginParityTest >> assertParityOf: names [
	"Each scene of names draws the bytes of #ffi in every mode the plugin implements"

	| failures modes |
	modes := self comparableModes.
	failures := OrderedCollection new.
	names do: [ :name |
		| reference |
		reference := self bytesOfScene: name in: #ffi.
		modes do: [ :mode |
			| bytes |
			bytes := self bytesOfScene: name in: mode.
			bytes = reference ifFalse: [
				failures add: name , ' ' , mode , ' '
					, (CairoPluginTestSupport quickDigestOfBytes: bytes) , ' (ffi '
					, (CairoPluginTestSupport quickDigestOfBytes: reference) , ')' ] ] ].
	self
		assert: failures isEmpty
		description: [ 'PIXELS-DIFFER: ' , failures asArray printString ].
	self skipUnlessEveryMode: modes
]

{ #category : 'helpers' }
CairoPluginParityTest >> errorsOf: someStrings in: aMode [

	| surface errors |
	self setMode: aMode.
	errors := OrderedCollection new.
	surface := AthensCairoSurface extent: 40 @ 40.
	surface drawDuring: [ :c |
		c setFont: self scenes font.
		c setPaint: Color black.
		someStrings do: [ :s | errors add: (self errorOf: [ c drawString: s ]) ] ].
	^ errors asArray
]

{ #category : 'helpers' }
CairoPluginParityTest >> stringsResultsOf: someStrings in: aMode [
	"The bytes of a surface on which each of someStrings was drawn, and the advances (bits) drawString: answered"

	| surface advances |
	self setMode: aMode.
	advances := OrderedCollection new.
	surface := AthensCairoSurface extent: 400 @ 400.
	surface drawDuring: [ :c |
		c setFont: self scenes font.
		c setPaint: Color black.
		someStrings doWithIndex: [ :s :i |
			c pathTransform restoreAfter: [
				| a |
				c pathTransform translateBy: i - 1 \\ 4 * 100 @ (i - 1 // 4 * 8 \\ 400).
				a := c drawString: s.
				advances add: {
						a x asIEEE64BitWord.
						a y asIEEE64BitWord } ] ] ].
	^ {
		  (CairoPluginTestSupport bytesOf: surface).
		  advances asArray }
]

{ #category : 'tests' }
CairoPluginParityTest >> testAnswers [
	"C3: the patched methods answer what the stock ones answer"

	| reference failures modes |
	modes := self comparableModes.
	reference := self answersIn: #ffi.
	failures := OrderedCollection new.
	modes do: [ :mode |
		(self answersIn: mode) with: reference do: [ :a :b |
			a = b ifFalse: [ failures add: mode -> { a. b } ] ] ].
	self assert: failures isEmpty description: [ 'answers differ: ' , failures asArray printString ].
	self assert: (reference detect: [ :a | a key = #newPath ]) value.
	self assert: (reference detect: [ :a | a key = #fillRectangle ]) value.
	self assert: (reference detect: [ :a | a key = #strokeRectangle ]) value.
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginParityTest >> testBenchScenes [

	self assertParityOf: self scenes benchSceneNames
]

{ #category : 'tests' }
CairoPluginParityTest >> testFillOutsideDrawDuring [
	"A fill outside drawDuring: (the surface has no current canvas) signals what stock Athens signals, in every mode"

	| reference modes errorIn |
	errorIn := [ :mode |
	           | surface canvas |
	           self setMode: mode.
	           surface := AthensCairoSurface extent: 10 @ 10.
	           surface drawDuring: [ :c | canvas := c ].
	           self errorOf: [
		           canvas
			           setPaint: Color red;
			           drawShape: (0 @ 0 extent: 5 @ 5) ] ].
	reference := errorIn value: #ffi.
	self assert: reference notNil.
	modes := self comparableModes.
	modes do: [ :mode | self assert: (errorIn value: mode) equals: reference ].
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginParityTest >> testInvalidWideStrings [
	"A WideString that UTF-8 cannot encode (a surrogate, a value above U+10FFFF): the text primitive fails before any cairo call and the stock path signals its error, in every mode"

	| strings reference modes before |
	strings := self scenes invalidWideStrings.
	reference := self errorsOf: strings in: #ffi.
	self assert: (reference allSatisfy: [ :e | e notNil ]).
	modes := self comparableModes.
	modes do: [ :mode |
		before := CairoPlugin primitiveCounters at: 'primitiveShowString' ifAbsent: [ 0 ].
		self assert: (self errorsOf: strings in: mode) equals: reference.
		self
			assert: (CairoPlugin primitiveCounters at: 'primitiveShowString' ifAbsent: [ 0 ])
			equals: before ].
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginParityTest >> testKerningPath [
	"With a font face that has kerning (forced: the stock fonts have none, and kerningLeft:right: answers 0 for them, so the pixels stay comparable), #all draws the #ffi pixels through the original renderCharacters:from:to: (the one-for-one primitives), never through the text primitive"

	| face saved reference modes before |
	face := self scenes font realFont face.
	saved := face instVarNamed: #hasKerning.
	[
	face instVarNamed: #hasKerning put: true.
	self assert: face hasKerning.
	reference := self bytesOfScene: 'text-latin1' in: #ffi.
	modes := self comparableModes.
	modes do: [ :mode |
		before := CairoPlugin primitiveCounters at: 'primitiveShowString' ifAbsent: [ 0 ].
		self assert: (self bytesOfScene: 'text-latin1' in: mode) = reference.
		self
			assert: (CairoPlugin primitiveCounters at: 'primitiveShowString' ifAbsent: [ 0 ])
			equals: before ] ] ensure: [ face instVarNamed: #hasKerning put: saved ].
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginParityTest >> testRandomWideStrings [
	"Amendment A1: for random valid WideStrings of several scripts, the text primitive (UTF-8 by simdutf) draws the pixels and answers the advances of the stock path (UTF-8 by ZnUTF8Encoder), and really draws them all (no fallback)"

	| strings reference modes before results |
	strings := self scenes randomWideStrings: 120 seed: 4242.
	reference := self stringsResultsOf: strings in: #ffi.
	modes := self comparableModes.
	modes do: [ :mode |
		before := CairoPlugin primitiveCounters at: 'primitiveShowString' ifAbsent: [ 0 ].
		results := self stringsResultsOf: strings in: mode.
		self assert: results last equals: reference last.
		self assert: results first = reference first description: 'pixels differ in mode ' , mode.
		mode = #all ifTrue: [
			self
				assert: (CairoPlugin primitiveCounters at: 'primitiveShowString') - before
				equals: strings size ] ].
	self skipUnlessEveryMode: modes
]

{ #category : 'tests' }
CairoPluginParityTest >> testRoassalScene [

	self assertParityOf: { self scenes roassalScene key }
]

{ #category : 'tests' }
CairoPluginParityTest >> testTargetedScenes [

	self assertParityOf: self scenes targetedSceneNames
]
