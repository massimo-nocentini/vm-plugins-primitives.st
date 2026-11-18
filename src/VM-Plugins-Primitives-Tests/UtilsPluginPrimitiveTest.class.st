"
I test the contract of the primitives of the UtilsPlugin (docs/UtilsPlugin.md): what they answer, and that they fail, leaving their arguments alone, on what they do not take (their Smalltalk twins then answer, or signal the error). I run with the plugin only.
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
	self assert: info second equals: 'UtilsPlugin 1.0'.
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
