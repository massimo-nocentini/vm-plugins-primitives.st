"
I am the abstract superclass of the tests of the CairoPlugin (pharo-vm: plugins/CairoPlugin, docs/CairoPlugin.md). My setUp saves what the tests change, my tearDown restores it: the installed groups, the wanted groups and whether the plugin was bound (the tests switch modes, unbind, force installs).

The tests that need the plugin skip themselves without it, with a reason (`skipUnlessPlugin`), as do those that need its drawing primitives when the plugin of the VM is the stub of a partial build (`skipUnlessImplemented:`); plugin/run-st-tests.sh counts the skips and fails when the plugin was expected. The tests of a VM without the plugin are not applicable with it (`skipWithPlugin`): CairoPluginTestRunner reports them apart. The time limit is 300 seconds (the WebAssembly interpreter is about 30 times slower than Cog). The scenes are `CairoPluginScenes fromEnvironment` (scale 0.05 by default).
"
Class {
	#name : 'CairoPluginTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'savedInstalled',
		'savedWanted',
		'savedBound'
	],
	#classInstVars : [
		'scenes',
		'skipReasons',
		'failureDescriptions'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'reporting' }
CairoPluginTestCase class >> failureDescriptionOf: aTest [
	"How aTest failed or erred last (in its test method), or nil"

	^ CairoPluginTestCase failureDescriptions at: aTest class name , '>>' , aTest selector ifAbsent: [ nil ]
]

