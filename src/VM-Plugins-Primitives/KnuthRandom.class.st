"
I am the lagged Fibonacci generator of fractions of Knuth's The Art of Computer Programming, volume 2, section 3.6 (3rd edition, 9th printing): his `rng-double.c`, `ranf_start` and `ranf_arr_next`, which the UtilsPlugin runs unchanged (and `UtilsPluginSmalltalk` translates, bit for bit, on a VM without it).

I am a `Random`, so I answer its protocol: `next` (a Float in [0, 1)), `next:`, `nextInteger:`, `nextBetween:and:`, `nextIntegerBetween:and:`, and I can shuffle a collection (`shuffleBy:`).

My state is the `state` of `Random`, an Array (see `UtilsPluginSmalltalk`), and my seed its `seed`: only its low 30 bits count, as Knuth's `seed & 0x3fffffff`, and `seed` answers them.

```smalltalk
(KnuthRandom seed: 310952) next: 3.
KnuthRandom new nextInteger: 6.
```
"
Class {
	#name : 'KnuthRandom',
	#superclass : 'Random',
	#category : 'VM-Plugins-Primitives',
	#package : 'VM-Plugins-Primitives'
}

{ #category : 'initialization' }
KnuthRandom >> initialize [
	"Not Random's: its state is a DoubleWordArray. The primitive_randomknuth_start of the plugin finds my state in my first slot and my seed in my second one: those of Random"

	state := UtilsPlugin newKnuthState.
	self useClockBasedSeed
]

{ #category : 'accessing' }
KnuthRandom >> next [
	"Answer the next fraction, a Float in [0, 1): Knuth's ranf_arr_next"

	UtilsPlugin usesPlugin ifTrue: [
		(self primNext: state) ifNotNil: [ :fraction | ^ fraction ] ].
	^ UtilsPluginSmalltalk knuthNext: state
]

{ #category : 'accessing' }
KnuthRandom >> nextInteger: anInteger [
	"Answer an integer in [1, anInteger], from the next fraction: exactly, for any size of anInteger"

	anInteger strictlyPositive ifFalse: [ self error: 'Range must be positive' ].
	^ (self next asTrueFraction * anInteger) truncated + 1
]

{ #category : 'primitives' }
KnuthRandom >> primNext: aState [
	"Answer the next fraction of aState and advance it, or nil when the primitive failed"

	<primitive: 'primitive_randomknuth_next' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'primitives' }
KnuthRandom >> primStart [
	"Seed my state with my seed and answer self, or nil when the primitive failed"

	<primitive: 'primitive_randomknuth_start' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'private' }
KnuthRandom >> privateNextValue [
	"Random's: an integer in [0, maxValue], from the next fraction"

	^ (self next * (self maxValue + 1)) truncated
]

{ #category : 'private' }
KnuthRandom >> setStateFromSeed [
	"Knuth's ranf_start: only the low 30 bits of the seed count"

	seed := seed asInteger bitAnd: 16r3FFFFFFF.
	(UtilsPlugin usesPlugin and: [ self primStart notNil ]) ifTrue: [ ^ self ].
	UtilsPluginSmalltalk knuthStart: state seed: seed
]
