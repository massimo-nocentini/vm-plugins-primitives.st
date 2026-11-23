"
I check the parts of criterion C8 of the CairoPlugin (`docs/CairoPlugin.md`) that run in one session:

- `CairoPlugin startUp: true` after an unbind binds again and installs the wanted groups on a VM with the plugin, and uninstalls them, keeping them wanted, on a VM without it;
- a NULL handle (what every ExternalAddress of a previous session is at an image start) is refused by the primitives, so the patched methods fall back to the FFI.

`plugin/tests/run-st-tests.sh` checks the rest across image restarts (saved installed, restarted on the plugin VM, then on a VM without the plugin in another directory: exactly one libcairo loaded).
"
Class {
	#name : 'CairoPluginSessionTest',
	#superclass : 'CairoPluginTestCase',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'tests' }
CairoPluginSessionTest >> testNullHandleIsRefused [
	"A canvas whose handle is NULL (a previous session's): the one-for-one primitive fails with #'bad receiver' and calls no cairo function"

	| surface answer counters after |
	self skipUnlessImplemented: #( #basic ).
	surface := AthensCairoSurface extent: 4 @ 4.
	surface drawDuring: [ :c |
		| copy |
		copy := c shallowCopy.
		copy instVarNamed: #handle put: ExternalAddress new.
		counters := CairoPlugin counters.
		answer := CairoPluginTestSupport primitive: #primitiveNewPath receiver: copy arguments: #(  ).
		after := CairoPlugin counters ].
	self assert: (self isFailure: answer).
	self assert: answer code equals: #'bad receiver'.
	self assert: after equals: counters
]

{ #category : 'tests' }
CairoPluginSessionTest >> testStartUpWithPlugin [

	self skipUnlessBound.
	CairoPlugin install: CairoPlugin groups.
	CairoPlugin unbind.
	self deny: CairoPlugin isBound.
	CairoPlugin startUp: true.
	self assert: CairoPlugin isBound.
	self assert: CairoPlugin installedGroups equals: CairoPlugin groups.
	self assert: CairoPlugin verify equals: #(  )
]

{ #category : 'tests' }
CairoPluginSessionTest >> testStartUpWithPluginInstallsTheWantedGroups [

	self skipUnlessBound.
	CairoPluginInstaller uninstall: CairoPlugin groups.
	CairoPluginInstaller wantedGroups: #( #basic #text ).
	CairoPlugin unbind.
	CairoPlugin startUp: true.
	self assert: CairoPlugin isBound.
	self assert: CairoPlugin installedGroups equals: #( #basic #text )
]

{ #category : 'tests' }
CairoPluginSessionTest >> testStartUpWithoutPlugin [

	self skipWithPlugin.
	CairoPlugin forceInstall: CairoPlugin groups.
	CairoPlugin startUp: true.
	self assert: CairoPlugin installedGroups isEmpty.
	self assert: CairoPlugin wantedGroups equals: CairoPlugin groups.
	self deny: ((AthensCairoCanvas >> #newPath) hasPragmaNamed: #cairoPluginPatch:)
]

{ #category : 'tests' }
CairoPluginSessionTest >> testStartUpWithNothingWanted [

	CairoPluginInstaller uninstall: CairoPlugin groups.
	CairoPluginInstaller wantedGroups: #(  ).
	CairoPlugin startUp: true.
	self assert: CairoPlugin installedGroups isEmpty
]
