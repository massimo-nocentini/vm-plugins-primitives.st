"
I test the splitting of strings, `String>>#strtok:inclusive:` and `String>>#linesIncludeEmptySubstrings:`, on both backends.
"
Class {
	#name : 'UtilsPluginStrtokTest',
	#superclass : 'UtilsPluginTestCase',
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'helpers' }
UtilsPluginStrtokTest >> assertSplit: aString by: delimiters inclusive: aBoolean is: pieces [

	| answer |
	answer := aString strtok: delimiters inclusive: aBoolean.
	self assert: answer class equals: Array.
	self assert: answer equals: pieces asArray.
	answer do: [ :each | self deny: each identicalTo: aString ]
]

{ #category : 'helpers' }
UtilsPluginStrtokTest >> lf [

	^ String lf
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testBadArguments [

	self should: [ 'a b' strtok: ' ' inclusive: nil ] raise: Error
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testCases [

	| lf cr |
	lf := String lf.
	cr := String cr.
	self assertSplit: '' by: lf inclusive: false is: #(  ).
	self assertSplit: '' by: lf inclusive: true is: #(  ).
	self assertSplit: 'abc' by: ' ' inclusive: false is: #( 'abc' ).
	self assertSplit: 'abc' by: ' ' inclusive: true is: #( 'abc' ).
	self assertSplit: lf by: lf inclusive: false is: #(  ).
	self assertSplit: lf by: lf inclusive: true is: #( '' ).
	self assertSplit: lf , lf by: lf inclusive: true is: #( '' '' ).
	self assertSplit: 'a' , lf by: lf inclusive: true is: #( 'a' ).
	self assertSplit: 'a' , lf , lf by: lf inclusive: true is: #( 'a' '' ).
	self assertSplit: lf , 'a' by: lf inclusive: true is: #( '' 'a' ).
	self assertSplit: 'a' , lf , lf , 'b' by: lf inclusive: true is: #( 'a' '' 'b' ).
	self assertSplit: 'a' , lf , lf , 'b' by: lf inclusive: false is: #( 'a' 'b' ).
	self assertSplit: 'a' , cr , lf , 'b' by: cr , lf inclusive: true is: #( 'a' '' 'b' ).
	self assertSplit: '  a  b ' by: ' ' inclusive: false is: #( 'a' 'b' ).
	self assertSplit: '  a  b ' by: ' ' inclusive: true is: #( '' '' 'a' '' 'b' ).
	self assertSplit: 'a,b;c' by: ',;' inclusive: false is: #( 'a' 'b' 'c' ).
	self assertSplit: 'abc' by: '' inclusive: false is: #( 'abc' ).
	self assertSplit: 'abc' by: '' inclusive: true is: #( 'abc' )
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testDelimiterCollections [

	self assertSplit: 'a,b;c' by: { $,. $; } inclusive: false is: #( 'a' 'b' 'c' ).
	self assertSplit: 'a,b;c' by: #[ 44 59 ] inclusive: false is: #( 'a' 'b' 'c' ).
	self assertSplit: 'a,b;c' by: #',;' inclusive: false is: #( 'a' 'b' 'c' )
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testLines [

	| lf cr |
	lf := String lf.
	cr := String cr.
	self
		assert: ('hello' , lf , 'world' linesIncludeEmptySubstrings: false)
		equals: #( 'hello' 'world' ).
	self
		assert: ('a' , cr , lf , cr , lf , 'b' linesIncludeEmptySubstrings: true)
		equals: #( 'a' '' 'b' ).
	self
		assert: ('a' , cr , lf , cr , lf , 'b' linesIncludeEmptySubstrings: false)
		equals: #( 'a' 'b' )
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testLinesAsPharo [
	"linesIncludeEmptySubstrings: true answers #lines, and false its non-empty lines"

	| random alphabet |
	random := Random seed: 7.
	alphabet := { $a. Character cr. Character lf }.
	1 to: 3000 do: [ :round |
		| text |
		text := String new: (random nextInteger: 12) - 1.
		1 to: text size do: [ :index |
			text at: index put: (alphabet at: (random nextInteger: 3)) ].
		self
			assert: (text linesIncludeEmptySubstrings: true)
			equals: text lines asArray.
		self
			assert: (text linesIncludeEmptySubstrings: false)
			equals: (text lines reject: [ :each | each isEmpty ]) asArray ]
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testNul [
	"NUL is a character like the others"

	| nul |
	nul := String with: Character null.
	self
		assertSplit: 'a' , nul , 'b c'
		by: ' '
		inclusive: false
		is: { 'a' , nul , 'b'. 'c' }.
	self
		assertSplit: 'a' , nul , 'b' , nul
		by: nul
		inclusive: true
		is: #( 'a' 'b' )
]

{ #category : 'tests' }
UtilsPluginStrtokTest >> testSymbolsAndWideStrings [

	| wide |
	self assertSplit: #'a b' by: ' ' inclusive: false is: #( 'a' 'b' ).
	wide := 'a' , (String with: (Character value: 955)) , ' b'.
	self
		assertSplit: wide
		by: ' '
		inclusive: false
		is: { 'a' , (String with: (Character value: 955)). 'b' }.
	self
		assertSplit: 'a b'
		by: (String with: (Character value: 955) with: $ )
		inclusive: false
		is: #( 'a' 'b' )
]
