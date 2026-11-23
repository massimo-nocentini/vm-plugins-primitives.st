"
I am SplitMix64, the generator of Sebastiano Vigna's `splitmix64.c` (2015, dedicated to the public domain), a fixed-increment version of the `SplittableRandom` of Java 8 (Steele, Lea and Flood, OOPSLA 2014, doi:10.1145/2714064.2660195). The UtilsPlugin runs his file unchanged; `UtilsPluginSmalltalk` translates it, bit for bit, on a VM without the plugin.

## The generator

My state is one 64-bit integer `x`. Each output adds the odd constant 16r9E3779B97F4A7C15 to `x` (modulo 2^64) and answers a mix of the new `x`:

```smalltalk
z := (z bitXor: z >> 30) * 16rBF58476D1CE4E5B9.
z := (z bitXor: z >> 27) * 16r94D049BB133111EB.
z bitXor: z >> 31
```

(each product modulo 2^64). I pass BigCrush, and I am fast.

Since `x` moves by an odd constant and the mix is a bijection (xorshifts and multiplications by odd constants are invertible), the 2^64 outputs of my period are a permutation of the 2^64 integers of 64 bits: no value ever repeats, whereas a random sequence of 2^32 values of 64 bits repeats one with a probability of about 40%. So I fail the tests based on collisions; for the same reason I am an excellent choice to fill the state of another generator from a seed (`nextIntegers64:`): consecutive outputs never hold the same value twice (two zeros, say), and never are all zero.

## The protocol

I am a `Random`, so I answer its protocol: `next` (a Float in [0, 1)), `next:`, `nextInteger:`, `nextBetween:and:`, `nextIntegerBetween:and:`, and I can shuffle a collection (`shuffleBy:`). Mine:

- `nextInteger64`, the next output, an Integer in [0, 2^64);
- `next`, the top 53 bits of the next output times 2^-53: every multiple of 2^-53 in [0, 1), exactly;
- `nextInteger: n`, the next output times n, divided by 2^64 and truncated, plus 1;
- `fill: aDoubleWordArray`, the next outputs in its elements, in order;
- and `nextIntegers64: n`, a new `DoubleWordArray` of the next n outputs.

## The state

My state is the `state` of `Random`, a `DoubleWordArray` of 1 whose element is `x`, as for `Random` itself. Any integer seeds me: `x` is the seed modulo 2^64, and `seed` answers it; `state first` answers `x`, which is the seed plus n times 16r9E3779B97F4A7C15, modulo 2^64, after n outputs.

```smalltalk
(SplitMix64 seed: 0) nextInteger64.	""16rE220A8397B1DCDAF""
(SplitMix64 seed: 1234567) nextIntegers64: 4.
SplitMix64 new next: 3.
(1 to: 10) asArray shuffleBy: SplitMix64 new.
```
"
Class {
	#name : 'SplitMix64',
	#superclass : 'Random',
	#category : 'VM-Plugins-Primitives',
	#package : 'VM-Plugins-Primitives'
}

{ #category : 'accessing' }
SplitMix64 >> fill: aDoubleWordArray [
	"Store the next outputs in the elements of aDoubleWordArray, in order, and answer it"

	UtilsPlugin usesPlugin ifTrue: [
		(self primOutputsOf: state into: aDoubleWordArray) ifNotNil: [ ^ aDoubleWordArray ] ].
	^ UtilsPluginSmalltalk splitMix64OutputsOf: state into: aDoubleWordArray
]

{ #category : 'initialization' }
SplitMix64 >> initialize [
	"Random's kind of state, a DoubleWordArray of 1: the primitives of the plugin read and write Vigna's x in its element"

	state := DoubleWordArray new: 1.
	self useClockBasedSeed
]

{ #category : 'accessing' }
SplitMix64 >> next [
	"Answer the next fraction, a Float in [0, 1): the top 53 bits of the next output times 2^-53"

	UtilsPlugin usesPlugin ifTrue: [
		(self primNextFloat: state) ifNotNil: [ :fraction | ^ fraction ] ].
	^ UtilsPluginSmalltalk splitMix64NextFloat: state
]

{ #category : 'accessing' }
SplitMix64 >> nextInteger64 [
	"Answer the next output, an Integer in [0, 2^64): Vigna's next()"

	UtilsPlugin usesPlugin ifTrue: [
		(self primNext: state) ifNotNil: [ :output | ^ output ] ].
	^ UtilsPluginSmalltalk splitMix64Next: state
]

{ #category : 'accessing' }
SplitMix64 >> nextInteger: anInteger [
	"Answer an integer in [1, anInteger]: the next output times anInteger, divided by 2^64 and truncated, plus 1"

	anInteger strictlyPositive ifFalse: [ self error: 'Range must be positive' ].
	^ (self nextInteger64 * anInteger bitShift: -64) + 1
]

{ #category : 'accessing' }
SplitMix64 >> nextIntegers64: anInteger [
	"Answer a new DoubleWordArray of the next anInteger outputs"

	^ self fill: (DoubleWordArray new: anInteger)
]

{ #category : 'primitives' }
SplitMix64 >> primNext: aState [
	"Answer the next output of aState and advance it, or nil when the primitive failed"

	<primitive: 'primitive_splitmix64_next' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'primitives' }
SplitMix64 >> primNextFloat: aState [
	"Answer the fraction of the next output of aState and advance it, or nil when the primitive failed"

	<primitive: 'primitive_splitmix64_nextfloat' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'primitives' }
SplitMix64 >> primOutputsOf: aState into: aDoubleWordArray [
	"Store the next outputs of aState in aDoubleWordArray and answer it, or nil when the primitive failed"

	<primitive: 'primitive_splitmix64_fill' module: 'UtilsPlugin'>
	^ nil
]

{ #category : 'private' }
SplitMix64 >> privateNextValue [
	"Random's: an integer in [0, maxValue], the top 31 bits of the next output"

	^ self nextInteger64 bitShift: -33
]

{ #category : 'private' }
SplitMix64 >> setStateFromSeed [
	"Vigna's x is the seed, modulo 2^64: any integer seeds the state"

	seed := seed asInteger bitAnd: 16rFFFFFFFFFFFFFFFF.
	state at: 1 put: seed
]
