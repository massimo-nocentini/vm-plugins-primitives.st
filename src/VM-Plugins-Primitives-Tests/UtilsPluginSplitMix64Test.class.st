"
I test `SplitMix64`, Vigna's generator, on both backends, against the outputs of his `splitmix64.c` (the C tests of the plugin print them: `enginetest --vectors`).
"
Class {
	#name : 'UtilsPluginSplitMix64Test',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'helpers' }
UtilsPluginSplitMix64Test >> gamma [

	^ 16r9E3779B97F4A7C15
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testFill [

	| random again outputs |
	random := SplitMix64 seed: 1234567.
	again := SplitMix64 seed: 1234567.
	outputs := random nextIntegers64: 1000.
	self assert: outputs class equals: DoubleWordArray.
	self assert: outputs size equals: 1000.
	self assert: outputs first equals: 16r599ED017FB08FC85.
	self assert: (outputs at: 100) equals: 16rF05866001D65775F.
	self assert: (outputs at: 1000) equals: 16r8B33CC4945DD1C5F.
	outputs do: [ :each | self assert: each equals: again nextInteger64 ].
	self assert: random state first equals: again state first.
	"fill: answers its argument; nothing to fill leaves the state alone"
	outputs := DoubleWordArray new: 3.
	self assert: (random fill: outputs) identicalTo: outputs.
	self assert: outputs asArray equals: ((1 to: 3) collect: [ :each | again nextInteger64 ]) asArray.
	self assert: (random fill: DoubleWordArray new) isEmpty.
	self assert: (random nextIntegers64: 0) isEmpty.
	self assert: random nextInteger64 equals: again nextInteger64.
	"no two outputs of a short stream are equal, none is zero here"
	outputs := (SplitMix64 seed: 42) nextIntegers64: 5000.
	self assert: outputs asSet size equals: 5000.
	self should: [ random fill: (Array new: 2) ] raise: Error.
	self should: [ random fill: random state ] raise: Error.
	self should: [ random fill: (self readOnly: (DoubleWordArray new: 2)) ] raise: Error
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testFractions [
	"next is the top 53 bits of the next output times 2^-53"

	| random outputs fraction |
	self
		assert: (SplitMix64 seed: 0) next
		equals: (Float fromIEEE64Bit: 16r3FEC4415072F63B9).
	self
		assert: (SplitMix64 seed: 1234567) next
		equals: (Float fromIEEE64Bit: 16r3FD667B405FEC23E).
	"the state 0, whose output is 0: the fraction +0.0"
	fraction := (SplitMix64 seed: (2 raisedTo: 64) - self gamma) next.
	self assert: fraction equals: 0.0.
	self assert: fraction signBit equals: 0.
	random := SplitMix64 seed: 99.
	outputs := (SplitMix64 seed: 99) nextIntegers64: 2000.
	outputs do: [ :each |
		fraction := random next.
		self assert: fraction isFloat.
		self assert: (fraction >= 0 and: [ fraction < 1 ]).
		self assert: fraction asTrueFraction equals: (each bitShift: -11) / (2 raisedTo: 53) ]
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testKnownOutputs [
	"The outputs 1, 2, 3, 100 and 1000 of some seeds, as Vigna's next() answers them: the first row is his file as it is, whose x starts at 0"

	#( #( 0 #( 1 16rE220A8397B1DCDAF 2 16r6E789E6AA1B965F4 3 16r06C45D188009454F 100 16r3505B7796BD1A506 1000 16r14E0ABB2BFCF7C3E ) )
	   #( 1 #( 1 16r910A2DEC89025CC1 2 16rBEEB8DA1658EEC67 3 16rF893A2EEFB32555E 100 16r4F05F03735C3B951 1000 16rE71894B1B5034FB7 ) )
	   #( 1234567 #( 1 16r599ED017FB08FC85 2 16r2C73F08458540FA5 3 16r883EBCE5A3F27C77 100 16rF05866001D65775F 1000 16r8B33CC4945DD1C5F ) )
	   #( 16rFFFFFFFFFFFFFFFF #( 1 16rE4D971771B652C20 2 16rE99FF867DBF682C9 3 16r382FF84CB27281E9 100 16rE6D6332A04AAF1C0 1000 16r82BD385046D33FBF ) )
	   #( 16r61C8864680B583EB #( 1 0 2 16rE220A8397B1DCDAF 3 16r6E789E6AA1B965F4 100 16rDC4C613D9EBA2304 1000 16r13CA922F0AF7DCBC ) ) )
		do: [ :row |
			| random outputs |
			random := SplitMix64 seed: row first.
			outputs := (1 to: 1000) collect: [ :index | random nextInteger64 ].
			row second pairsDo: [ :index :output |
				self assert: (outputs at: index) equals: output ].
			"the state is the seed plus 1000 gammas, modulo 2^64"
			self
				assert: random state first
				equals: (row first + (1000 * self gamma) bitAnd: 16rFFFFFFFFFFFFFFFF) ]
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testLayout [
	"The state is Random's, a DoubleWordArray of 1 that holds Vigna's x"

	| random |
	self assert: (Random instVarNames first: 2) equals: #( #state #seed ).
	random := SplitMix64 seed: 5.
	self assert: random state class equals: DoubleWordArray.
	self assert: random state size equals: 1.
	self assert: random state first equals: 5.
	random nextInteger64.
	self assert: random state first equals: 5 + self gamma
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testNextInteger [

	| random seen |
	random := SplitMix64 seed: 42.
	seen := Set new.
	10000 timesRepeat: [
		| n |
		n := random nextInteger: 6.
		self assert: (n between: 1 and: 6).
		seen add: n ].
	self assert: seen size equals: 6.
	self assert: ((random nextInteger: (2 raisedTo: 100)) between: 1 and: (2 raisedTo: 100)).
	"the output times n, over 2^64"
	self
		assert: ((SplitMix64 seed: 0) nextInteger: 1000)
		equals: 16rE220A8397B1DCDAF * 1000 // (2 raisedTo: 64) + 1.
	self assert: ((SplitMix64 seed: 0) nextInteger: 1) equals: 1.
	self should: [ random nextInteger: 0 ] raise: Error
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testRandomProtocol [

	| random fractions shuffled |
	random := SplitMix64 seed: 1.
	self assert: (random isKindOf: Random).
	fractions := random next: 1000.
	self assert: fractions size equals: 1000.
	self assert: (fractions allSatisfy: [ :each | each isFloat and: [ each >= 0 and: [ each < 1 ] ] ]).
	self assert: ((random nextBetween: 2 and: 3) between: 2 and: 3).
	self assert: ((random nextIntegerBetween: -3 and: 3) between: -3 and: 3).
	shuffled := (1 to: 50) asArray shuffleBy: (SplitMix64 seed: 9).
	self assert: shuffled sorted equals: (1 to: 50) asArray.
	self
		assert: shuffled
		equals: ((1 to: 50) asArray shuffleBy: (SplitMix64 seed: 9)).
	self assert: (SplitMix64 new next between: 0 and: 1).
	self assert: (SplitMix64 new nextInteger64 between: 0 and: 16rFFFFFFFFFFFFFFFF)
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testSeeds [

	| random first |
	"any integer seeds the state, modulo 2^64"
	self
		assert: ((SplitMix64 seed: -1) nextIntegers64: 300)
		equals: ((SplitMix64 seed: 16rFFFFFFFFFFFFFFFF) nextIntegers64: 300).
	self
		assert: ((SplitMix64 seed: (2 raisedTo: 64) + 7) nextIntegers64: 300)
		equals: ((SplitMix64 seed: 7) nextIntegers64: 300).
	self assert: (SplitMix64 seed: -1) seed equals: 16rFFFFFFFFFFFFFFFF.
	self assert: (SplitMix64 seed: (2 raisedTo: 70) + 7) seed equals: 7.
	self assert: (SplitMix64 seed: 0) seed equals: 0.
	"seeding again starts over"
	random := SplitMix64 seed: 77.
	first := random nextIntegers64: 250.
	random seed: 77.
	self assert: (random nextIntegers64: 250) equals: first.
	"two generators do not share their states"
	self
		assert: ((SplitMix64 seed: 77) nextInteger64; nextInteger64)
		equals: (first at: 2)
]

{ #category : 'tests' }
UtilsPluginSplitMix64Test >> testWrapAround [
	"The state wraps around modulo 2^64: from 2^64 - gamma the first state is 0, whose output is 0, and the stream goes on as the seed 0's"

	| random |
	random := SplitMix64 seed: (2 raisedTo: 64) - self gamma.
	self assert: random nextInteger64 equals: 0.
	self assert: random state first equals: 0.
	self assert: (random nextIntegers64: 100) equals: ((SplitMix64 seed: 0) nextIntegers64: 100).
	random := SplitMix64 seed: 16rFFFFFFFFFFFFFFFF.
	random nextInteger64.
	self assert: random state first equals: self gamma - 1
]
