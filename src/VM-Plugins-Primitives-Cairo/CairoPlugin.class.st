"
I am the image side of the CairoPlugin of the Pharo VM (pharo-vm: plugins/CairoPlugin; docs/CairoPlugin.md is the contract): Athens drawing through cairo with named primitives instead of uFFI's callouts, on the same libcairo the FFI loads.

Loading the package on a VM with the plugin binds it and installs every group (see below; on a VM without it, it changes nothing); `CairoPlugin install` binds the plugin to cairo (`bind`) and patches the hot methods of Athens-Cairo at run time, by group:
- `#basic`: one primitive per FFI callout (newPath, moveToX:Y:, fill, the matrix functions, ...);
- `#shape`: `AthensCairoCanvas>>draw` of a Rectangle or an AthensCairoPath painted with a Color or a stroke of a Color, in one primitive;
- `#text`: `drawString:` (`CairoFreetypeFontRenderer>>renderCharacters:from:to:`) in one primitive, for ByteString, ByteSymbol, WideString and WideSymbol (UTF-8 by simdutf in the plugin).

Each patch keeps the original under `ffi<Selector>` and falls back to it when its primitive fails (no plugin, unbound, an argument the plugin does not take), so Athens draws the same pixels with or without the plugin. `CairoPlugin uninstall` restores the originals exactly. The patches are installed with the system announcements suspended: Athens-Cairo is not marked modified and Epicea logs nothing (a first install writes the sources of the `ffi…` copies to the .changes file, and on Pharo 14 and later an uninstall writes their removals there).

