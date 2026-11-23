"
I test the contract of the primitives of the UtilsPlugin (`docs/UtilsPlugin.md`): what they answer, and that they fail, leaving their arguments alone, on what they do not take (their Smalltalk twins then answer, or signal the error). I run with the plugin only.
"
Class {
	#name : 'UtilsPluginPrimitiveTest',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'building suites' }
UtilsPluginPrimitiveTest class >> testParameters [

	^ ParametrizedTestMatrix new
		  forSelector: #backend addOptions: #( #plugin );
		  yourself
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testDeCasteljauFailures [

	| points out |
	points := { 0 @ 0. 1 @ 1 }.
	out := Array new: 2.
	self assert: (UtilsPlugin primDeCasteljau: #(  ) into: out at: #( 0.5 )) isNil.
	self assert: (UtilsPlugin primDeCasteljau: points asOrderedCollection into: out at: #( 0.5 )) isNil.
	self assert: (UtilsPlugin primDeCasteljau: { 0 @ 0. 1 @ (1 / 2) } into: out at: #( 0.5 )) isNil.
	self assert: (UtilsPlugin primDeCasteljau: { 0 @ 0. 3 } into: out at: #( 0.5 )) isNil.
	self assert: (UtilsPlugin primDeCasteljau: points into: out at: { 1 / 2 }) isNil.
	self assert: (UtilsPlugin primDeCasteljau: points into: out at: #( 0 0.5 1 )) isNil.
	self assert: (UtilsPlugin primDeCasteljau: points into: (self readOnly: (Array new: 2)) at: #( 0.5 )) isNil.
	self assert: out equals: (Array new: 2).
	self assert: (UtilsPlugin primDeCasteljau: points into: out at: #( 0.5 )) identicalTo: UtilsPlugin.
	self assert: out first equals: 0.5 @ 0.5
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testFmaFailures [

	self assert: (2.0 primitiveTimes: 3 plus: 1.0) isNil.
	self assert: (2.0 primitiveTimes: 3.0 plus: nil) isNil.
	self assert: (2.0 primitiveTimes: 3.0 plus: 1.0) equals: 7.0.
	self assert: ((2 raisedTo: 1000) asFloat primitiveTimes: 1.0 plus: 0.0) equals: (2 raisedTo: 1000) asFloat
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testForwarders [
	"The VM follows the forwarders of the arguments and retries"

	| points old |
	points := { 0 @ 0. 1 @ 1 }.
	old := points last.
	old becomeForward: 4 @ 8.
	self assert: (UtilsPlugin deCasteljau: points into: (Array new: 1) at: #( 1 )) first equals: 4.0 @ 8.0
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testInfo [

	| info |
	info := UtilsPlugin info.
	self assert: info size equals: 3.
	self assert: info first equals: 1.
	self assert: info second equals: 'UtilsPlugin 1.1'.
	self assert: (#( 'native' 'emscripten' ) includes: info third)
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testKnuthFailures [

	| random state |
	random := KnuthRandom seed: 1.
	state := UtilsPlugin primKnuthState.
	self assert: state notNil.
	self assert: (random primNext: state) isFloat.
	self assert: (random primNext: #( 1 2 3 )) isNil.
	self assert: (random primNext: { ByteArray new: 800. ByteArray new: 8072 }) isNil.
	self assert: (random primNext: { ByteArray new: 799. ByteArray new: 8072. 1 }) isNil.
	self assert: (random primNext: (state copy at: 3 put: 0; yourself)) isNil.
	self assert: (random primNext: (state copy at: 3 put: 102; yourself)) isNil.
	self assert: (random primNext: (state copy at: 3 put: nil; yourself)) isNil.
	self assert: (random primNext: (self readOnly: state copy)) isNil.
	self assert: (random primNext: (state copy at: 1 put: (self readOnly: state first copy); yourself)) isNil.
	self should: [ UtilsPluginSmalltalk knuthNext: (state copy at: 3 put: 0; yourself) ] raise: Error.
	self should: [ UtilsPluginSmalltalk knuthNext: (self readOnly: state copy) ] raise: Error.
	random instVarNamed: #seed put: (2 raisedTo: 70).
	self assert: random primStart isNil.
	random instVarNamed: #seed put: 3.
	self assert: random primStart identicalTo: random
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testSplitMix64Failures [
	"The state is a writable DoubleWordArray of 1, the array to fill a writable non-empty DoubleWordArray apart from it; a failure writes nothing"

	| random state badStates array |
	random := SplitMix64 seed: 0.
	state := DoubleWordArray with: 0.
	self assert: (random primNext: state) equals: 16rE220A8397B1DCDAF.
	self assert: state first equals: 16r9E3779B97F4A7C15.
	self assert: (random primNextFloat: (DoubleWordArray with: 0)) equals: (Float fromIEEE64Bit: 16r3FEC4415072F63B9).
	"SmallIntegers too: the output of the state 0 is 0"
	self assert: (random primNext: (DoubleWordArray with: (2 raisedTo: 64) - 16r9E3779B97F4A7C15)) identicalTo: 0.
	badStates := {
		nil. 3. (2 raisedTo: 70). #( 0 ). DoubleWordArray new. DoubleWordArray new: 2.
		ByteArray new: 8. WordArray new: 2. (DoubleByteArray new: 4). Float pi. 'abcdefgh' }.
	badStates do: [ :each |
		self assert: (random primNext: each) isNil description: [ each printString ].
		self assert: (random primNextFloat: each) isNil description: [ each printString ].
		self assert: (random primOutputsOf: each into: (DoubleWordArray new: 2)) isNil description: [ each printString ].
		self should: [ UtilsPluginSmalltalk splitMix64Next: each ] raise: Error ].
	state := self readOnly: (DoubleWordArray with: 5).
	self assert: (random primNext: state) isNil.
	self assert: (random primNextFloat: state) isNil.
	self assert: (random primOutputsOf: state into: (DoubleWordArray new: 2)) isNil.
	self assert: state first equals: 5.
	self should: [ UtilsPluginSmalltalk splitMix64Next: state ] raise: Error.
	"the array to fill"
	state := DoubleWordArray with: 5.
	{ nil. #( 0 0 ). DoubleWordArray new. ByteArray new: 16. WordArray new: 4. DoubleByteArray new: 8. self readOnly: (DoubleWordArray new: 2). state }
		do: [ :each |
			self assert: (random primOutputsOf: state into: each) isNil description: [ each printString ].
			self assert: state first equals: 5 ].
	self should: [ UtilsPluginSmalltalk splitMix64OutputsOf: state into: state ] raise: Error.
	self should: [ UtilsPluginSmalltalk splitMix64OutputsOf: state into: (WordArray new: 2) ] raise: Error.
	self should: [ UtilsPluginSmalltalk splitMix64OutputsOf: state into: (self readOnly: (DoubleWordArray new: 2)) ] raise: Error.
	self assert: state first equals: 5.
	"the twin takes an empty one, which the primitive refuses"
	self assert: (UtilsPluginSmalltalk splitMix64OutputsOf: state into: DoubleWordArray new) isEmpty.
	array := DoubleWordArray new: 3.
	self assert: (random primOutputsOf: state into: array) identicalTo: array.
	self assert: array asArray equals: ((SplitMix64 seed: 5) nextIntegers64: 3) asArray.
	self assert: state first equals: (5 + (3 * 16r9E3779B97F4A7C15) bitAnd: 16rFFFFFFFFFFFFFFFF)
]

{ #category : 'tests' }
UtilsPluginPrimitiveTest >> testStrtokFailures [

	| wide |
	wide := 'a b' , (String with: (Character value: 955)).
	self assert: (wide primStrtok: ' ' inclusive: false) isNil.
	self assert: ('a b' primStrtok: ' ' inclusive: nil) isNil.
	self assert: ('a b' primStrtok: { $  } inclusive: false) isNil.
	self assert: ('a b' primStrtok: (String with: (Character value: 955)) inclusive: false) isNil.
	self assert: ('a b' primStrtok: ' ' inclusive: false) equals: #( 'a' 'b' ).
	self assert: ('a b' primStrtok: #[ 32 ] inclusive: false) equals: #( 'a' 'b' )
]
