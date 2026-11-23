"
I check criterion C6 of the CairoPlugin (`docs/CairoPlugin.md`):

- with every group installed and the plugin unbound, or on a VM without the plugin with `forceInstall:`, every patched method falls back to its FFI original and every scene draws the pixels of stock Athens;
- on a VM without the plugin `install` refuses and loading the package installed nothing.

I run on every VM, with or without the plugin.
"
Class {
	#name : 'CairoPluginFallbackTest',
	#superclass : 'CairoPluginTestCase',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginFallbackTest >> assertFallbackParityOf: names [

	| failures |
	failures := OrderedCollection new.
	names do: [ :name |
		| reference bytes |
		reference := self bytesOfScene: name in: #ffi.
		bytes := self bytesOfScene: name in: #fallback.
		bytes = reference ifFalse: [
			failures add: name , ' ' , (CairoPluginTestSupport quickDigestOfBytes: bytes) , ' (ffi '
				, (CairoPluginTestSupport quickDigestOfBytes: reference) , ')' ] ].
	self
		assert: failures isEmpty
		description: [ 'PIXELS-DIFFER in #fallback: ' , failures asArray printString ]
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testBenchScenes [

	self assertFallbackParityOf: self scenes benchSceneNames
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testInstallRefusesWithoutPlugin [

	| error |
	self skipWithPlugin.
	CairoPluginInstaller uninstall: CairoPlugin groups.
	error := nil.
	[ CairoPlugin install ]
		on: CairoPluginError
		do: [ :e | error := e ].
	self assert: error notNil.
	self assert: error code equals: #'no plugin'.
	self assert: CairoPlugin installedGroups isEmpty.
	self deny: CairoPlugin isAvailable.
	self assert: CairoPlugin info isNil
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testLoadInstalledNothingWithoutPlugin [
	"On a VM without the plugin, loading the package (or starting the image) leaves Athens unpatched"

	self skipWithPlugin.
	self assert: savedInstalled isEmpty.
	self deny: ((AthensCairoCanvas >> #newPath) hasPragmaNamed: #cairoPluginPatch:).
	self deny: (AthensCairoCanvas includesSelector: #ffiNewPath)
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testRoassalScene [

	self assertFallbackParityOf: { self scenes roassalScene key }
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testTargetedScenes [

	self assertFallbackParityOf: self scenes targetedSceneNames
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testTextErrorsAsStock [
	"In #fallback, the WideStrings that UTF-8 cannot encode signal the stock error, and a fill outside drawDuring: too"

	| errorsIn |
	errorsIn := [ :mode |
	            | surface canvas errors |
	            self setMode: mode.
	            errors := OrderedCollection new.
	            surface := AthensCairoSurface extent: 30 @ 30.
	            surface drawDuring: [ :c |
		            canvas := c.
		            c setFont: self scenes font.
		            c setPaint: Color black.
		            self scenes invalidWideStrings do: [ :s |
			            errors add: (self errorOf: [ c drawString: s ]) ] ].
	            errors add: (self errorOf: [
			             canvas
				             setPaint: Color red;
				             drawShape: (0 @ 0 extent: 5 @ 5) ]).
	            errors asArray ].
	self assert: (errorsIn value: #fallback) equals: (errorsIn value: #ffi)
]

{ #category : 'tests' }
CairoPluginFallbackTest >> testUnboundVerify [
	"Installed but unbound: verify says so, and every patched method still draws (see the parity tests)"

	self setMode: #fallback.
	self assert: (CairoPlugin verify includes: 'installed but unbound')
]
