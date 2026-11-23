"
I am the drawings that the tests and the benchmark of the CairoPlugin make with Athens: each scene is a name and a block taking an `AthensCairoCanvas`, run on a white surface by `run:`.

## `benchScenes`

The workloads of the benchmark (the scenes of the design's `bench.st`, with the same data: `Random seed: 42`, the same counts times `scale`):

- `a-polyline` (one path of many line segments, stroked),
- `a2-lines` (many two-point paths, stroked: Roassal's edges),
- `b-rects` (rectangles filled and stroked),
- `c-bezier` (Bezier ellipses, filled),
- `d-transforms` (a rectangle per path transform),
- `e-text` (short strings, `drawString:`),

and the text variants of the SimdUTF encoding:

- `e-text-wide` (the same strings with one character outside Latin-1, WideStrings)
- and `e-text-long` (strings of 2000 characters).

## `roassalScene` (`f-roassal`)

A Roassal graph of boxes, ellipses, lines and labels drawn by `RSAthensRenderer`; `roassalCanvas` builds the graph (the same at each call) for the benchmark, which renders it with `renderRoassal:on:`.

## `targetedScenes`

Small scenes aimed at one path of the plugin each:

- rectangles of Integers, Floats and both,
- translucent colors,
- stroke widths, joins and caps,
- dashes (nil, empty, an Array),
- arcs and curves,
- nested clips,
- path transforms,
- paint modes,
- gradients (pattern paints, through the FFI),
- the fill rule,
- Latin-1 text,
- the empty string,
- ByteSymbols,
- WideStrings and WideSymbols of several scripts,
- long strings,
- Roassal labels (glyphs) and bordered labels (`textPath:`).

## `paritySceneNames`/`sceneNamed:`

All of them (the benchmark ones and the targeted ones), for the pixel parity of the modes.

## Size and scale

The scenes are drawn in a space of 1000 x 1000: a surface of another `size` is scaled to it. The counts of the benchmark scenes are `scale` times those of `bench.st` (`scale: 0.05` for the tests, at least 1 of each). `fromEnvironment` reads `CP_SCENE_SCALE` and `CP_SCENE_SIZE`.
"
Class {
	#name : 'CairoPluginScenes',
	#superclass : 'Object',
	#instVars : [
		'scale',
		'size',
		'points',
		'palette',
		'rects',
		'ellipses',
		'strings',
		'roassalNumbers',
		'font',
		'prepared'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'instance creation' }
CairoPluginScenes class >> fromEnvironment [
	"The scenes at the scale CP_SCENE_SCALE (0.05 by default) on surfaces of CP_SCENE_SIZE pixels (1000 by default)"

	| env |
	env := OSEnvironment current.
	^ self
		  scale: (env at: 'CP_SCENE_SCALE' ifAbsent: [ '0.05' ]) asNumber
		  size: (env at: 'CP_SCENE_SIZE' ifAbsent: [ '1000' ]) asNumber
]

{ #category : 'instance creation' }
CairoPluginScenes class >> scale: aNumber [

	^ self scale: aNumber size: 1000
]

{ #category : 'instance creation' }
CairoPluginScenes class >> scale: aNumber size: anInteger [

	^ self new setScale: aNumber size: anInteger
]

{ #category : 'scenes - benchmark' }
CairoPluginScenes >> benchSceneNames [

	^ self benchScenes collect: [ :each | each key ]
]

{ #category : 'scenes - benchmark' }
CairoPluginScenes >> benchScenes [
	"The workloads of the benchmark: name -> [ :canvas | ... ] (see the class comment)"

	| lines |
	self prepare.
	lines := OrderedCollection new.
	lines add: 'a-polyline' -> [ :c |
		| path |
		path := c createPath: [ :b |
			        b
				        absolute;
				        moveTo: points first.
			        2 to: points size do: [ :i | b lineTo: (points at: i) ] ].
		c setStrokePaint: Color black.
		c drawShape: path ].
	lines add: 'a2-lines' -> [ :c |
		1 to: points size - 4 by: 4 do: [ :i |
			| path |
			path := c createPath: [ :b |
				        b
					        absolute;
					        moveTo: (points at: i);
					        lineTo: (points at: i + 4) ].
			(c setStrokePaint: (palette at: i \\ 64 + 1)) width: 1.0.
			c drawShape: path ] ].
	lines add: 'b-rects' -> [ :c |
		rects doWithIndex: [ :r :i |
			c setPaint: (palette at: i \\ 64 + 1).
			c drawShape: r.
			c setStrokePaint: (palette at: i * 7 \\ 64 + 1).
			c drawShape: r ] ].
	lines add: 'c-bezier' -> [ :c |
		ellipses doWithIndex: [ :e :i |
			c setPaint: (palette at: i \\ 64 + 1).
			c drawShape: (self ellipsePath: e on: c) ] ].
	lines add: 'd-transforms' -> [ :c |
		| unit |
		unit := -5 @ -5 corner: 5 @ 5.
		1 to: (self count: 20000) do: [ :i |
			| r |
			r := rects at: i - 1 \\ rects size + 1.
			c pathTransform restoreAfter: [
				c pathTransform
					translateBy: r origin;
					rotateByDegrees: i \\ 360;
					scaleBy: 1.5.
				c setPaint: (palette at: i \\ 64 + 1).
				c drawShape: unit ] ] ].
	lines add: 'e-text' -> [ :c | self drawStrings: strings on: c ].
	lines add: 'e-text-wide' -> [ :c | self drawStrings: self wideStrings on: c ].
	lines add: 'e-text-long' -> [ :c | self drawLongStrings: self longStrings on: c ].
	^ lines asArray
]

{ #category : 'accessing' }
CairoPluginScenes >> count: anInteger [
	"anInteger (a count of bench.st) at my scale, at least 1"

	^ (anInteger * scale) rounded max: 1
]

{ #category : 'scenes - helpers' }
CairoPluginScenes >> drawLongStrings: someStrings on: c [

	c setFont: self font.
	c setPaint: Color black.
	someStrings doWithIndex: [ :s :i |
		c pathTransform restoreAfter: [
			c pathTransform translateBy: 0 @ (i * 13 \\ 1000).
			c drawString: s ] ]
]

{ #category : 'scenes - helpers' }
CairoPluginScenes >> drawStrings: someStrings on: c [

	c setFont: self font.
	c setPaint: Color black.
	someStrings doWithIndex: [ :s :i |
		| r |
		r := rects at: i - 1 \\ rects size + 1.
		c pathTransform restoreAfter: [
			c pathTransform translateBy: r origin.
			c drawString: s ] ]
]

{ #category : 'scenes - helpers' }
CairoPluginScenes >> ellipsePath: e on: c [
	"A Bezier ellipse (4 cubic curves) as Roassal's buildEllipsePath: makes it, centered at e key with the half axes e value"

	| ctr hw hh |
	ctr := e key.
	hw := e value x.
	hh := e value y.
	^ c createPath: [ :b |
		  b
			  absolute;
			  moveTo: ctr - (hw @ 0).
		  b
			  curveVia: ctr x - hw @ (ctr y - (hh * 0.55))
			  and: ctr x - (hw * 0.55) @ (ctr y - hh)
			  to: ctr x @ (ctr y - hh).
		  b
			  curveVia: ctr x + (hw * 0.55) @ (ctr y - hh)
			  and: ctr x + hw @ (ctr y - (hh * 0.55))
			  to: ctr x + hw @ ctr y.
		  b
			  curveVia: ctr x + hw @ (ctr y + (hh * 0.55))
			  and: ctr x + (hw * 0.55) @ (ctr y + hh)
			  to: ctr x @ (ctr y + hh).
		  b
			  curveVia: ctr x - (hw * 0.55) @ (ctr y + hh)
			  and: ctr x - hw @ (ctr y + (hh * 0.55))
			  to: ctr x - hw @ ctr y.
		  b close ]
]

{ #category : 'accessing' }
CairoPluginScenes >> font [
	"The font of the text scenes: Source Sans Pro 10, which the stock images have (without kerning)"

	^ font ifNil: [ font := LogicalFont familyName: 'Source Sans Pro' pointSize: 10 ]
]

{ #category : 'scenes - text' }
CairoPluginScenes >> invalidWideStrings [
	"WideStrings that UTF-8 cannot encode (a surrogate, a value above U+10FFFF): stock Athens signals ZnInvalidUTF8 for them, and so must every mode"

	^ {
		  (String with: $a with: (Character value: 16rD800) with: $b).
		  (String with: $a with: (Character value: 16rDFFF)).
		  (String with: (Character value: 16r110000) with: $z) }
]

{ #category : 'scenes - text' }
CairoPluginScenes >> longStrings [
	"Strings of 2000 characters (UTF-8 longer than the 1024 bytes the text primitive encodes into on the stack): ByteStrings, and one WideString in four"

	| n |
	self prepare.
	n := (self count: 50) max: 4.
	^ (1 to: n) collect: [ :i |
		  | s |
		  s := String new: 2000 streamContents: [ :out |
			       [ out position < 2000 ] whileTrue: [
				       out nextPutAll: (strings at: out position \\ strings size + 1); space ] ].
		  s := s first: 2000.
		  i \\ 4 = 0
			  ifTrue: [ s copyReplaceAll: 'node' with: (String with: (Character value: 955) with: $o with: $d with: $e) ]
			  ifFalse: [ s ] ]
]

{ #category : 'scenes - all' }
CairoPluginScenes >> paritySceneNames [
	"Every scene whose pixels the modes must draw alike"

	^ self paritySceneNamesWithout: #(  )
]

{ #category : 'scenes - all' }
CairoPluginScenes >> paritySceneNamesWithout: excluded [

	^ ((self benchScenes , { self roassalScene } , self targetedScenes)
		   collect: [ :each | each key ]) reject: [ :each | excluded includes: each ]
]

{ #category : 'initialization' }
CairoPluginScenes >> prepare [
	"Build the data of the benchmark scenes, in the order and with the generator of bench.st (Random seed: 42)"

	| rnd lineN |
	prepared == true ifTrue: [ ^ self ].
	rnd := Random seed: 42.
	lineN := self count: 100000.
	points := Array new: lineN + 1.
	points at: 1 put: 500.0 @ 500.0.
	2 to: points size do: [ :i |
		| p q |
		p := points at: i - 1.
		q := p + ((rnd next * 10 - 5) @ (rnd next * 10 - 5)).
		q := ((q x max: 0.0) min: 1000.0) @ ((q y max: 0.0) min: 1000.0).
		points at: i put: q ].
	palette := (1 to: 64) collect: [ :i | Color h: i * 5.6 s: 0.8 v: 0.9 ].
	rects := (1 to: (self count: 20000)) collect: [ :i |
		         | o |
		         o := rnd next * 980 @ (rnd next * 980).
		         o extent: rnd next * 18 + 2 @ (rnd next * 18 + 2) ].
	ellipses := (1 to: (self count: 10000)) collect: [ :i |
		            rnd next * 960 + 20 @ (rnd next * 960 + 20)
		            -> (rnd next * 15 + 3 @ (rnd next * 15 + 3)) ].
	strings := (1 to: (self count: 5000)) collect: [ :i | 'node ' , i printString ].
	"the Roassal graph takes its numbers from here on, as bench.st's first Roassal scene: drawn now, so that every graph is the same"
	roassalNumbers := (1 to: 6 * (self count: 1000)) collect: [ :i | rnd next ].
	prepared := true
]

{ #category : 'scenes - text' }
CairoPluginScenes >> randomWideStrings: n seed: anInteger [
	"n random WideStrings of 1 to 12 valid code points from several scripts (Latin-1, Latin Extended, Greek, Cyrillic, Arabic, Devanagari, CJK, symbols, emoji above U+FFFF): each also holds a character outside Latin-1, so that it is a WideString"

	| rnd ranges |
	rnd := Random seed: anInteger.
	ranges := #( #( 16r20 16r7E ) #( 16rA0 16rFF ) #( 16r100 16r17F ) #( 16r391 16r3C9 ) #( 16r410 16r44F )
	             #( 16r621 16r64A ) #( 16r905 16r939 ) #( 16r4E00 16r4E80 ) #( 16r2190 16r21FF )
	             #( 16r1F600 16r1F64F ) #( 16r10000 16r1007F ) ).
	^ (1 to: n) collect: [ :k |
		  | len s |
		  len := (rnd next * 12) floor + 1.
		  s := WideString new: len + 1.
		  1 to: len do: [ :i |
			  | r |
			  r := ranges at: (rnd next * ranges size) floor + 1.
			  s at: i put: (Character value: (r first + (rnd next * (r last - r first + 1)) floor)) ].
		  s at: len + 1 put: (Character value: 16r3BB).
		  s ]
]

{ #category : 'scenes - roassal' }
CairoPluginScenes >> renderRoassal: anRSCanvas on: aCanvas [
	"Draw anRSCanvas with RSAthensRenderer on aCanvas, an AthensCairoCanvas (inside drawDuring:)"

	| renderer |
	renderer := RSAthensRenderer new.
	(renderer respondsTo: #scale:) ifTrue: [ renderer scale: 1 ].
	renderer
		surface: aCanvas surface;
		canvas: aCanvas.
	anRSCanvas accept: renderer
]

{ #category : 'scenes - roassal' }
CairoPluginScenes >> roassalCanvas [
	"A new RSCanvas of the benchmark's graph: (count: 1000) boxes and ellipses with borders, twice as many translucent lines, a label every 10 nodes; the same graph at each call"

	| numbers next cv nodes n |
	self prepare.
	numbers := ReadStream on: roassalNumbers.
	next := [ numbers next ].
	n := self count: 1000.
	cv := RSCanvas new.
	nodes := (1 to: n) collect: [ :i |
		         | sh |
		         sh := i odd
			               ifTrue: [ RSBox new ]
			               ifFalse: [ RSEllipse new ].
		         sh
			         size: 8 + (i \\ 10);
			         color: (palette at: i \\ 64 + 1);
			         borderColor: Color black.
		         sh translateTo: next value * 1000 @ (next value * 1000).
		         sh ].
	cv addAll: nodes.
	1 to: n * 2 do: [ :i |
		cv add: (RSLine new
				 from: (nodes at: (next value * n) floor + 1);
				 to: (nodes at: (next value * n) floor + 1);
				 color: (Color gray alpha: 0.5);
				 yourself) ].
	1 to: n by: 10 do: [ :k |
		| nd |
		nd := nodes at: k.
		cv add: ((RSLabel text: 'n' , k printString)
				 translateTo: nd position;
				 yourself) ].
	cv extent: 1000 @ 1000.
	^ cv
]

{ #category : 'scenes - roassal' }
CairoPluginScenes >> roassalScene [
	"f-roassal: the benchmark's Roassal graph, built anew and drawn"

	^ 'f-roassal' -> [ :c | self renderRoassal: self roassalCanvas on: c ]
]

{ #category : 'running' }
CairoPluginScenes >> run: aBlock [
	"A new AthensCairoSurface of my size, white, on which aBlock drew with its canvas in a space of 1000 x 1000 (scaled to my size); answer the surface"

	| surface |
	surface := AthensCairoSurface extent: size @ size.
	surface drawDuring: [ :c |
		c
			setPaint: Color white;
			drawShape: (0 @ 0 extent: size @ size).
		size = 1000 ifFalse: [ c pathTransform scaleBy: size / 1000.0 ].
		aBlock value: c ].
	^ surface
]

{ #category : 'running' }
CairoPluginScenes >> runScene: aName [

	^ self run: (self sceneNamed: aName)
]

{ #category : 'accessing' }
CairoPluginScenes >> scale [

	^ scale
]

{ #category : 'scenes - all' }
CairoPluginScenes >> sceneNamed: aName [
	"The block of the scene aName (of benchScenes, roassalScene or targetedScenes)"

	^ ((self benchScenes , { self roassalScene } , self targetedScenes)
		   detect: [ :each | each key = aName ]
		   ifNone: [ self error: 'no scene ' , aName printString ]) value
]

{ #category : 'initialization' }
CairoPluginScenes >> setScale: aNumber size: anInteger [

	scale := aNumber.
	size := anInteger
]

{ #category : 'accessing' }
CairoPluginScenes >> size [

	^ size
]

{ #category : 'scenes - targeted' }
CairoPluginScenes >> targetedSceneNames [

	^ self targetedScenes collect: [ :each | each key ]
]

{ #category : 'scenes - targeted' }
CairoPluginScenes >> targetedScenes [
	"Small scenes aimed at one path of the plugin each (see the class comment)"

	| lines |
	self prepare.
	lines := OrderedCollection new.
	lines add: 'rect-integer' -> [ :c |
		1 to: 40 do: [ :i |
			| r |
			r := i * 23 \\ 900 @ (i * 37 \\ 900) corner: i * 23 \\ 900 + (i \\ 7 * 9 + 3) @ (i * 37 \\ 900 + (i \\ 5 * 11 + 2)).
			c setPaint: (palette at: i \\ 64 + 1).
			c drawShape: r.
			(c setStrokePaint: (palette at: i * 3 \\ 64 + 1)) width: i \\ 4 + 1.
			c drawShape: r ] ].
	lines add: 'rect-float' -> [ :c |
		1 to: 40 do: [ :i |
			| r |
			r := i * 23.25 \\ 900 @ (i * 37.5 \\ 900) extent: i \\ 7 * 9.125 + 3.5 @ (i \\ 5 * 11.75 + 2.25).
			c setPaint: (palette at: i \\ 64 + 1).
			c drawShape: r.
			(c setStrokePaint: (palette at: i * 5 \\ 64 + 1)) width: i \\ 3 * 0.75 + 0.5.
			c drawShape: r ] ].
	lines add: 'rect-mixed' -> [ :c |
		1 to: 40 do: [ :i |
			| r |
			r := i odd
				     ifTrue: [ i * 21 @ (i * 19.5) corner: i * 21 + 17.25 @ (i * 19.5 + 12) ]
				     ifFalse: [ i * 21.5 @ (i * 19) corner: i * 21.5 + 15 @ (i * 19 + 9.75) ].
			c setPaint: (palette at: i \\ 64 + 1).
			c drawShape: r.
			c setStrokePaint: Color black.
			c drawShape: r ] ].
	lines add: 'rect-translucent' -> [ :c |
		1 to: 30 do: [ :i |
			c setPaint: ((palette at: i \\ 64 + 1) alpha: i / 31.0).
			c drawShape: (i * 25 @ (i * 20) extent: 120 @ 80).
			c setStrokePaint: (Color black alpha: 0.5).
			c drawShape: (i * 25 @ (i * 20) extent: 120 @ 80) ] ].
	lines add: 'stroke-styles' -> [ :c |
		| joins caps |
		joins := #( #joinMiter #joinRound #joinBevel ).
		caps := #( #capButt #capRound #capSquare ).
		1 to: 9 do: [ :i |
			| sp path |
			path := c createPath: [ :b |
				        b
					        absolute;
					        moveTo: 50 + (i * 100) @ 100;
					        lineTo: 90 + (i * 100) @ 300;
					        lineTo: 30 + (i * 100) @ 350;
					        lineTo: 70 + (i * 100) @ 500 ].
			sp := c setStrokePaint: (palette at: i * 7 \\ 64 + 1).
			sp width: i * 2.
			sp perform: (joins at: i - 1 \\ 3 + 1).
			sp perform: (caps at: i - 1 // 3 + 1).
			c drawShape: path.
			c drawShape: (50 + (i * 100) @ 600 extent: 60 @ (i * 20)) ] ].
	lines add: 'dashes' -> [ :c |
		1 to: 60 do: [ :i |
			| sp r |
			r := i * 15 @ (i * 14) extent: 200 @ 60.
			sp := c setStrokePaint: (palette at: i \\ 64 + 1).
			sp width: 1 + (i \\ 3).
			i \\ 4 = 0 ifTrue: [ sp dashes: #( 4 2 ) offset: 1 ].
			i \\ 4 = 1 ifTrue: [ sp dashes: #(  ) offset: 0 ].
			i \\ 4 = 2 ifTrue: [ sp dashes: #( 6.5 2.25 1 3 ) offset: 2.5 ].
			c drawShape: r.
			i odd ifTrue: [
				c drawShape: (c createPath: [ :b |
						  b
							  absolute;
							  moveTo: r origin;
							  lineTo: r corner;
							  lineTo: r topRight ]) ] ] ].
	lines add: 'paths-arcs-curves' -> [ :c |
		1 to: 12 do: [ :i |
			| path |
			path := c createPath: [ :b |
				        b
					        absolute;
					        moveTo: i * 70 @ 100.
				        b
					        arcAround: i * 70 + 30 @ 150
					        radius: 20 + i
					        startAngle: 0
					        endAngle: Float pi * i / 6.
				        b cwArcTo: i * 70 + 10 @ 250 angle: Float pi / 3.
				        b ccwArcTo: i * 70 + 40 @ 300 angle: Float pi / 4.
				        b curveVia: i * 70 + 60 @ 320 to: i * 70 + 20 @ 380.
				        b
					        curveVia: i * 70 @ 400
					        and: i * 70 + 50 @ 420
					        to: i * 70 + 30 @ 460.
				        b relative.
				        b lineTo: 15 @ 10.
				        b moveTo: 5 @ 5.
				        b lineTo: -10 @ 20.
				        b close ].
			c setPaint: (palette at: i * 5 \\ 64 + 1).
			c drawShape: path.
			(c setStrokePaint: Color black) width: 1.5.
			c drawShape: path ] ].
	lines add: 'clip-nested' -> [ :c |
		c clipBy: (100 @ 100 corner: 700 @ 700) during: [
			c setPaint: Color red.
			c drawShape: (0 @ 0 extent: 500 @ 500).
			c clipBy: (300 @ 300 corner: 900 @ 600) during: [
				c setPaint: (Color blue alpha: 0.6).
				c drawShape: (c createPath: [ :b |
						 b
							 absolute;
							 moveTo: 250 @ 250;
							 lineTo: 800 @ 350;
							 lineTo: 400 @ 800;
							 close ]) ].
			c setPaint: Color green.
			c drawShape: (600 @ 600 extent: 300 @ 300) ].
		c setPaint: Color yellow.
		c drawShape: (650 @ 50 extent: 100 @ 900) ].
	lines add: 'transforms' -> [ :c |
		1 to: 24 do: [ :i |
			c pathTransform restoreAfter: [
				| m |
				c pathTransform translateBy: i * 37 @ (i * 29).
				c pathTransform rotateByDegrees: i * 15.
				c pathTransform scaleBy: 0.5 + (i / 8.0).
				m := AthensAffineTransform new.
				m translateBy: 3 @ 4.
				m scaleBy: 1.25.
				c pathTransform multiplyBy: m.
				i \\ 3 = 0 ifTrue: [
					c pathTransform invert.
					c pathTransform invert ].
				c setPaint: (palette at: i \\ 64 + 1).
				c drawShape: (-10 @ -10 corner: 10 @ 10).
				c setStrokePaint: Color black.
				c drawShape: (self ellipsePath: 0 @ 0 -> (8 @ 5) on: c) ] ] ].
	lines add: 'paint-modes' -> [ :c |
		#( #over #source #add #xor #multiply #screen #darken #lighten #difference ) doWithIndex: [ :mode :i |
			c setPaint: (palette at: i * 7 \\ 64 + 1).
			c drawShape: (i * 90 @ 100 extent: 120 @ 400).
			c paintMode restoreAfter: [
				c paintMode perform: mode.
				c setPaint: ((palette at: i * 3 \\ 64 + 1) alpha: 0.7).
				c drawShape: (i * 90 + 40 @ 300 extent: 120 @ 300) ] ] ].
	lines add: 'gradients' -> [ :c |
		| linear radial |
		linear := c surface
			          createLinearGradient: {
					          (0 -> Color red).
					          (0.5 -> Color green).
					          (1 -> Color blue) }
			          start: 100 @ 100
			          stop: 500 @ 300.
		radial := c surface
			          createRadialGradient: {
					          (0 -> Color white).
					          (1 -> (Color black alpha: 0.5)) }
			          center: 600 @ 600
			          radius: 200.
		c setPaint: linear.
		c drawShape: (100 @ 100 corner: 500 @ 300).
		c drawShape: (self ellipsePath: 300 @ 500 -> (150 @ 80) on: c).
		c setPaint: radial.
		c drawShape: (400 @ 400 corner: 800 @ 800).
		(c setStrokePaint: linear) width: 8.
		c drawShape: (100 @ 700 corner: 300 @ 900) ].
	lines add: 'fill-rule' -> [ :c |
		| path |
		path := c createPath: [ :b |
			        b
				        absolute;
				        moveTo: 500 @ 100;
				        lineTo: 700 @ 800;
				        lineTo: 200 @ 350;
				        lineTo: 800 @ 350;
				        lineTo: 300 @ 800;
				        close ].
		c setPaint: Color orange.
		c drawShape: path.
		c fillRuleEvenOdd.
		c pathTransform restoreAfter: [
			c pathTransform translateBy: 100 @ 50.
			c setPaint: (Color blue alpha: 0.5).
			c drawShape: path ].
		c fillRuleWinding ].
	lines add: 'surface-clear' -> [ :c |
		c setPaint: Color red.
		c drawShape: (0 @ 0 extent: 300 @ 300).
		c surface clear: (Color green alpha: 0.25).
		c setPaint: Color blue.
		c drawShape: (100 @ 100 extent: 300 @ 300) ].
	lines add: 'text-latin1' -> [ :c |
		self drawTexts: {
				'caf' , (String with: (Character value: 233)) , ' na' , (String with: (Character value: 239)) , 've'.
				(String withAll: ((160 to: 255) collect: [ :k | Character value: k ])).
				'ASCII only, 0123456789 !?' } on: c ].
	lines add: 'text-empty' -> [ :c | self drawTexts: { ''. ''. 'x' } on: c ].
	lines add: 'text-symbols' -> [ :c |
		self drawTexts: {
				#aByteSymbol.
				('caf' , (String with: (Character value: 233))) asSymbol.
				#+ } on: c ].
	lines add: 'text-wide' -> [ :c | self drawTexts: self wideScripts on: c ].
	lines add: 'text-wide-symbols' -> [ :c | self drawTexts: (self wideScripts collect: [ :s | s asSymbol ]) on: c ].
	lines add: 'text-long' -> [ :c |
		c setFont: self font.
		c setPaint: Color black.
		(self longStrings first: 4) doWithIndex: [ :s :i |
			c pathTransform restoreAfter: [
				c pathTransform translateBy: 0 @ (i * 40).
				c drawString: s ] ] ].
	lines add: 'text-paints' -> [ :c |
		c setFont: self font.
		{ Color red. Color blue alpha: 0.4. Color transparent.
		  c surface createLinearGradient: { 0 -> Color red. 1 -> Color blue } start: 0 @ 0 stop: 300 @ 0 } doWithIndex: [ :p :i |
			c setPaint: p.
			c pathTransform restoreAfter: [
				c pathTransform translateBy: 20 @ (i * 40).
				c drawString: 'paint ' , i printString , ' ' , (String with: (Character value: 955)) ] ] ].
	lines add: 'roassal-labels' -> [ :c |
		| cv |
		cv := RSCanvas new.
		1 to: 12 do: [ :i |
			| label |
			label := RSLabel text: 'label ' , i printString , (i even ifTrue: [ String with: (Character value: 233) ] ifFalse: [ '' ]).
			label color: (palette at: i * 5 \\ 64 + 1).
			i \\ 3 = 0 ifTrue: [ label borderColor: Color black ].
			label translateTo: i * 70 @ (i * 60).
			cv add: label ].
		cv extent: 1000 @ 1000.
		self renderRoassal: cv on: c ].
	^ lines asArray
]

{ #category : 'scenes - helpers' }
CairoPluginScenes >> drawTexts: someStrings on: c [

	c setFont: self font.
	c setPaint: Color black.
	someStrings doWithIndex: [ :s :i |
		c pathTransform restoreAfter: [
			c pathTransform translateBy: 20 @ (i * 40).
			c drawString: s ] ]
]

{ #category : 'scenes - text' }
CairoPluginScenes >> wideScripts [
	"WideStrings of several scripts: Latin with combining marks, Greek, Cyrillic, Arabic, Hebrew, Devanagari, Chinese, Japanese, Korean, symbols, emoji above U+FFFF (the stock font lacks most of them: cairo then draws the same boxes in every mode)"

	^ #( #( 16r4C 16r6F 16r67 16r6F 16r73 16r20 16r3BB 16r3CC 16r3B3 16r3BF 16r3C2 )
	     #( 16r41F 16r440 16r438 16r432 16r435 16r442 16r20 16r43C 16r438 16r440 )
	     #( 16r645 16r631 16r62D 16r628 16r627 16r20 16r5E9 16r5DC 16r5D5 16r5DD )
	     #( 16r928 16r92E 16r938 16r94D 16r924 16r947 16r20 16r65 16r301 16r20 16r6E 16r303 )
	     #( 16r4E2D 16r6587 16r20 16r65E5 16r672C 16r8A9E 16r20 16rD55C 16rAD6D 16rC5B4 )
	     #( 16r2190 16r21D2 16r2211 16r221E 16r20 16r20AC 16r20 16r1F600 16r1F680 16r1F4A9 16r10348 ) )
		  collect: [ :codes |
			  | s |
			  s := WideString new: codes size.
			  codes doWithIndex: [ :code :i | s at: i put: (Character value: code) ].
			  s ]
]

{ #category : 'scenes - text' }
CairoPluginScenes >> wideStrings [
	"The strings of e-text with one character outside Latin-1 each (lambda): WideStrings"

	self prepare.
	^ strings collect: [ :s | s copyWith: (Character value: 955) ]
]
