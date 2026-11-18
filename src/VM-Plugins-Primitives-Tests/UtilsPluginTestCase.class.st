"
I am the abstract superclass of the tests of the package VM-Plugins-Primitives. Each of my subclasses runs every test twice, with the parameter `backend`:
- `#plugin`: through the UtilsPlugin of the VM (skipped when the VM has none);
- `#smalltalk`: with the plugin hidden (`UtilsPlugin pluginHidden: true`), through `UtilsPluginSmalltalk`, as on a VM without the plugin.
"
Class {
	#name : 'UtilsPluginTestCase',
	#superclass : 'ParametrizedTestCase',
	#instVars : [
		'backend'
	],
	#category : 'VM-Plugins-Primitives-Tests',
	#package : 'VM-Plugins-Primitives-Tests'
}

{ #category : 'testing' }
UtilsPluginTestCase class >> isAbstract [

	^ self == UtilsPluginTestCase
]

{ #category : 'building suites' }
UtilsPluginTestCase class >> testParameters [

	^ ParametrizedTestMatrix new
		  forSelector: #backend addOptions: #( #plugin #smalltalk );
		  yourself
]

{ #category : 'accessing' }
UtilsPluginTestCase >> backend [

	^ backend
]

{ #category : 'accessing' }
UtilsPluginTestCase >> backend: aSymbol [

	backend := aSymbol
]

{ #category : 'helpers' }
UtilsPluginTestCase >> bitsOf: aFloat [

	^ aFloat asIEEE64BitWord
]

{ #category : 'helpers' }
UtilsPluginTestCase >> float: aFloat isSameAs: anotherFloat [
	"The same bits, or both NaNs (whose bits the platforms choose)"

	^ (aFloat isNaN and: [ anotherFloat isNaN ]) or: [
		  aFloat class == anotherFloat class and: [
			  (self bitsOf: aFloat) = (self bitsOf: anotherFloat) ] ]
]

{ #category : 'helpers' }
UtilsPluginTestCase >> point: aPoint isSameAs: anotherPoint [

	^ (self float: aPoint x isSameAs: anotherPoint x) and: [
		  self float: aPoint y isSameAs: anotherPoint y ]
]

{ #category : 'helpers' }
UtilsPluginTestCase >> readOnly: anObject [

	anObject beReadOnlyObject.
	^ anObject
]

{ #category : 'running' }
UtilsPluginTestCase >> setUp [

	super setUp.
	UtilsPlugin pluginHidden: false.
	backend = #plugin ifTrue: [
		UtilsPlugin isAvailable ifFalse: [ ^ self skip: 'The VM has no UtilsPlugin' ] ].
	UtilsPlugin pluginHidden: backend = #smalltalk
]

{ #category : 'running' }
UtilsPluginTestCase >> tearDown [

	UtilsPlugin pluginHidden: false.
	super tearDown
]