{ #category : 'reporting' }
CairoPluginTestCase class >> failureDescriptions [

	^ failureDescriptions ifNil: [ failureDescriptions := Dictionary new ]
]

{ #category : 'skipping' }
CairoPluginTestCase class >> notApplicablePrefix [
	"The start of the reason of a skip that is not one: the test does not apply to this VM"

	^ 'n/a: '
]

{ #category : 'skipping' }
CairoPluginTestCase class >> resetSkipReasons [
	"Forget the reasons of the skips and the descriptions of the failures"

	CairoPluginTestCase setSkipReasons: Dictionary new.
	CairoPluginTestCase failureDescriptions removeAll
]

{ #category : 'skipping' }
CairoPluginTestCase class >> setSkipReasons: aDictionary [

	skipReasons := aDictionary
]

{ #category : 'skipping' }
CairoPluginTestCase class >> skipReasonOf: aTest [
	"The reason aTest gave when it skipped itself last"

	^ CairoPluginTestCase skipReasons at: aTest class name , '>>' , aTest selector ifAbsent: [ '' ]
]

{ #category : 'skipping' }
CairoPluginTestCase class >> skipReasons [

	^ skipReasons ifNil: [ skipReasons := Dictionary new ]
]

{ #category : 'testing' }
CairoPluginTestCase class >> isAbstract [

	^ self == CairoPluginTestCase
]

{ #category : 'accessing' }
CairoPluginTestCase class >> scenes [
	"The scenes of the tests (shared by my subclasses: their data is built once)"

	^ CairoPluginTestCase scenesInstance
]

{ #category : 'accessing' }
CairoPluginTestCase class >> scenesInstance [

	^ scenes ifNil: [ scenes := CairoPluginScenes fromEnvironment ]
]

{ #category : 'helpers' }
CairoPluginTestCase >> bytesOfScene: aName in: aMode [
	"The bytes of the scene aName drawn in aMode"

	self setMode: aMode.
	^ CairoPluginTestSupport bytesOf: (self scenes runScene: aName)
]

{ #category : 'helpers' }
CairoPluginTestCase >> comparableModes [
	"The modes this VM can draw in, to compare with #ffi: #fallback always; #basic and #all when the bound plugin implements their groups"

	| implemented modes |
	implemented := self implementedGroups.
	modes := OrderedCollection new.
	(implemented includes: #basic) ifTrue: [ modes add: #basic ].
	implemented size = CairoPlugin groups size ifTrue: [ modes add: #all ].
	modes add: #fallback.
	^ modes asArray
]

{ #category : 'running' }
CairoPluginTestCase >> defaultTimeLimit [

	^ 300 seconds
]

{ #category : 'helpers' }
CairoPluginTestCase >> errorOf: aBlock [
	"{ class name. messageText } of the error aBlock signals, or nil"

	^ [
	  aBlock value.
	  nil ]
		  on: Error
		  do: [ :e |
			  e return: {
					  e class name.
					  e messageText asString } ]
]

{ #category : 'helpers' }
CairoPluginTestCase >> isFailure: anObject [

	^ anObject isKindOf: CairoPluginPrimitiveFailure
]

{ #category : 'helpers' }
CairoPluginTestCase >> implementedGroups [

	^ CairoPluginTestSupport implementedGroups
]

{ #category : 'accessing' }
CairoPluginTestCase >> scenes [

	^ self class scenes
]

{ #category : 'running' }
CairoPluginTestCase >> performTest [
	"Keep the description of a failure or an error (and where an error happened) for CairoPluginTestRunner, then let SUnit see it"

	^ [ super performTest ]
		  on: Error , TestFailure
		  do: [ :e |
			  | where |
			  where := (e isKindOf: TestFailure)
				           ifTrue: [ '' ]
				           ifFalse: [
					           ' at '
					           , ((e signalerContext stack first: 6) collect: [ :c | c printString ])
						           asArray printString ].
			  CairoPluginTestCase failureDescriptions
				  at: self class name , '>>' , self selector
				  put: e class name , ': ' , e messageText asString , where.
			  e pass ]
]

{ #category : 'helpers' }
CairoPluginTestCase >> setMode: aMode [
	"Put the image in aMode and check that its groups are installed"

	| installed expected |
	installed := CairoPluginTestSupport setMode: aMode.
	expected := aMode = #ffi
		            ifTrue: [ #(  ) ]
		            ifFalse: [
			            aMode = #basic
				            ifTrue: [ #( #basic ) ]
				            ifFalse: [ CairoPlugin groups ] ].
	self
		assert: installed asArray = expected asArray
		description: [
			'mode ' , aMode printString , ': installed ' , installed printString , ', report '
			, CairoPlugin lastReport printString ].
	aMode = #fallback ifTrue: [ self deny: CairoPlugin isBound ]
]

{ #category : 'running' }
CairoPluginTestCase >> setUp [

	super setUp.
	savedInstalled := CairoPlugin installedGroups.
	savedWanted := CairoPlugin wantedGroups.
	savedBound := CairoPlugin isBound
]

{ #category : 'skipping' }
CairoPluginTestCase >> skip: aString [
	"Skip, keeping the reason for CairoPluginTestRunner"

	CairoPluginTestCase skipReasons at: self class name , '>>' , self selector put: aString.
	^ super skip: aString
]

{ #category : 'skipping' }
CairoPluginTestCase >> skipUnlessBound [

	self skipUnlessPlugin.
	CairoPlugin isBound ifFalse: [
		[ CairoPlugin bind ]
			on: CairoPluginError
			do: [ :e |
				^ self skip: 'the CairoPlugin cannot be bound: ' , e messageText ] ]
]

{ #category : 'skipping' }
CairoPluginTestCase >> skipUnlessImplemented: groups [
	"Skip unless the bound plugin implements the primitives of every group of groups"

	| implemented missing |
	self skipUnlessBound.
	implemented := self implementedGroups.
	missing := groups reject: [ :g | implemented includes: g ].
	missing isEmpty ifFalse: [
		self skip: 'the CairoPlugin of this VM does not implement the primitives of '
			, missing printString , ' (a stub plugin answers #''unsupported operation'')' ]
]

{ #category : 'skipping' }
CairoPluginTestCase >> skipUnlessEveryMode: modes [
	"After comparing modes with #ffi: skip, with the reason, unless they were every mode"

	modes size = 3 ifTrue: [ ^ self ].
	CairoPlugin isAvailable ifFalse: [
		^ self skip: 'the VM has no CairoPlugin: compared #ffi to ' , modes printString , ' only' ].
	self skip: 'compared #ffi to ' , modes printString
		, ' only: the CairoPlugin of this VM implements the primitives of '
		, self implementedGroups printString , ' (a stub plugin answers #''unsupported operation'')'
]

{ #category : 'skipping' }
CairoPluginTestCase >> skipUnlessPlugin [

	CairoPlugin isAvailable ifFalse: [ self skip: 'the VM has no CairoPlugin' ]
]

{ #category : 'skipping' }
CairoPluginTestCase >> skipWithPlugin [
	"A test of the VM without the plugin: not applicable with it (CairoPluginTestRunner does not count it as a skip)"

	CairoPlugin isAvailable ifTrue: [
		self skip: self class notApplicablePrefix , 'only on a VM without the CairoPlugin' ]
]

{ #category : 'running' }
CairoPluginTestCase >> tearDown [

	CairoPluginInstaller uninstall: CairoPlugin groups.
	(savedBound and: [ CairoPlugin isBound not ]) ifTrue: [
		[ CairoPlugin bind ]
			on: CairoPluginError
			do: [ :e | "the test checks it" ] ].
	(savedBound not and: [ CairoPlugin isBound ]) ifTrue: [ CairoPlugin unbind ].
	savedInstalled isEmpty ifFalse: [
		CairoPluginInstaller install: savedInstalled force: CairoPlugin isBound not ].
	CairoPluginInstaller wantedGroups: savedWanted.
	super tearDown
]
