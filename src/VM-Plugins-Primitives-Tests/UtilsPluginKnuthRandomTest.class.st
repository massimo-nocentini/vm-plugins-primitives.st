"
I test `KnuthRandom`, Knuth's generator, on both backends, against the values of his `rng-double.c` (the C tests of the plugin print them: `enginetest --vectors`).
"
Class {
	#name : 'UtilsPluginKnuthRandomTest',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testKnuthsCheck [
	"The main of rng-double.c: ran_u[0] after ranf_start(310952) and 2009 calls of ranf_array(a, 1009). Each cycle of 100 fractions calls ranf_array(a, 1009) once: the 200801st fraction starts the 2009th cycle"

	| random |
	self timeLimit: 2 minutes.
	random := KnuthRandom seed: 310952.
	200801 timesRepeat: [ random next ].
	self
		assert: (random state first float64AtOffset: 0)
		equals: 0.36410514377569680455
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testLayout [
	"primitive_randomknuth_start reads the state in the first slot and the seed in the second one"

	self assert: (Random instVarNames first: 2) equals: #( #state #seed ).
	self assert: (KnuthRandom new instVarAt: 1) class equals: Array
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testNewState [

	| state |
	state := UtilsPlugin newKnuthState.
	self assert: state size equals: 3.
	self assert: state first size equals: 800.
	self assert: state second size equals: 8072.
	self assert: state third equals: 1.
	self
		assert: (UtilsPluginSmalltalk knuthNext: state)
		equals: (KnuthRandom seed: 314159) next
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testNextInteger [

	| random seen |
	random := KnuthRandom seed: 42.
	seen := Set new.
	10000 timesRepeat: [
		| n |
		n := random nextInteger: 6.
		self assert: (n between: 1 and: 6).
		seen add: n ].
	self assert: seen size equals: 6.
	self assert: ((random nextInteger: (2 raisedTo: 100)) between: 1 and: (2 raisedTo: 100)).
	self should: [ random nextInteger: 0 ] raise: Error
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testRandomProtocol [

	| random fractions shuffled |
	random := KnuthRandom seed: 1.
	self assert: (random isKindOf: Random).
	fractions := random next: 1000.
	self assert: fractions size equals: 1000.
	self assert: (fractions allSatisfy: [ :each | each isFloat and: [ each >= 0 and: [ each < 1 ] ] ]).
	self assert: ((random nextBetween: 2 and: 3) between: 2 and: 3).
	self assert: ((random nextIntegerBetween: -3 and: 3) between: -3 and: 3).
	shuffled := (1 to: 50) asArray shuffleBy: (KnuthRandom seed: 9).
	self assert: shuffled sorted equals: (1 to: 50) asArray.
	self
		assert: shuffled
		equals: ((1 to: 50) asArray shuffleBy: (KnuthRandom seed: 9)).
	self assert: (KnuthRandom new next between: 0 and: 1)
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testReferenceValues [
	"The fractions 1, 2, 3, 100, 101 (the second cycle) and 205 of some seeds, as Knuth's ranf_arr_next answers them"

	#( #( 0 #( 1 16r3FE846EDED6C7F80 2 16r3FE0322121CF9FB4 3 16r3FE786DEF8DA8110 100 16r3FE654629A2B0670 101 16r3FD807FEB4AAC1A0 205 16r3FBC0E6BDBE25240 ) )
	   #( 310952 #( 1 16r3FC4F4EEA4AAF860 2 16r3FE294B722F76C58 3 16r3FE77DFE7149F53C 100 16r3FDF7CB96B9294C8 101 16r3FE9D45A8EBD78B6 205 16r3FD7F4464E5C8184 ) )
	   #( 314159 #( 1 16r3FE0CA37C7325BDA 2 16r3FE73FE2BFFA528E 3 16r3FEEBFBBCA6368B8 100 16r3FEE61A1C9A080B4 101 16r3FC10F8716DDAED0 205 16r3FDEE204B8247AE0 ) )
	   #( 1073741823 #( 1 16r3FB1DF8C9C40DDC0 2 16r3FD02067ACA71D38 3 16r3FE51DA3A417309E 100 16r3FDC87F6B4269F9C 101 16r3FE1FC5F5F30809E 205 16r3FEB43240B893E86 ) ) )
		do: [ :row |
			| random fractions |
			random := KnuthRandom seed: row first.
			fractions := random next: 205.
			row second pairsDo: [ :index :bits |
				self
					assert: (fractions at: index)
					equals: (Float fromIEEE64Bit: bits) ] ]
]

{ #category : 'tests' }
UtilsPluginKnuthRandomTest >> testSeeds [

	| random first |
	"only the low 30 bits of the seed count"
	self
		assert: ((KnuthRandom seed: 5) next: 300)
		equals: ((KnuthRandom seed: 5 + (3 << 30)) next: 300).
	self assert: (KnuthRandom seed: -1) seed equals: 16r3FFFFFFF.
	self assert: (KnuthRandom seed: (2 raisedTo: 70) + 7) seed equals: 7.
	"seeding again starts over"
	random := KnuthRandom seed: 77.
	first := random next: 250.
	random seed: 77.
	self assert: (random next: 250) equals: first
]