- `CairoPlugin info` answers `{ protocol. version. 'native'/'emscripten'. cairo version or nil. 'loader'/'static'. missing symbol or nil. missing optional symbols }`, or nil when the VM has no CairoPlugin (`isAvailable`).
- Loading the package installs every group when the VM has the plugin (never without it: a patch whose primitive is missing costs ~60 ns per call); at each image start (`startUp:`) the plugin is bound again and the wanted groups installed, or uninstalled when the VM has no plugin (they are installed again on a later start with one).
- Loading a newer version of the package over installed patches replaces those it compiles differently (`refreshAfterLoad`, the baseline's post-load; `install` and every start do it too).
- `verify` checks the installed patches; `counters`, `primitiveCounters` and `resetCounters` count the cairo calls and the primitive calls made by the plugin.
"
Class {
	#name : 'CairoPlugin',
	#superclass : 'Object',
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'binding' }
CairoPlugin class >> bind [
	"Bind the plugin to the libcairo the FFI uses (CairoLibrary uniqueInstance libraryName, checked with the address of cairo_create the FFI resolves), with the layout table of this image (with the string classes of the text primitive); answer the cairo version (e.g. 11704). Signals CairoPluginError (code: #'no plugin', #runner, #layout, or the failure code of the primitive: #'not found', #'inappropriate operation', #'unsupported operation', #'bad index', #'bad argument')"

	| layout |
	self isAvailable ifFalse: [
		CairoPluginError signal: 'CairoPlugin: the VM has no CairoPlugin' code: #'no plugin' ].
	CairoPluginInstaller runnerIsSameThread ifFalse: [
		self uninstallKeepingWish.
		CairoPluginError
			signal: 'CairoPlugin: CairoLibrary does not run its callouts with TFSameThreadRunner'
			code: #runner ].
	layout := CairoPluginLayout current.
	layout ifNil: [
		CairoPluginError
			signal: 'CairoPlugin: the Athens classes do not fit the plugin: ' , CairoPluginLayout problem
			code: #layout ].
	^ self
		  primBind: self libraryName
		  probe: self probeAddress
		  layout: layout
]

{ #category : 'binding' }
CairoPlugin class >> cairoVersion [
	"The version of the bound cairo (e.g. 11704 for 1.17.4), or nil"

	^ self info ifNotNil: [ :i | i at: 4 ]
]

{ #category : 'counters' }
CairoPlugin class >> counters [
	"Dictionary 'cairo_new_path' -> the number of calls the plugin made to it since the last reset (zeros included; empty without the plugin)"

	^ self countersAt: 1
]

{ #category : 'private' }
CairoPlugin class >> countersAt: index [

	| counts names d |
	d := Dictionary new.
	counts := self primCounters.
	names := self primFunctionNames.
	(counts isNil or: [ names isNil ]) ifTrue: [ ^ d ].
	(names at: index) with: (counts at: index) do: [ :name :count |
		d at: name put: count ].
	^ d
]

{ #category : 'installing' }
CairoPlugin class >> forceInstall: groups [
	"Install groups even when the plugin is not bound or absent, for the tests of the fallback (every patch then runs its original); the guards still apply. Answer the groups installed"

	^ CairoPluginInstaller install: groups force: true
]

{ #category : 'installing' }
CairoPlugin class >> groups [

	^ CairoPluginInstaller groups
]

{ #category : 'plugin' }
CairoPlugin class >> info [
	"{ 1. 'CairoPlugin 1.0'. 'native' or 'emscripten'. cairo version or nil (unbound). 'loader' or 'static'. missing symbol or nil. missing optional symbols }, or nil when the VM has no CairoPlugin"

	^ self primInfo
]

{ #category : 'class initialization' }
CairoPlugin class >> initialize [
	"At the package load: start at each image start, want every group, and install them when the VM has the plugin"

	self unregisterFromSessionManager.
	SessionManager default registerUserClassNamed: self name.
	CairoPluginInstaller wantedGroups: self groups.
	self isAvailable
		ifTrue: [
			[ self install ]
				on: CairoPluginError
				do: [ :e |
					self note: 'not installed: ' , e messageText ] ]
		ifFalse: [ self note: 'the VM has no plugin, Athens keeps its FFI' ]
]

{ #category : 'installing' }
CairoPlugin class >> install [
	"Install every group (see #install:)"

	^ self install: self groups
]

{ #category : 'installing' }
CairoPlugin class >> install: groups [
	"Bind if needed, then install the groups (of #basic #shape #text) whose guards pass, and want them at the next starts; answer the groups installed. Signals CairoPluginError when the VM has no plugin or it cannot be bound (see #bind). What was skipped is in #lastReport"

	self isAvailable ifFalse: [
		CairoPluginError signal: 'CairoPlugin: the VM has no CairoPlugin' code: #'no plugin' ].
	self isBound ifFalse: [ self bind ].
	^ CairoPluginInstaller install: groups force: false
]

{ #category : 'installing' }
CairoPlugin class >> installedGroups [
	"The groups installed, in the order of #groups"

	^ CairoPluginInstaller installedGroups
]

{ #category : 'plugin' }
CairoPlugin class >> isAvailable [
	"Whether the VM has the CairoPlugin"

	^ self info notNil
]

{ #category : 'binding' }
CairoPlugin class >> isBound [
	"Whether the plugin is bound to cairo in this session"

	^ self info
		  ifNil: [ false ]
		  ifNotNil: [ :i | (i at: 4) notNil ]
]

{ #category : 'installing' }
CairoPlugin class >> isInstalled [

	^ self installedGroups notEmpty
]

{ #category : 'installing' }
CairoPlugin class >> lastReport [
	"What the last install, uninstall or verify skipped, refused, healed or found (Strings)"

	^ CairoPluginInstaller lastReport
]

{ #category : 'binding' }
CairoPlugin class >> libraryName [
	"The path of the libcairo the FFI loads"

	^ CairoLibrary uniqueInstance libraryName
]

{ #category : 'private' }
CairoPlugin class >> note: aString [

	Transcript
		show: 'CairoPlugin: ' , aString;
		cr
]

{ #category : 'primitives' }
CairoPlugin class >> primBind: libraryPath probe: anExternalAddress layout: anArray [
	"Bind the plugin (primitiveBind): libraryPath, the libcairo the FFI loads (a ByteString of at most 255 bytes); anExternalAddress, the address of cairo_create the FFI resolves in it; anArray, the layout table (CairoPluginLayout current: 29 SmallIntegers then the string classes the text primitive takes, ByteString ByteSymbol WideString WideSymbol; a table of only the 29 SmallIntegers binds too, without text). Answer the cairo version; signal CairoPluginError with the failure code otherwise"

	<primitive: 'primitiveBind' module: 'CairoPlugin' error: ec>
	^ CairoPluginError
		  signal: 'CairoPlugin: binding to ' , libraryPath printString , ' failed: ' , ec printString
		  code: ec
]

{ #category : 'primitives' }
CairoPlugin class >> primCounters [
	"{ the cairo calls by function. the successful calls by primitive } (Arrays of SmallIntegers, in the order of #primFunctionNames), or nil without the plugin"

	<primitive: 'primitiveCounters' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'primitives' }
CairoPlugin class >> primFunctionNames [
	"{ the cairo function names ('cairo_new_path', ...). the primitive names ('primitiveNewPath', ...) }, or nil without the plugin"

	<primitive: 'primitiveFunctionNames' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'primitives' }
CairoPlugin class >> primInfo [

	<primitive: 'primitiveInfo' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'primitives' }
CairoPlugin class >> primResetCounters [

	<primitive: 'primitiveResetCounters' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'primitives' }
CairoPlugin class >> primUnbind [

	<primitive: 'primitiveUnbind' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'counters' }
CairoPlugin class >> primitiveCounters [
	"Dictionary 'primitiveNewPath' -> the number of its successful calls since the last reset (empty without the plugin)"

	^ self countersAt: 2
]

{ #category : 'binding' }
CairoPlugin class >> probeAddress [
	"The address of cairo_create that the FFI resolves in its libcairo (nil when it cannot): the bind checks that the plugin resolves the same one, i.e. uses the same libcairo"

	^ [ ExternalAddress loadSymbol: 'cairo_create' module: self libraryName ]
		  on: Error
		  do: [ :e | nil ]
]

{ #category : 'counters' }
CairoPlugin class >> resetCounters [

	self primResetCounters
]

{ #category : 'system startup' }
CairoPlugin class >> startUp: resuming [
	"At an image start (after the FFI): bind again and install the wanted groups (a no-op when installed; heals drift), then verify; when the plugin cannot be bound (no plugin, another cairo, the runner changed) uninstall the installed groups but keep them wanted, so that a start on a VM with the plugin installs them again"

	resuming ifFalse: [ ^ self ].
	(self wantedGroups isEmpty and: [ self installedGroups isEmpty ]) ifTrue: [
		^ self ].
	self isAvailable ifFalse: [
		self installedGroups isEmpty ifFalse: [
			self uninstallKeepingWish.
			self note: 'the VM has no plugin: uninstalled (still wanted: '
				, self wantedGroups printString , ')' ].
		^ self ].
	[
	self bind.
	self wantedGroups isEmpty ifFalse: [ self install: self wantedGroups ].
	self verify ]
		on: Error
		do: [ :e |
			self uninstallKeepingWish.
			self note: 'not installed at this start: ' , e messageText ]
]

{ #category : 'installing' }
CairoPlugin class >> refreshAfterLoad [
	"After a load of the package (the post-load of BaselineOfVMPluginsPrimitives): a newer version loaded over the patches an older one installed replaces those it compiles differently (class initialize runs again only when its own source changed); nothing when no patch is stale"

	(self isInstalled and: [ CairoPluginInstaller hasStalePatches ]) ifFalse: [ ^ self ].
	[
	self install: self installedGroups.
	self note: 'stale patches replaced, installed ' , self installedGroups printString ]
		on: CairoPluginError
		do: [ :e | self note: 'stale patches not replaced: ' , e messageText ]
]

{ #category : 'binding' }
CairoPlugin class >> unbind [
	"Unbind the plugin (every patched method then falls back to its original): for the tests of the fallback with the plugin present"

	self primUnbind
]

{ #category : 'installing' }
CairoPlugin class >> uninstall [
	"Uninstall every group and want none"

	self uninstall: self groups.
	CairoPluginInstaller wantedGroups: #(  )
]

{ #category : 'installing' }
CairoPlugin class >> uninstall: groups [
	"Uninstall groups and stop wanting them; answer the groups still installed"

	| left |
	left := CairoPluginInstaller uninstall: groups.
	CairoPluginInstaller wantedGroups:
		(self wantedGroups reject: [ :g | groups includes: g ]).
	^ left
]

{ #category : 'private' }
CairoPlugin class >> uninstallKeepingWish [
	"Uninstall every group, keeping the wanted groups"

	CairoPluginInstaller uninstall: self groups
]

{ #category : 'class initialization' }
CairoPlugin class >> unload [
	"At the package unload: restore Athens and stop starting"

	self uninstall.
	self unregisterFromSessionManager
]

{ #category : 'private' }
CairoPlugin class >> unregisterFromSessionManager [

	[ SessionManager default unregisterClassNamed: self name ]
		on: Error
		do: [ :e | "not registered" ]
]

{ #category : 'installing' }
CairoPlugin class >> verify [
	"Check the installed patches; answer the problems (Strings), empty when consistent: drift ('AthensCairoCanvas>>newPath: not patched any more'), 'installed but unbound', the runner (then every group is uninstalled, the wanted groups kept), stale patches (of an older version of the package: install replaces them), subclass overrides and guard mismatches (the group is uninstalled, a #basic method alone; still wanted), missing optional symbols. Heals a patch overwritten by uFFI's first-call generation and says so"

	^ CairoPluginInstaller verify
]

{ #category : 'installing' }
CairoPlugin class >> wantedGroups [
	"The groups installed at each image start on a VM with the plugin"

	^ CairoPluginInstaller wantedGroups
]
