"
I test the fused multiply-add, `Float>>#times:plus:`, on both backends.
"
Class {
	#name : 'UtilsPluginFmaTest',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'tests' }
UtilsPluginFmaTest >> testArgumentsAsFloats [

	self assert: (2.0 times: 1 / 2 plus: 1) equals: 2.0.
	self assert: (2.0 times: 3 plus: 1) equals: 7.0.
	self assert: (0.5 times: 4 plus: (2 raisedTo: 70)) equals: (2 raisedTo: 70) asFloat
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testExact [

	self assert: (2.0 times: 3.0 plus: 1.0) equals: 7.0.
	self assert: (-1.5 times: 2.0 plus: 0.25) equals: -2.75
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testInfinitiesAndNaNs [

	self assert: (1.0e308 times: 10.0 plus: Float negativeInfinity) equals: Float negativeInfinity.
	self assert: (1.0e308 times: 10.0 plus: 0.0) equals: Float infinity.
	self assert: (Float infinity times: 2.0 plus: 1.0) equals: Float infinity.
	self assert: (Float infinity times: 0.0 plus: 1.0) isNaN.
	self assert: (Float infinity times: 2.0 plus: Float negativeInfinity) isNaN.
	self assert: (1.0 times: 1.0 plus: Float nan) isNaN.
	self assert: (Float nan times: 0.0 plus: 1.0) isNaN
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testNumber [

	self assert: (3 times: 4 plus: 5) equals: 17.
	self assert: (1 / 3 times: 3 plus: 1) equals: 2
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testOneRounding [
	"(1 + 2^-52)(1 - 2^-53) - 1 is 2^-53 - 2^-105 exactly; rounding the product first answers 0"

	| x y |
	x := 1.0 + (1 / (2 raisedTo: 52)) asFloat.
	y := 1.0 - (1 / (2 raisedTo: 53)) asFloat.
	self assert: x * y - 1.0 equals: 0.0.
	self
		assert: (x times: y plus: -1.0)
		equals: (1 / (2 raisedTo: 53)) - (1 / (2 raisedTo: 105))
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testSignedZeros [

	self assert: (Float negativeZero times: 1.0 plus: Float negativeZero) signBit equals: 1.
	self assert: (0.0 times: -1.0 plus: 0.0) signBit equals: 0.
	self assert: (Float negativeZero times: Float negativeZero plus: Float negativeZero) signBit equals: 0.
	self assert: (2.0 times: 3.0 plus: -6.0) signBit equals: 0.
	self assert: (-2.0 times: 3.0 plus: 6.0) signBit equals: 0
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testSubnormals [

	| tiny |
	tiny := Float fminDenormalized.
	"half of the smallest subnormal is a tie: to even, zero, with its sign"
	self assert: (tiny times: 0.5 plus: 0.0) equals: 0.0.
	self assert: (tiny times: 0.5 plus: 0.0) signBit equals: 0.
	self assert: (tiny negated times: 0.5 plus: 0.0) signBit equals: 1.
	self assert: (tiny times: 0.75 plus: 0.0) equals: tiny.
	self assert: (tiny times: 1.5 plus: 0.0) equals: tiny * 2.
	self assert: (Float fminNormalized times: 0.5 plus: tiny) equals: Float fminNormalized / 2 + tiny
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testRoundingOfLargeIntegers [
	"x * y + z is here an integer of 436 bits just above the middle of two Floats: Pharo 12's LargeNegativeInteger>>#asFloat answers the lower one"

	| x y z |
	x := Float fromIEEE64Bit: 16rB067FDEDA7000000.
	y := Float fromIEEE64Bit: 16r6AB3500BF8000000.
	z := Float fromIEEE64Bit: 16rCC60035E98000000.
	self assert: (x times: y plus: z) asIEEE64BitWord equals: 16rDB2CF591CD06466D.
	self assert: (x negated times: y plus: z negated) asIEEE64BitWord equals: 16r5B2CF591CD06466D
]

{ #category : 'tests' }
UtilsPluginFmaTest >> testTiesToEven [

	| half |
	half := (1 / (2 raisedTo: 53)) asFloat.
	"1 + 2^-53 is the middle of 1 and 1 + 2^-52: to even, 1"
	self assert: (half times: 1.0 plus: 1.0) equals: 1.0.
	"1 + 2^-52 + 2^-53 is the middle of 1 + 2^-52 and 1 + 2^-51: to even, the second"
	self
		assert: (half times: 3.0 plus: 1.0)
		equals: 1.0 + (1 / (2 raisedTo: 51)).
	self assert: ((2 raisedTo: 1023) asFloat times: 2.0 plus: Float fmax) equals: Float infinity
]
