"
I check criterion C2 of the CairoPlugin (`docs/CairoPlugin.md`): after each shape and text primitive (and a few one-for-one ones), the cairo state of the canvas (`CairoPluginTestSupport stateOf:`: the matrix bit for bit, the source, the line width, join and cap, the dashes, the current point, the fill rule, the operator, the font matrix, the antialiasing, the scaled font) is the state the same Athens calls leave in `#ffi` mode.

Without the plugin, or with a plugin that does not implement every group, I compare the modes it can draw, then skip myself saying so.
"
Class {
	#name : 'CairoPluginStateTest',
	#superclass : 'CairoPluginTestCase',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginStateTest >> assertStatesOf: operations [
	"Each operation (name -> [ :canvas | ... ]) leaves the #ffi state in every mode"

	| failures modes |
	modes := self comparableModes.
	failures := OrderedCollection new.
	operations do: [ :op |
		| reference |
		reference := self stateAfter: op value in: #ffi.
		modes do: [ :mode |
			| state |
			state := self stateAfter: op value in: mode.
			state = reference ifFalse: [
				failures add: op key , ' ' , mode , ': '
					, (state reject: [ :each | reference includes: each ]) printString , ' (ffi '
					, (reference reject: [ :each | state includes: each ]) printString , ')' ] ] ].
	self assert: failures isEmpty description: [ 'cairo state differs: ' , failures asArray printString ].
	self skipUnlessEveryMode: modes
]

{ #category : 'operations' }
CairoPluginStateTest >> basicOperations [

	^ {
		  (#newPathMoveTo -> [ :c |
		   c newPath.
		   c surface createPath: [ :b |
			   b
				   absolute;
				   moveTo: 3 @ 4 ] ]).
		  (#setPathMatrix -> [ :c |
		   c pathTransform
			   translateBy: 2.5 @ 3;
			   rotateByDegrees: 33.
		   c setPathMatrix ]).
		  (#sourceRGBA -> [ :c | c setSourceR: 0.1 g: 0.25 b: 1 a: 0.5 ]).
		  (#lineStyle -> [ :c |
		   c primSetLineWidth: 2.75.
		   c primSetLineJoin: 1.
		   c primSetLineCap: 2 ]).
		  (#dashes -> [ :c |
		   | buf |
		   buf := ByteArray new: 16.
		   buf doubleAt: 1 put: 3.5.
		   buf doubleAt: 9 put: 1.0.
		   c primSetDashesLengths: buf count: 2 offset: 0.5 ]).
		  (#resetDash -> [ :c | c resetDash ]).
		  (#fillRule -> [ :c | c fillRuleEvenOdd ]).
		  (#operator -> [ :c | c paintMode xor ]).
		  (#antialias -> [ :c | c setAA: 1 ]).
		  (#clip -> [ :c | c clipBy: (1 @ 1 corner: 20 @ 20) during: [ c pathTransform scaleBy: 2. c setPathMatrix ] ]).
		  (#fontSize -> [ :c |
		   c setFont: self scenes font.
		   c setFontSize: 13 ]) }
]

{ #category : 'operations' }
CairoPluginStateTest >> shapeOperations [

	| rect path stroke |
	rect := 3 @ 4.5 corner: 30 @ 25.
	path := [ :c |
	        c createPath: [ :b |
		        b
			        absolute;
			        moveTo: 5 @ 5;
			        lineTo: 50 @ 10;
			        curveVia: 40 @ 40 and: 20 @ 50 to: 10 @ 40;
			        close ] ].
	stroke := [ :c :dashes |
	          | sp |
	          sp := c setStrokePaint: (Color r: 0.2 g: 0.4 b: 0.6 alpha: 0.8).
	          sp width: 3.5.
	          sp joinRound.
	          sp capSquare.
	          dashes ifNotNil: [ sp dashes: dashes offset: 1.5 ].
	          sp ].
	^ {
		  (#fillRectangleColor -> [ :c |
		   c pathTransform translateBy: 2 @ 1.
		   c setPaint: (Color red alpha: 0.5).
		   c drawShape: rect ]).
		  (#fillRectangleIntegers -> [ :c |
		   c setPaint: Color blue.
		   c drawShape: (1 @ 2 corner: 13 @ 17) ]).
		  (#strokeRectangle -> [ :c |
		   stroke value: c value: nil.
		   c drawShape: rect ]).
		  (#strokeRectangleDashes -> [ :c |
		   stroke value: c value: #( 4 2.5 1 ).
		   c drawShape: rect ]).
		  (#strokeRectangleNoDashes -> [ :c |
		   stroke value: c value: #(  ).
		   c drawShape: rect ]).
		  (#fillPathColor -> [ :c |
		   c pathTransform scaleBy: 1.5.
		   c setPaint: Color green.
		   c drawShape: (path value: c) ]).
		  (#strokePath -> [ :c |
		   stroke value: c value: nil.
		   c drawShape: (path value: c) ]).
		  (#strokePathDashes -> [ :c |
		   stroke value: c value: #( 2 2 ).
		   c drawShape: (path value: c) ]) }
]

{ #category : 'helpers' }
CairoPluginStateTest >> stateAfter: aBlock in: aMode [

	| surface state |
	self setMode: aMode.
	surface := AthensCairoSurface extent: 64 @ 64.
	surface drawDuring: [ :c |
		aBlock value: c.
		state := CairoPluginTestSupport stateOf: c ].
	^ state
]

{ #category : 'tests' }
CairoPluginStateTest >> testBasicOperations [

	self assertStatesOf: self basicOperations
]

{ #category : 'tests' }
CairoPluginStateTest >> testShapeOperations [

	self assertStatesOf: self shapeOperations
]

{ #category : 'tests' }
CairoPluginStateTest >> testTextOperations [

	self assertStatesOf: self textOperations
]

{ #category : 'operations' }
CairoPluginStateTest >> textOperations [

	| text |
	text := [ :aString |
	        [ :c |
	        c pathTransform translateBy: 4 @ 20.
	        c setFont: self scenes font.
	        c setPaint: (Color r: 0.5 g: 0.1 b: 0.9 alpha: 0.7).
	        c drawString: aString ] ].
	^ {
		  (#byteString -> (text value: 'Athens')).
		  (#latin1 -> (text value: 'caf' , (String with: (Character value: 233)))).
		  (#byteSymbol -> (text value: #symbol)).
		  (#wideString -> (text value: (self scenes wideScripts at: 1))).
		  (#wideSymbol -> (text value: (self scenes wideScripts at: 6) asSymbol)).
		  (#empty -> (text value: '')) }
]
