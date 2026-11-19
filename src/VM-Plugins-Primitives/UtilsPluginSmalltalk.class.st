"
I am the Smalltalk twin of the UtilsPlugin (see `UtilsPlugin`): each of my class methods answers what the plugin's primitive answers, bit for bit, or signals the error for the arguments it fails on. The image uses me on a VM without the plugin, after a primitive failed, and when `UtilsPlugin pluginHidden` is true.

- `fma:times:plus:` is C's `fma`, exactly: the exact value of x * y + z (with Fractions), rounded once to the nearest Float, with IEEE 754's signed zeros, infinities and NaNs.
- `split:by:inclusive:` is the splitting of `primitive_strtok_r`.
- `deCasteljau:into:at:` repeats the roundings of the engine's `up_bezier`, in the same order, with my `fma:times:plus:` and an IEEE division (no ZeroDivide).
- `newKnuthState`, `knuthStart:seed:` and `knuthNext:` translate `ranf_start`, `ranf_array` and `ranf_arr_next` of Knuth's `rng-double.c` (TAOCP 3.6, 3rd edition, 9th printing), which the plugin runs unchanged, on the same state: { ByteArray of the 100 doubles of ran_u. ByteArray of the 1009 doubles of the buffer. 1-based index of its next fraction }. A state may go from the plugin to me and back.
- `splitMix64Next:`, `splitMix64NextFloat:` and `splitMix64OutputsOf:into:` translate `next()` of Vigna's `splitmix64.c`, which the plugin runs unchanged, on the same state, a DoubleWordArray of 1 (his x), each product and sum taken modulo 2^64.
"
Class {
	#name : 'UtilsPluginSmalltalk',
	#superclass : 'Object',
	#category : 'VM-Plugins-Primitives',
	#package : 'VM-Plugins-Primitives'
}

