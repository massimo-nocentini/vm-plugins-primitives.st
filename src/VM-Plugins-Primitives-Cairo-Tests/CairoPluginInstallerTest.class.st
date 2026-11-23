"
I check criterion C7 of the CairoPlugin (`docs/CairoPlugin.md`), the installer:

- after a warm-up (every scene drawn once, the garbage collected: uFFI has generated every callout), `install` then `uninstall` leaves every target class and metaclass as it was (the same selectors, uFFI's source stub at each patched selector, the identical methods elsewhere, the same protocols), Athens-Cairo is not marked modified (Monticello, the package) and Epicea logs nothing;
- a reinstall compiles nothing (the `.changes` file does not grow);
- `install` twice is `install` once, and so is `uninstall`;
- drift is reported by `verify`, kept by `uninstall`, healed by `install`;
- a uFFI overwrite is healed by `verify`;
- a collision, a changed replicated method and a subclass override are refused.

I run on every VM: with the plugin through `install:`, without it through `forceInstall:` (the guards apply alike).
"
Class {
	#name : 'CairoPluginInstallerTest',
	#superclass : 'CairoPluginTestCase',
	#instVars : [
		'snapshot',
		'flags'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'helpers' }
CairoPluginInstallerTest >> athensFlags [
	"{ Monticello's modified flag of Athens-Cairo. its package's dirty flag. the number of Epicea entries }"

	| workingCopies copy package epicea |
	workingCopies := (MCWorkingCopy respondsTo: #allWorkingCopies)
		                 ifTrue: [ MCWorkingCopy allWorkingCopies ]
		                 ifFalse: [ MCWorkingCopy allManagers ].
	copy := workingCopies detect: [ :w | w packageName = 'Athens-Cairo' ] ifNone: [ nil ].
	package := PackageOrganizer default packageNamed: 'Athens-Cairo' ifAbsent: [ nil ].
	epicea := [ EpMonitor current log entriesCount ]
		          on: Error
		          do: [ :e | -1 ].
	^ {
		  (copy ifNotNil: [ copy modified ]).
		  (package ifNotNil: [ package isDirty ]).
		  epicea }
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> changesSize [

	^ SourceFiles changesFileStream size
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> diffFrom: before to: after [
	"The keys whose values differ (methods compared by identity)"

	| diffs |
	diffs := OrderedCollection new.
	(before keys asSet , after keys asSet) do: [ :k |
		| x y same |
		x := before at: k ifAbsent: [ nil ].
		y := after at: k ifAbsent: [ nil ].
		same := (x isArray and: [ y isArray and: [ x size = 2 and: [ y size = 2 and: [ x first isCompiledMethod ] ] ] ])
			        ifTrue: [ x first == y first and: [ x last = y last ] ]
			        ifFalse: [ x = y ].
		same ifFalse: [ diffs add: k ] ].
	^ diffs asSortedCollection asArray
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> install: groups [
	"Install groups with the plugin, or forced without it; answer the groups installed"

	^ CairoPlugin isAvailable
		  ifTrue: [ CairoPlugin install: groups ]
		  ifFalse: [ CairoPlugin forceInstall: groups ]
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> isPatched: aClass at: aSelector [

	^ (aClass compiledMethodAt: aSelector ifAbsent: [ nil ])
		  ifNil: [ false ]
		  ifNotNil: [ :m | m hasPragmaNamed: #cairoPluginPatch: ]
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> newClassNamed: aName superclass: aClass [
	"A class created for a test, in the package CairoPlugin-TestScratch (removed by #removeClassNamed:)"

	CairoPluginInstaller quietly: [
		(aClass respondsTo: #<<)
			ifTrue: [
				(aClass << aName)
					package: 'CairoPlugin-TestScratch';
					install ]
			ifFalse: [
				aClass
					subclass: aName
					instanceVariableNames: ''
					classVariableNames: ''
					package: 'CairoPlugin-TestScratch' ] ].
	^ Smalltalk globals at: aName
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> removeClassNamed: aName [

	CairoPluginInstaller quietly: [
		(Smalltalk globals at: aName ifAbsent: [ nil ]) ifNotNil: [ :c | c removeFromSystem ].
		(PackageOrganizer default packageNamed: 'CairoPlugin-TestScratch' ifAbsent: [ nil ])
			ifNotNil: [ :p | p removeFromSystem ] ]
]

{ #category : 'running' }
CairoPluginInstallerTest >> setUp [

	super setUp.
	CairoPluginInstaller uninstall: CairoPlugin groups.
	CairoPluginTestSupport warmUp: self scenes.
	snapshot := self targetsSnapshot.
	flags := self athensFlags
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> targetClassNames [

	^ #( #AthensCairoCanvas #AthensCairoPathBuilder #AthensCairoPath #AthensCairoMatrix #AthensCairoPaintMode
	     #AthensCairoSurface #CairoScaledFont #CairoFreetypeFontRenderer #CairoFontMetricsProvider )
]

{ #category : 'helpers' }
CairoPluginInstallerTest >> targetsSnapshot [
	"For every target class and metaclass: its selectors, its protocols, and per selector the method (uFFI's source stub for a generated callout) and its protocol"

	| d |
	d := Dictionary new.
	self targetClassNames do: [ :n |
		| c |
		c := Smalltalk globals at: n.
		{ c. c class } do: [ :cls |
			d at: cls name , ' selectors' put: cls selectors asSortedCollection asArray.
			d at: cls name , ' protocols' put: (cls protocolNames collect: [ :p | p asString ]) asSortedCollection asArray.
			cls selectors do: [ :s |
				| m |
				m := cls compiledMethodAt: s.
				d at: cls name , '>>' , s put: {
						(m propertyAt: #ffiNonCompiledMethod ifAbsent: [ m ]).
						(cls protocolNameOfSelector: s) } ] ] ].
	^ d
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testCollisionRefusesTheGroup [

	| before answer |
	CairoPluginInstaller quietly: [
		AthensCairoCanvas compile: 'ffiNewPath
	^ 42' classified: #private withStamp: nil notifying: nil logSource: false ].
	[
	before := self targetsSnapshot.
	answer := self install: #( #basic ).
	self assert: answer isEmpty.
	self assert: (CairoPlugin lastReport anySatisfy: [ :s | s includesSubstring: 'collision' ]).
	self assert: (self diffFrom: before to: self targetsSnapshot) isEmpty ] ensure: [
		CairoPluginInstaller quietly: [ AthensCairoCanvas removeSelector: #ffiNewPath ] ].
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testDriftIsReportedKeptAndHealed [

	| original protocol report |
	self install: CairoPlugin groups.
	original := CairoPluginInstaller originalAt: #( #AthensCairoCanvas false #fill ).
	protocol := AthensCairoCanvas protocolNameOfSelector: #fill.
	[
	CairoPluginInstaller quietly: [
		AthensCairoCanvas compile: original sourceCode classified: protocol withStamp: nil notifying: nil logSource: false ].
	report := CairoPlugin verify.
	self assert: (report includes: 'AthensCairoCanvas>>fill: not patched any more').
	CairoPlugin uninstall.
	self deny: (self isPatched: AthensCairoCanvas at: #fill).
	self deny: (AthensCairoCanvas >> #fill) == original.
	self assert: (CairoPlugin lastReport anySatisfy: [ :s | s beginsWith: 'AthensCairoCanvas>>fill: not patched any more' ]).
	self deny: (AthensCairoCanvas includesSelector: #ffiFill).
	self install: CairoPlugin groups.
	self assert: (self isPatched: AthensCairoCanvas at: #fill) ] ensure: [
		CairoPlugin uninstall.
		CairoPluginInstaller quietly: [
			CairoPluginInstaller put: original in: AthensCairoCanvas at: #fill protocol: protocol ] ].
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testGuardMismatchRefusesShapeAndText [
	"A replicated method whose source changed (Color>>red) refuses the groups that replicate it"

	| original answer |
	original := Color >> #red.
	[
	CairoPluginInstaller quietly: [
		Color compile: 'red
	"changed"
	^ self privateRed asFloat / ComponentMax' classified: original protocolName withStamp: nil notifying: nil logSource: false ].
	answer := self install: #( #shape #text ).
	self assert: answer isEmpty.
	self assert: (CairoPlugin lastReport select: [ :s | s includesSubstring: 'Color>>red' ]) size equals: 2 ] ensure: [
		CairoPluginInstaller quietly: [
			CairoPluginInstaller put: original in: Color at: #red protocol: original protocolName ] ].
	self assert: Color >> #red identicalTo: original
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testInstallAndUninstall [
	"install then uninstall leaves the targets as they were: the stubs, the protocols, the flags of Athens-Cairo, Epicea"

	| answer records stub installedFlags |
	stub := (AthensCairoCanvas >> #newPath) propertyAt: #ffiNonCompiledMethod ifAbsent: [ nil ].
	self assert: stub notNil description: 'after the warm-up newPath is a callout uFFI generated'.
	answer := self install: CairoPlugin groups.
	self assert: answer equals: CairoPlugin groups.
	records := CairoPluginInstaller records.
	self assert: (records at: #basic) size equals: 60.
	self assert: (records at: #shape) size equals: 1.
	self assert: (records at: #shape) first added size equals: 4.
	self assert: (records at: #text) size equals: 1.
	self assert: (records at: #text) first added size equals: 1.
	self assert: (self isPatched: AthensCairoCanvas at: #newPath).
	self assert: (self isPatched: AthensCairoPath class at: #primDestroyPath:).
	self assert: (CairoPluginInstaller originalAt: #( #AthensCairoCanvas false #newPath )) identicalTo: stub.
	self assert: (AthensCairoCanvas includesSelector: #ffiNewPath).
	self assert: (AthensCairoCanvas includesSelector: #ffiDraw).
	self assert: (AthensCairoCanvas protocolNameOfSelector: #cairoPluginFillRectangle:color:)
		equals: (AthensCairoCanvas protocolNameOfSelector: #draw).
	self
		assert: (AthensCairoCanvas protocolNames collect: [ :p | p asString ]) asSortedCollection asArray
		equals: (snapshot at: 'AthensCairoCanvas protocols').
	installedFlags := self athensFlags.
	self assert: installedFlags equals: flags.
	CairoPlugin uninstall.
	self assert: CairoPlugin installedGroups isEmpty.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty.
	self assert: (AthensCairoCanvas compiledMethodAt: #newPath) identicalTo: stub.
	self assert: self athensFlags equals: flags
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testInstallTwiceUninstallTwice [

	| installed |
	self install: CairoPlugin groups.
	installed := self targetsSnapshot.
	self install: CairoPlugin groups.
	self assert: (self diffFrom: installed to: self targetsSnapshot) isEmpty.
	CairoPlugin uninstall.
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testOptionalSymbolsMissing [
	"C10: a plugin bound without the optional cairo_ft functions (simulated): #text and the patches of lock and unlock are skipped"

	| original answer |
	original := CairoPluginInstaller class >> #missingOptionalSymbols.
	[
	CairoPluginInstaller quietly: [
		CairoPluginInstaller class compile: 'missingOptionalSymbols
	^ #( ''cairo_ft_scaled_font_lock_face'' )' classified: original protocolName withStamp: nil notifying: nil logSource: false ].
	answer := self install: CairoPlugin groups.
	self assert: answer equals: #( #basic #shape ).
	self deny: (self isPatched: CairoScaledFont at: #lock).
	self deny: (self isPatched: CairoScaledFont at: #unlock).
	self assert: (self isPatched: CairoScaledFont at: #getExtents:) ] ensure: [
		CairoPluginInstaller quietly: [
			CairoPluginInstaller put: original in: CairoPluginInstaller class at: #missingOptionalSymbols protocol: original protocolName ] ].
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testReinstallCompilesNothing [

	| size cached |
	self install: CairoPlugin groups.
	CairoPlugin uninstall.
	size := self changesSize.
	cached := CairoPluginInstaller cache at: #( #AthensCairoCanvas false #newPath ).
	self install: CairoPlugin groups.
	self assert: self changesSize equals: size.
	self assert: AthensCairoCanvas >> #newPath identicalTo: cached method.
	self assert: (AthensCairoCanvas compiledMethodAt: #ffiNewPath) identicalTo: cached ffiCopy.
	self assert: self athensFlags equals: flags.
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testRunnerSwitch [
	"C10: CairoLibrary running its callouts with another runner than TFSameThreadRunner: verify uninstalls every group and keeps them wanted, install refuses"

	| report error |
	self install: CairoPlugin groups.
	CairoPluginInstaller quietly: [
		CairoLibrary compile: 'runner
	^ Object new' classified: #test withStamp: nil notifying: nil logSource: false ].
	[
	report := CairoPlugin verify.
	self assert: CairoPlugin installedGroups isEmpty.
	self assert: CairoPlugin wantedGroups equals: CairoPlugin groups.
	self assert: (report anySatisfy: [ :s | s beginsWith: 'runner is not TFSameThreadRunner' ]).
	error := nil.
	[ self install: CairoPlugin groups ]
		on: CairoPluginError
		do: [ :e | error := e ].
	self assert: error notNil.
	self assert: error code equals: #runner ] ensure: [
		CairoPluginInstaller quietly: [ CairoLibrary removeSelector: #runner ] ].
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testGuardChangeAfterInstallUninstallsTheGroup [
	"A replicated method (Color>>red) changed after the install: verify, and install, uninstall the groups that replicate it (the primitives would bypass the change), which stay wanted; with the method back they install again"

	| original changed report answer |
	original := Color >> #red.
	changed := 'red
	"changed"
	^ self privateRed asFloat / ComponentMax'.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	[
	CairoPluginInstaller quietly: [
		Color compile: changed classified: original protocolName withStamp: nil notifying: nil logSource: false ].
	report := CairoPlugin verify.
	self assert: (report includes: 'guard: Color>>red has a source CairoPlugin was not verified with (group #shape uninstalled)').
	self assert: (report includes: 'guard: Color>>red has a source CairoPlugin was not verified with (group #text uninstalled)').
	self assert: CairoPlugin installedGroups equals: #( #basic ).
	self assert: CairoPlugin wantedGroups equals: CairoPlugin groups.
	self deny: (self isPatched: AthensCairoCanvas at: #draw).
	self deny: (AthensCairoCanvas includesSelector: #ffiDraw).
	self deny: (AthensCairoCanvas includesSelector: #cairoPluginFillRectangle:color:).
	"install: refused, and an installed group whose guard fails is uninstalled by install as well"
	CairoPluginInstaller quietly: [
		CairoPluginInstaller put: original in: Color at: #red protocol: original protocolName ].
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	CairoPluginInstaller quietly: [
		Color compile: changed classified: original protocolName withStamp: nil notifying: nil logSource: false ].
	answer := self install: CairoPlugin groups.
	self assert: answer equals: #( #basic ).
	self assert: (CairoPlugin lastReport anySatisfy: [ :s | s beginsWith: '#shape uninstalled: guard: Color>>red' ]).
	self assert: (CairoPlugin lastReport anySatisfy: [ :s | s beginsWith: '#text uninstalled: guard: Color>>red' ]).
	self deny: (self isPatched: CairoFreetypeFontRenderer at: #renderCharacters:from:to:) ] ensure: [
		CairoPluginInstaller quietly: [
			CairoPluginInstaller put: original in: Color at: #red protocol: original protocolName ] ].
	self assert: Color >> #red identicalTo: original.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testRecompiledTargetUninstallsCleanly [
	"A target class recompiled while the patches are installed (recompileAll, a class variable added: new methods from the same sources): uninstall still recognises and removes its ffi copies, and the groups install again"

	| selectors classSelectors |
	selectors := AthensCairoMatrix selectors asSet.
	classSelectors := AthensCairoMatrix class selectors asSet.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	self assert: (AthensCairoMatrix includesSelector: #ffiPrimSetScaleX:Y:).
	CairoPluginInstaller quietly: [ AthensCairoMatrix recompile ].
	self assert: (self isPatched: AthensCairoMatrix at: #primSetScaleX:Y:).
	CairoPlugin uninstall.
	self deny: (CairoPlugin lastReport anySatisfy: [ :s | s includesSubstring: 'not the copy' ]).
	self assert: AthensCairoMatrix selectors asSet equals: selectors.
	self assert: AthensCairoMatrix class selectors asSet equals: classSelectors.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	self deny: (CairoPlugin lastReport anySatisfy: [ :s | s includesSubstring: 'collision' ]).
	CairoPlugin uninstall.
	self assert: AthensCairoMatrix selectors asSet equals: selectors
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testStalePatchIsReplaced [
	"A newer version of the package loaded over installed patches (here: the mirror of draw and the primitive of a row of the table changed): verify reports the stale patches, install replaces them"

	| mirrorDraw table report |
	mirrorDraw := CairoPluginMirrorAthensCairoCanvas >> #draw.
	table := CairoPluginInstaller class >> #basicTable.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	self assert: CairoPluginInstaller hasStalePatches not.
	[
	CairoPluginInstaller quietly: [
		CairoPluginMirrorAthensCairoCanvas
			compile: mirrorDraw sourceCode , '
	"VERSION2"'
			classified: mirrorDraw protocolName
			withStamp: nil
			notifying: nil
			logSource: false.
		CairoPluginInstaller class
			compile: (table sourceCode copyReplaceAll: '''primitivePaint''' with: '''primitivePaintV2''')
			classified: table protocolName
			withStamp: nil
			notifying: nil
			logSource: false ].
	self assert: CairoPluginInstaller hasStalePatches.
	report := CairoPlugin verify.
	self assert: (report includes: 'stale patch: AthensCairoCanvas>>draw (group #shape; install replaces it)').
	self assert: (report includes: 'stale patch: AthensCairoCanvas>>primPaint (group #basic; install replaces it)').
	self assert: (report select: [ :each | each beginsWith: 'stale' ]) size equals: 2.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	self assert: (CairoPlugin lastReport includes: 'stale patch replaced: AthensCairoCanvas>>draw (group #shape)').
	self assert: (CairoPlugin lastReport includes: 'stale patch replaced: AthensCairoCanvas>>primPaint (group #basic)').
	self assert: ((AthensCairoCanvas >> #draw) sourceCode includesSubstring: 'VERSION2').
	self assert: ((AthensCairoCanvas >> #primPaint) sourceCode includesSubstring: 'primitivePaintV2').
	self deny: CairoPluginInstaller hasStalePatches.
	self deny: (CairoPlugin verify anySatisfy: [ :each | each beginsWith: 'stale' ]) ] ensure: [
		CairoPluginInstaller quietly: [
			CairoPluginInstaller put: mirrorDraw in: CairoPluginMirrorAthensCairoCanvas at: #draw protocol: mirrorDraw protocolName.
			CairoPluginInstaller put: table in: CairoPluginInstaller class at: #basicTable protocol: table protocolName ] ].
	"the sources of this version again: stale once more, replaced by an install, and uninstall restores Athens"
	self assert: CairoPluginInstaller hasStalePatches.
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	self deny: ((AthensCairoCanvas >> #draw) sourceCode includesSubstring: 'VERSION2').
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testUninstallWaitsForARunningPatch [
	"A process preempted inside a patch (draw, about to send an added method) when the patches are uninstalled: the originals are back at once, but what the patch sends stays until no process runs it, so the process finishes its drawing; the next uninstall removes it"

	| patch surface result process steps |
	self assert: (self install: CairoPlugin groups) equals: CairoPlugin groups.
	patch := AthensCairoCanvas >> #draw.
	self assert: (CairoPluginInstaller isPatch: patch).
	surface := AthensCairoSurface extent: 10 @ 10.
	surface drawDuring: [ :c |
		c setPaint: Color red.
		process := [
		           result := [
		                     c drawShape: (0 @ 0 extent: 5 @ 5).
		                     #ok ]
			                     on: Error
			                     do: [ :e | e description ] ] newProcess.
		steps := 0.
		[ process suspendedContext method == patch or: [ steps > 100000 ] ] whileFalse: [
			process step.
			steps := steps + 1 ].
		self assert: process suspendedContext method identicalTo: patch.
		CairoPlugin uninstall.
		self deny: (self isPatched: AthensCairoCanvas at: #draw).
		self assert: (AthensCairoCanvas includesSelector: #ffiDraw).
		self assert: CairoPluginInstaller pending notEmpty.
		process resume.
		steps := 0.
		[ process isTerminated or: [ steps > 500 ] ] whileFalse: [
			(Delay forMilliseconds: 10) wait.
			steps := steps + 1 ] ].
	self assert: result equals: #ok.
	self assert: (surface asForm colorAt: 2 @ 2) equals: Color red.
	CairoPlugin uninstall.
	self assert: CairoPluginInstaller pending isEmpty.
	self deny: (AthensCairoCanvas includesSelector: #ffiDraw).
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testSubclassOverrideRefusesShape [

	| cls report |
	cls := self newClassNamed: #CairoPluginTestScratchSurface superclass: AthensCairoSurface.
	[
	CairoPluginInstaller quietly: [
		cls compile: 'fillRectangle: r withSolidColor: c
	^ super fillRectangle: r withSolidColor: c' classified: #test withStamp: nil notifying: nil logSource: false ].
	self assert: (self install: #( #shape )) isEmpty.
	self assert: (CairoPlugin lastReport anySatisfy: [ :s |
			 s includesSubstring: 'subclass override: CairoPluginTestScratchSurface>>fillRectangle:withSolidColor:' ]).
	CairoPluginInstaller quietly: [ cls removeSelector: #fillRectangle:withSolidColor: ].
	self assert: (self install: #( #shape )) equals: #( #shape ).
	CairoPluginInstaller quietly: [
		cls compile: 'fillRectangle: r withSolidColor: c
	^ super fillRectangle: r withSolidColor: c' classified: #test withStamp: nil notifying: nil logSource: false ].
	report := CairoPlugin verify.
	self assert: CairoPlugin installedGroups isEmpty.
	self assert: (report anySatisfy: [ :s | s includesSubstring: 'subclass override: CairoPluginTestScratchSurface' ]) ]
		ensure: [ self removeClassNamed: #CairoPluginTestScratchSurface ].
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]

{ #category : 'tests' }
CairoPluginInstallerTest >> testUFFIOverwriteIsHealed [
	"A uFFI callout put back at a patched selector (as a first call that was running during the install does): verify puts the patch back and says so"

	| generated report |
	generated := AthensCairoCanvas >> #newPath.
	self assert: (generated propertyAt: #ffiNonCompiledMethod ifAbsent: [ nil ]) notNil.
	self install: CairoPlugin groups.
	AthensCairoCanvas methodDict at: #newPath put: generated.
	report := CairoPlugin verify.
	self assert: (report anySatisfy: [ :s | s beginsWith: 'healed: AthensCairoCanvas>>newPath' ]).
	self assert: (self isPatched: AthensCairoCanvas at: #newPath).
	CairoPlugin uninstall.
	self assert: (self diffFrom: snapshot to: self targetsSnapshot) isEmpty
]
