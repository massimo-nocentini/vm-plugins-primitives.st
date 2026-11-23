"
I mirror `AthensCairoPathBuilder`: I declare exactly its instance variables, in its order, so that my methods compile here and, unchanged, in `AthensCairoPathBuilder` (see `CairoPluginMirrorAthensCairoCanvas`). I am never instantiated.
"
Class {
	#name : 'CairoPluginMirrorAthensCairoPathBuilder',
	#superclass : 'Object',
	#instVars : [
		'context',
		'absolute',
		'endPoint',
		'lastControlPoint'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'CairoPlugin basic' }
CairoPluginMirrorAthensCairoPathBuilder >> cairoPluginCopyPathInto: aPath [
	<cairoPluginAdded: #basic patch: #copyPath>
	<primitive: 'primitiveBuilderCopyPath' module: 'CairoPlugin'>
	^ self ffiCopyPath
]

{ #category : 'CairoPlugin basic' }
CairoPluginMirrorAthensCairoPathBuilder >> copyPath [
	"Installed by CairoPlugin (group #basic): primitiveBuilderCopyPath of the CairoPlugin, into a new
	AthensCairoPath as uFFI answers it; its original, the FFI callout of Athens, is #ffiCopyPath,
	which runs when the primitive fails."
	<cairoPluginPatch: #basic>
	^ self cairoPluginCopyPathInto: AthensCairoPath basicNew
]
