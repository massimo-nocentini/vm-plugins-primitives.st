"
I test the points of Bezier curves, `SequenceableCollection>>#bezierPointsAt:` and `UtilsPlugin class>>#deCasteljau:into:at:`, on both backends.
"
Class {
	#name : 'UtilsPluginDeCasteljauTest',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'helpers' }
UtilsPluginDeCasteljauTest >> textbookPointOf: points at: t [
	"Repeated linear interpolation"

	| ps |
	ps := points collect: [ :each | each x asFloat @ each y asFloat ].
	[ ps size > 1 ] whileTrue: [
		ps := (1 to: ps size - 1) collect: [ :index |
			      (ps at: index) * (1 - t) + ((ps at: index + 1) * t) ] ].
	^ ps first
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testAgainstTheTextbook [

	| random |
	random := Random seed: 11.
	1 to: 500 do: [ :round |
		| points t point expected |
		points := (1 to: (random nextInteger: 12)) collect: [ :index |
			          (random next * 200 - 100) @ (random next * 200 - 100) ].
		t := random next.
		point := points bezierPointAt: t.
		expected := self textbookPointOf: points at: t.
		self assert: (point x closeTo: expected x precision: 1.0e-9).
		self assert: (point y closeTo: expected y precision: 1.0e-9) ]
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testEndpoints [

	| random |
	random := Random seed: 3.
	1 to: 200 do: [ :round |
		| points |
		points := (1 to: (random nextInteger: 10)) collect: [ :index |
			          (random next * 10) @ (random next * 10) negated ].
		self assert: (points bezierPointAt: 0) equals: points first.
		self assert: (points bezierPointAt: 1) equals: points last ]
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testErrors [

	self should: [ #(  ) bezierPointAt: 0.5 ] raise: CollectionIsEmpty.
	self should: [ #( 1 2 ) bezierPointAt: 0.5 ] raise: Error.
	self
		should: [
			UtilsPlugin
				deCasteljau: { 0 @ 0. 1 @ 1 }
				into: (Array new: 1)
				at: #( 0 1 ) ]
		raise: SubscriptOutOfBounds.
	self
		should: [
			UtilsPlugin
				deCasteljau: { 0 @ 0. 1 @ 1 }
				into: (self readOnly: (Array new: 2))
				at: #( 0 1 ) ]
		raise: ModificationForbidden
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testExtrapolation [
	"Outside [0, 1] the curve goes on; no ZeroDivide, NaN in, NaN out"

	| points |
	points := { 0 @ 0. 1 @ 2. 2 @ 0 }.
	self assert: ((points bezierPointAt: 2) x closeTo: 4.0).
	self assert: ((points bezierPointAt: 2) y closeTo: -8.0).
	self assert: (points bezierPointAt: Float nan) x isNaN.
	"at -1 the scheme divides by zero: an IEEE infinity, then NaNs"
	self shouldnt: [ points bezierPointsAt: #( -1 1.5 3 -2 1.0e300 ) ] raise: ZeroDivide
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testIntoTheControlPoints [
	"The control points are all read before the curve points are stored"

	| points |
	points := { 0 @ 0. 10 @ 20 }.
	UtilsPlugin deCasteljau: points into: points at: #( 1 0.5 ).
	self assert: points equals: { 10.0 @ 20.0. 5.0 @ 10.0 }
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testKindsOfNumbers [

	| floats |
	floats := { 0.0 @ 0.0. 1.0 @ 0.5. 3.0 @ 2.0 } bezierPointsAt: #( 0.25 0.75 ).
	self
		assert: ({ 0 @ 0. 1 @ (1 / 2). 3 @ 2 } bezierPointsAt: #( 0.25 0.75 ))
		equals: floats.
	self
		assert: ({ 0 @ 0. 1 @ (1 / 2). 3 @ 2 } bezierPointsAt: { 1 / 4. 3 / 4 })
		equals: floats.
	self
		assert: ({ 0 @ 0. 1 @ (1 / 2). 3 @ 2 } asOrderedCollection bezierPointsAt: (0.25 to: 0.75 by: 0.5))
		equals: floats
]

{ #category : 'tests' }
UtilsPluginDeCasteljauTest >> testSmallCurves [

	| point |
	self assert: ({ 3.5 @ -2 } bezierPointAt: 0.25) equals: 3.5 @ -2.0.
	self assert: ({ 0 @ 0. 10 @ 20 } bezierPointAt: 0.5) equals: 5.0 @ 10.0.
	point := { 0 @ 0. 1 @ 2. 2 @ 0 } bezierPointAt: 0.5.
	self assert: (point x closeTo: 1.0).
	self assert: (point y closeTo: 1.0).
	self assert: point x isFloat.
	self assert: point y isFloat
]