{ #category : 'Bezier curves' }
UtilsPluginSmalltalk class >> bezierPointOf: xs and: ys at: t [
	"The point at the Float t of the Bezier curve of the n >= 1 control points (xs at: k) @ (ys at: k), Floats: Q = P1, then for k = 1 .. n-1
		h := h * t(n-k) / (k(1-t) + h * t(n-k)),  Q := (1-h) Q + h Pk+1
	with h = 1 at first, each product-sum fused, as up_bezier of the plugin"

	| n h u px py |
	n := xs size asFloat.
	h := 1.0.
	u := 1.0 - t.
	px := xs first.
	py := ys first.
	2 to: xs size do: [ :index |
		| k h1 |
		k := (index - 1) asFloat.
		h := h * (self fma: t times: n plus: t negated * k).
		h := self divide: h by: (self fma: u times: k plus: h).
		h1 := 1.0 - h.
		px := self fma: px times: h1 plus: (xs at: index) * h.
		py := self fma: py times: h1 plus: (ys at: index) * h ].
	^ px @ py
]

{ #category : 'Bezier curves' }
UtilsPluginSmalltalk class >> deCasteljau: controlPoints into: curvePoints at: parameters [
	"As UtilsPlugin class>>#deCasteljau:into:at: (the control points are all read first)"

	| xs ys |
	controlPoints isEmpty ifTrue: [
		^ CollectionIsEmpty signalWith: controlPoints ].
	parameters size > curvePoints size ifTrue: [
		^ SubscriptOutOfBounds
			  signalFor: parameters size
			  lowerBound: 1
			  upperBound: curvePoints size ].
	xs := controlPoints collect: [ :each | each x asFloat ] as: Array.
	ys := controlPoints collect: [ :each | each y asFloat ] as: Array.
	parameters doWithIndex: [ :t :j |
		curvePoints at: j put: (self bezierPointOf: xs and: ys at: t asFloat) ].
	^ curvePoints
]

{ #category : 'Bezier curves' }
UtilsPluginSmalltalk class >> divide: a by: b [
	"a / b of the Floats a and b as IEEE 754 divides: a zero divisor answers an infinity, or a NaN for 0 / 0 and NaN / 0, instead of signalling ZeroDivide"

	b isZero ifFalse: [ ^ a / b ].
	(a isNaN or: [ a isZero ]) ifTrue: [ ^ Float nan ].
	^ (a signBit bitXor: b signBit) = 0
		  ifTrue: [ Float infinity ]
		  ifFalse: [ Float negativeInfinity ]
]

{ #category : 'fma' }
UtilsPluginSmalltalk class >> fma: x times: y plus: z [
	"x * y + z of the Floats x, y and z, rounded once: the Float nearest to the exact value (ties to even), as C's fma"

	| exact |
	(x isFinite and: [ y isFinite ]) ifFalse: [
		"x * y is an infinity or a NaN, exactly, and so is the sum"
		^ x * y + z ].
	z isFinite ifFalse: [ "x * y is finite: the sum is z" ^ z ].
	exact := x asTrueFraction * y asTrueFraction + z asTrueFraction.
	exact isZero ifTrue: [
		"-0 only for (-0) + (-0): x * y an exact -0 and z -0"
		^ ((x isZero or: [ y isZero ]) and: [
			   (x signBit bitXor: y signBit) = 1 and: [ z signBit = 1 ] ])
			  ifTrue: [ Float negativeZero ]
			  ifFalse: [ 0.0 ] ].
	^ self floatNearest: exact
]

{ #category : 'fma' }
UtilsPluginSmalltalk class >> floatNearest: aNumber [
	"The Float nearest to the Integer or Fraction aNumber, ties to even, as IEEE 754 rounds: an infinity beyond the largest Float, a subnormal or a zero (with the sign of aNumber) below the smallest normal one. Not Number>>#asFloat: the asFloat of some LargeIntegers of Pharo 12 is not the nearest Float"

	| numerator denominator exponent significand remainder |
	aNumber isZero ifTrue: [ ^ 0.0 ].
	numerator := aNumber abs numerator.
	denominator := aNumber abs denominator.
	"significand := numerator / denominator / 2^exponent, truncated, with 53 bits (2^52 <= significand < 2^53) or fewer for a subnormal (exponent -1074)"
	exponent := numerator highBit - denominator highBit - 53 max: -1074.
	[
	| scaledNumerator scaledDenominator |
	scaledNumerator := exponent < 0
		                   ifTrue: [ numerator bitShift: exponent negated ]
		                   ifFalse: [ numerator ].
	scaledDenominator := exponent > 0
		                     ifTrue: [ denominator bitShift: exponent ]
		                     ifFalse: [ denominator ].
	significand := scaledNumerator // scaledDenominator.
	remainder := scaledNumerator - (significand * scaledDenominator).
	significand highBit > 53
		ifTrue: [ exponent := exponent + 1. false ]
		ifFalse: [
			(significand highBit < 53 and: [ exponent > -1074 ])
				ifTrue: [ exponent := exponent - 1. false ]
				ifFalse: [
					"round to nearest, ties to even"
					(remainder * 2 > scaledDenominator or: [
						 remainder * 2 = scaledDenominator and: [ significand odd ] ])
						ifTrue: [ significand := significand + 1 ].
					true ] ] ] whileFalse.
	"significand <= 2^53: its asFloat is exact, and so is timesTwoPower: unless it overflows"
	^ aNumber negative
		  ifTrue: [ (significand asFloat timesTwoPower: exponent) negated ]
		  ifFalse: [ significand asFloat timesTwoPower: exponent ]
]

{ #category : 'Knuth generator' }
UtilsPluginSmalltalk class >> knuthNext: state [
	"Answer the next fraction of state, a Float in [0, 1), and advance it: Knuth's ranf_arr_next"

	| buffer cursor |
	self checkKnuthState: state.
	buffer := state at: 2.
	cursor := state at: 3.
	(buffer float64AtOffset: cursor - 1 * 8) < 0 ifTrue: [
		self knuthCycle: state.
		cursor := 1 ].
	state at: 3 put: cursor + 1.
	^ buffer float64AtOffset: cursor - 1 * 8
]

{ #category : 'Knuth generator' }
UtilsPluginSmalltalk class >> knuthStart: state seed: anInteger [
	"Seed state with the low 30 bits of anInteger (Knuth's ranf_start), with an empty buffer, and answer state"

	self checkKnuthState: state.
	self put: (self ranfStart: anInteger) into: (state at: 1).
	(state at: 2) float64AtOffset: 0 put: -1.0.
	state at: 3 put: 1.
	^ state
]

{ #category : 'Knuth generator' }
UtilsPluginSmalltalk class >> newKnuthState [
	"A new state, seeded with 314159 (as the plugin's primitive_randomknuth_init)"

	^ self
		  knuthStart: (Array
				   with: (ByteArray new: self knuthLongLag * 8)
				   with: (ByteArray new: self knuthQuality * 8)
				   with: 1)
		  seed: 314159
]

{ #category : 'Knuth generator' }
UtilsPluginSmalltalk class >> ranfArray: aa count: n state: ranU [
	"Knuth's ranf_array(aa, n) on the state ranU: put n new fractions in aa (1-based Arrays of Floats; n >= 100)"

	| kk ll i j |
	kk := self knuthLongLag.
	ll := self knuthShortLag.
	1 to: kk do: [ :index | aa at: index put: (ranU at: index) ].
	j := kk.
	[ j < n ] whileTrue: [
		aa at: j + 1 put: (self modSum: (aa at: j - kk + 1) and: (aa at: j - ll + 1)).
		j := j + 1 ].
	i := 0.
	[ i < ll ] whileTrue: [
		ranU at: i + 1 put: (self modSum: (aa at: j - kk + 1) and: (aa at: j - ll + 1)).
		i := i + 1.
		j := j + 1 ].
	[ i < kk ] whileTrue: [
		ranU at: i + 1 put: (self modSum: (aa at: j - kk + 1) and: (ranU at: i - ll + 1)).
		i := i + 1.
		j := j + 1 ].
	^ aa
]

{ #category : 'Knuth generator' }
UtilsPluginSmalltalk class >> ranfStart: anInteger [
	"Knuth's ranf_start(seed): answer the state ran_u, an Array of 100 Floats (C's u[j] is my u at: j + 1)"

	| kk ll u ulp ss s t ranU |
	kk := self knuthLongLag.
	ll := self knuthShortLag.
	u := Array new: kk + kk - 1.
	ulp := 1.0 / (1 << 30) / (1 << 22). "2 to the -52"
	ss := 2.0 * ulp * ((anInteger bitAnd: 16r3FFFFFFF) + 2).
	0 to: kk - 1 do: [ :j |
		u at: j + 1 put: ss. "bootstrap the buffer"
		ss := ss + ss.
		ss >= 1.0 ifTrue: [ ss := ss - (1.0 - (2 * ulp)) ] ]. "cyclic shift of 51 bits"
	u at: 2 put: (u at: 2) + ulp. "make u[1] (and only u[1]) odd"
	s := anInteger bitAnd: 16r3FFFFFFF.
	t := self knuthSeparation - 1.
	[ t = 0 ] whileFalse: [
		kk - 1 to: 1 by: -1 do: [ :j | "square"
			u at: j + j + 1 put: (u at: j + 1).
			u at: j + j put: 0.0 ].
		kk + kk - 2 to: kk by: -1 do: [ :j |
			u
				at: j - (kk - ll) + 1
				put: (self modSum: (u at: j - (kk - ll) + 1) and: (u at: j + 1)).
			u at: j - kk + 1 put: (self modSum: (u at: j - kk + 1) and: (u at: j + 1)) ].
		s odd ifTrue: [ "multiply by z"
			kk to: 1 by: -1 do: [ :j | u at: j + 1 put: (u at: j) ].
			u at: 1 put: (u at: kk + 1). "shift the buffer cyclically"
			u at: ll + 1 put: (self modSum: (u at: ll + 1) and: (u at: kk + 1)) ].
		s isZero
			ifTrue: [ t := t - 1 ]
			ifFalse: [ s := s >> 1 ] ].
	ranU := Array new: kk.
	0 to: ll - 1 do: [ :j | ranU at: j + kk - ll + 1 put: (u at: j + 1) ].
	ll to: kk - 1 do: [ :j | ranU at: j - ll + 1 put: (u at: j + 1) ].
	10 timesRepeat: [ "warm things up"
		self ranfArray: u count: kk + kk - 1 state: ranU ].
	^ ranU
]

{ #category : 'SplitMix64' }
UtilsPluginSmalltalk class >> splitMix64Next: state [
	"Answer the next output of state, an Integer in [0, 2^64), and advance it: Vigna's next(), whose x is the element of state"

	| x |
	self checkSplitMix64State: state.
	x := (state at: 1) + self splitMix64Gamma bitAnd: self splitMix64Mask.
	state at: 1 put: x.
	^ self splitMix64Mix: x
]

{ #category : 'SplitMix64' }
UtilsPluginSmalltalk class >> splitMix64NextFloat: state [
	"Answer the fraction of the next output of state, a Float in [0, 1): its top 53 bits times 2^-53 (exact), and advance it"

	^ ((self splitMix64Next: state) bitShift: -11) asFloat timesTwoPower: -53
]

{ #category : 'SplitMix64' }
UtilsPluginSmalltalk class >> splitMix64OutputsOf: state into: aDoubleWordArray [
	"Store the next outputs of state in the elements of aDoubleWordArray, in order, advance state as many times, and answer aDoubleWordArray (as primitive_splitmix64_fill, which takes no empty one)"

	self checkSplitMix64State: state.
	(aDoubleWordArray class isDoubleWords and: [ aDoubleWordArray ~~ state ])
		ifFalse: [ ^ self error: 'Not a DoubleWordArray apart from the state of a SplitMix64' ].
	aDoubleWordArray isReadOnlyObject ifTrue: [
		^ self error: 'The DoubleWordArray to fill is read-only' ].
	1 to: aDoubleWordArray size do: [ :index |
		aDoubleWordArray at: index put: (self splitMix64Next: state) ].
	^ aDoubleWordArray
]

{ #category : 'splitting' }
UtilsPluginSmalltalk class >> split: aString by: delimiters inclusive: aBoolean [
	"The pieces of aString between the characters of delimiters (a String, a ByteArray of their values, or a collection of Characters), as primitive_strtok_r: with aBoolean false the maximal runs of non-delimiters, with aBoolean true every field between delimiters, empty ones too, but an empty last one"

	| set pieces start |
	set := self delimiterSet: delimiters.
	pieces := OrderedCollection new.
	aBoolean
		ifTrue: [
			start := 1.
			1 to: aString size do: [ :index |
				(set includes: (aString at: index)) ifTrue: [
					pieces add: (aString copyFrom: start to: index - 1).
					start := index + 1 ] ].
			start <= aString size ifTrue: [
				pieces add: (aString copyFrom: start to: aString size) ] ]
		ifFalse: [
			start := nil.
			1 to: aString size do: [ :index |
				(set includes: (aString at: index))
					ifTrue: [
						start ifNotNil: [
							pieces add: (aString copyFrom: start to: index - 1).
							start := nil ] ]
					ifFalse: [ start ifNil: [ start := index ] ] ].
			start ifNotNil: [
				pieces add: (aString copyFrom: start to: aString size) ] ].
	^ pieces asArray
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> checkKnuthState: state [
	"Signal an error unless state is the state of a generator that may be updated, as the plugin's checks"

	| cursor |
	((state isKindOf: Array) and: [
		 state size = 3 and: [
			 (self isBytes: (state at: 1) size: self knuthLongLag * 8) and: [
				 self isBytes: (state at: 2) size: self knuthQuality * 8 ] ] ])
		ifFalse: [ ^ self error: 'Not the state of a KnuthRandom' ].
	cursor := state at: 3.
	(cursor isInteger and: [ cursor between: 1 and: self knuthLongLag + 1 ])
		ifFalse: [ ^ self error: 'Not the state of a KnuthRandom' ].
	(state isReadOnlyObject or: [
		 (state at: 1) isReadOnlyObject or: [ (state at: 2) isReadOnlyObject ] ])
		ifTrue: [ ^ self error: 'The state of a KnuthRandom is read-only' ]
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> checkSplitMix64State: state [
	"Signal an error unless state is the state of a SplitMix64 that may be updated, as the plugin's checks: a writable DoubleWordArray of 1"

	(state class isDoubleWords and: [ state size = 1 ]) ifFalse: [
		^ self error: 'Not the state of a SplitMix64' ].
	state isReadOnlyObject ifTrue: [
		^ self error: 'The state of a SplitMix64 is read-only' ]
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> delimiterSet: delimiters [

	(delimiters isKindOf: ByteArray) ifTrue: [ ^ delimiters asString asSet ].
	^ delimiters asSet
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> isBytes: anObject size: anInteger [

	^ anObject class isBytes and: [
		  anObject class isVariable and: [ anObject basicSize = anInteger ] ]
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> knuthCycle: state [
	"Knuth's ranf_arr_cycle on state: a new buffer of fractions, ended by -1"

	| ranU buffer |
	ranU := self doublesOf: (state at: 1).
	buffer := self ranfArray: (Array new: self knuthQuality) count: self knuthQuality state: ranU.
	buffer at: self knuthLongLag + 1 put: -1.0.
	self put: ranU into: (state at: 1).
	self put: buffer into: (state at: 2)
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> doublesOf: aByteArray [

	^ (1 to: aByteArray size // 8) collect: [ :index |
		  aByteArray float64AtOffset: index - 1 * 8 ]
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> knuthLongLag [
	"Knuth's KK"

	^ 100
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> knuthQuality [
	"Knuth's QUALITY: the size of the buffer of fractions, of which a cycle uses the first KK"

	^ 1009
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> knuthSeparation [
	"Knuth's TT, the guaranteed separation between streams"

	^ 70
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> knuthShortLag [
	"Knuth's LL"

	^ 37
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> modSum: x and: y [
	"Knuth's mod_sum: (x + y) mod 1.0, as ((x)+(y))-(int)((x)+(y))"

	| sum |
	sum := x + y.
	^ sum - sum truncated
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> put: floats into: aByteArray [

	floats doWithIndex: [ :each :index |
		aByteArray float64AtOffset: index - 1 * 8 put: each ]
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> splitMix64Gamma [
	"The odd constant that Vigna's next() adds to x: 2^64 divided by the golden ratio, made odd"

	^ 16r9E3779B97F4A7C15
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> splitMix64Mask [

	^ 16rFFFFFFFFFFFFFFFF
]

{ #category : 'private' }
UtilsPluginSmalltalk class >> splitMix64Mix: x [
	"The output of Vigna's next() for the new x: a bijection of the integers of 64 bits"

	| z mask |
	mask := self splitMix64Mask.
	z := (x bitXor: (x bitShift: -30)) * 16rBF58476D1CE4E5B9 bitAnd: mask.
	z := (z bitXor: (z bitShift: -27)) * 16r94D049BB133111EB bitAnd: mask.
	^ z bitXor: (z bitShift: -31)
]
