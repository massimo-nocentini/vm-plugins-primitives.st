"
I compare the primitives of the UtilsPlugin with their Smalltalk twins (`UtilsPluginSmalltalk`) on many random arguments: they must answer the same bits (NaNs aside, whose bits the platforms choose). I run with the plugin only.
"
Class {
	#name : 'UtilsPluginDifferentialTest',
	#superclass : 'UtilsPluginTestCase',
	#instVars : [
		'random'
	],
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'building suites' }
UtilsPluginDifferentialTest class >> testParameters [

	^ ParametrizedTestMatrix new
		  forSelector: #backend addOptions: #( #plugin );
		  yourself
]

{ #category : 'helpers' }
UtilsPluginDifferentialTest >> randomFloat [
	"Floats of every magnitude, special values and simple ones"

	| choice |
	choice := random nextInteger: 20.
	choice = 1 ifTrue: [
		^ #( 0.0 -0.0 1.0 -1.0 0.5 2.0 ) atRandom: random ].
	choice = 2 ifTrue: [
		^ { Float infinity. Float negativeInfinity. Float nan. Float fminDenormalized. Float fminNormalized. Float fmax. Float negativeZero }
			  atRandom: random ].
	choice = 3 ifTrue: [ ^ (random nextInteger: 2000) - 1000 / 8.0 ].
	^ (random next - 0.5) timesTwoPower: (random nextInteger: 2200) - 1100
]

{ #category : 'running' }
UtilsPluginDifferentialTest >> setUp [

	super setUp.
	"thousands of cases, on the Smalltalk twins too: about 15 s on the interpreter of the WebAssembly VM"
	self timeLimit: 2 minutes.
	random := Random seed: 2026
]

{ #category : 'tests' }
UtilsPluginDifferentialTest >> testDeCasteljau [

	1 to: 3000 do: [ :round |
		| points parameters byPlugin bySmalltalk |
		points := (1 to: (random nextInteger: 12)) collect: [ :index |
			          (random nextInteger: 4) = 1
				          ifTrue: [ (random nextInteger: 200) - 100 @ ((random nextInteger: 200) - 100) ]
				          ifFalse: [ (random next * 100 - 50) @ (random next * 100 - 50) ] ].
		parameters := (1 to: (random nextInteger: 8)) collect: [ :index |
			              (random nextInteger: 10) = 1
				              ifTrue: [ #( 0 1 -1 2 0.5 ) atRandom: random ]
				              ifFalse: [
					              (random nextInteger: 10) = 1
						              ifTrue: [ self randomFloat ]
						              ifFalse: [ random next * 1.4 - 0.2 ] ] ].
		byPlugin := Array new: parameters size.
		bySmalltalk := Array new: parameters size.
		self assert: (UtilsPlugin primDeCasteljau: points into: byPlugin at: parameters) notNil.
		UtilsPluginSmalltalk deCasteljau: points into: bySmalltalk at: parameters.
		byPlugin with: bySmalltalk do: [ :a :b |
			self assert: (self point: a isSameAs: b) description: [ points printString , ' at ' , parameters printString ] ] ]
]

{ #category : 'tests' }
UtilsPluginDifferentialTest >> testFma [

	1 to: 40000 do: [ :round |
		| x y z byPlugin bySmalltalk |
		x := self randomFloat.
		y := self randomFloat.
		"a z that (nearly) cancels x * y, a third of the times"
		z := ((random nextInteger: 3) = 1 and: [ (x * y) isFinite ])
			     ifTrue: [ (x * y) negated + (((random nextInteger: 5) - 3) * (x * y) ulp) ]
			     ifFalse: [ self randomFloat ].
		byPlugin := x primitiveTimes: y plus: z.
		bySmalltalk := UtilsPluginSmalltalk fma: x times: y plus: z.
		self assert: byPlugin notNil.
		self
			assert: (self float: byPlugin isSameAs: bySmalltalk)
			description: [ x printString , ' * ' , y printString , ' + ' , z printString ] ]
]

{ #category : 'tests' }
UtilsPluginDifferentialTest >> testKnuth [

	1 to: 30 do: [ :round |
		| seed plugin smalltalk mixed |
		seed := random nextInteger: 16r7FFFFFFF.
		plugin := KnuthRandom seed: seed.
		UtilsPlugin pluginHidden: true.
		smalltalk := KnuthRandom seed: seed.
		UtilsPlugin pluginHidden: false.
		mixed := KnuthRandom seed: seed.
		1 to: 450 do: [ :index |
			| expected |
			expected := plugin next.
			UtilsPlugin pluginHidden: true.
			self assert: smalltalk next equals: expected.
			"a state goes from one way to the other"
			UtilsPlugin pluginHidden: index \\ 3 = 0.
			self assert: mixed next equals: expected.
			UtilsPlugin pluginHidden: false ] ]
]

{ #category : 'tests' }
UtilsPluginDifferentialTest >> testSplitMix64 [

	1 to: 60 do: [ :round |
		| seed plugin smalltalk mixed byPlugin bySmalltalk |
		"seeds of every size, the edges of 64 bits too"
		seed := round <= 6
			        ifTrue: [ #( 0 1 -1 16rFFFFFFFFFFFFFFFF 16r61C8864680B583EB 16r8000000000000000 ) at: round ]
			        ifFalse: [ (random nextInteger: (2 raisedTo: (random nextInteger: 70))) - 1 ].
		plugin := SplitMix64 seed: seed.
		UtilsPlugin pluginHidden: true.
		smalltalk := SplitMix64 seed: seed.
		UtilsPlugin pluginHidden: false.
		mixed := SplitMix64 seed: seed.
		1 to: 300 do: [ :index |
			| expected fraction |
			expected := plugin nextInteger64.
			fraction := plugin next.
			UtilsPlugin pluginHidden: true.
			self assert: smalltalk nextInteger64 equals: expected.
			self assert: (self float: smalltalk next isSameAs: fraction).
			"a state goes from one way to the other"
			UtilsPlugin pluginHidden: index \\ 3 = 0.
			self assert: mixed nextInteger64 equals: expected.
			UtilsPlugin pluginHidden: index \\ 5 = 0.
			self assert: (self float: mixed next isSameAs: fraction).
			UtilsPlugin pluginHidden: false ].
		"the bulk primitive against the twin"
		byPlugin := DoubleWordArray new: (random nextInteger: 200).
		bySmalltalk := DoubleWordArray new: byPlugin size.
		self assert: (plugin primOutputsOf: plugin state into: byPlugin) identicalTo: byPlugin.
		UtilsPluginSmalltalk splitMix64OutputsOf: smalltalk state into: bySmalltalk.
		self assert: byPlugin equals: bySmalltalk.
		self assert: plugin state first equals: smalltalk state first ]
]

{ #category : 'tests' }
UtilsPluginDifferentialTest >> testStrtok [

	| alphabet |
	alphabet := { $a. $b. Character lf. Character cr. $ . Character null }.
	1 to: 20000 do: [ :round |
		| text delimiters inclusive byPlugin bySmalltalk |
		text := String new: (random nextInteger: 25) - 1.
		1 to: text size do: [ :index |
			text at: index put: (alphabet atRandom: random) ].
		delimiters := String new: (random nextInteger: 4) - 1.
		1 to: delimiters size do: [ :index |
			delimiters at: index put: (alphabet at: 2 + (random nextInteger: 4)) ].
		inclusive := random next < 0.5.
		byPlugin := text primStrtok: delimiters inclusive: inclusive.
		bySmalltalk := UtilsPluginSmalltalk split: text by: delimiters inclusive: inclusive.
		self assert: byPlugin notNil.
		self assert: byPlugin equals: bySmalltalk.
		self assert: (byPlugin collect: [ :each | each class ]) equals: (bySmalltalk collect: [ :each | each class ]) ]
]
