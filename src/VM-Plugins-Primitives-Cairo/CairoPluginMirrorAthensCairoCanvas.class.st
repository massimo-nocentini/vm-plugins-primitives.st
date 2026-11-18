"
I mirror AthensCairoCanvas: I declare exactly its instance variables, in its order, so that my methods compile here and, unchanged, in AthensCairoCanvas. They are the hand-written templates that `CairoPluginInstaller` compiles into AthensCairoCanvas: the patched methods have the pragma `<cairoPluginPatch: group>`, the methods they call (added to AthensCairoCanvas) the pragma `<cairoPluginAdded: group patch: selector>`. I am never instantiated.
"
Class {
	#name : 'CairoPluginMirrorAthensCairoCanvas',
	#superclass : 'Object',
	#instVars : [
		'paint',
		'surface',
		'shape',
		'fontRenderer',
		'paintMode',
		'paintCache',
		'handle',
		'pathTransform',
		'paintTransform',
		'currentClipRect'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'CairoPlugin shape' }
CairoPluginMirrorAthensCairoCanvas >> cairoPluginFillPath: aPath color: aColor [
	<cairoPluginAdded: #shape patch: #draw>
	<primitive: 'primitiveFillPathColor' module: 'CairoPlugin'>
	^ self ffiDraw
]

{ #category : 'CairoPlugin shape' }
CairoPluginMirrorAthensCairoCanvas >> cairoPluginFillRectangle: aRectangle color: aColor [
	<cairoPluginAdded: #shape patch: #draw>
	<primitive: 'primitiveFillRectangleColor' module: 'CairoPlugin'>
	^ self ffiDraw
]

{ #category : 'CairoPlugin basic' }
CairoPluginMirrorAthensCairoCanvas >> cairoPluginGetScaledFontInto: aScaledFont [
	<cairoPluginAdded: #basic patch: #getScaledFont>
	<primitive: 'primitiveGetScaledFont' module: 'CairoPlugin'>
	^ self ffiGetScaledFont
]

{ #category : 'CairoPlugin shape' }
CairoPluginMirrorAthensCairoCanvas >> cairoPluginStrokePath: aPath paint: aStrokePaint colorClass: aClass [
	<cairoPluginAdded: #shape patch: #draw>
	<primitive: 'primitiveStrokePath' module: 'CairoPlugin'>
	^ self ffiDraw
]

{ #category : 'CairoPlugin shape' }
CairoPluginMirrorAthensCairoCanvas >> cairoPluginStrokeRectangle: aRectangle paint: aStrokePaint colorClass: aClass [
	<cairoPluginAdded: #shape patch: #draw>
	<primitive: 'primitiveStrokeRectangle' module: 'CairoPlugin'>
	^ self ffiDraw
]

{ #category : 'CairoPlugin shape' }
CairoPluginMirrorAthensCairoCanvas >> draw [
	"Installed by CairoPlugin (group #shape): a Rectangle or an AthensCairoPath painted with a Color, or
	with an AthensCairoStrokePaint of a Color, in one primitive making the same cairo calls as Athens;
	anything else, or a failure, through the original (#ffiDraw)."
	<cairoPluginPatch: #shape>
	| s p |
	self class == AthensCairoCanvas ifFalse: [ ^ self ffiDraw ].
	s := shape.
	p := paint.
	s class == Rectangle ifTrue: [
		p class == Color ifTrue: [ ^ self cairoPluginFillRectangle: s color: p ].
		p class == AthensCairoStrokePaint ifTrue: [ ^ self cairoPluginStrokeRectangle: s paint: p colorClass: Color ] ].
	s class == AthensCairoPath ifTrue: [
		p class == Color ifTrue: [ ^ self cairoPluginFillPath: s color: p ].
		p class == AthensCairoStrokePaint ifTrue: [ ^ self cairoPluginStrokePath: s paint: p colorClass: Color ] ].
	^ self ffiDraw
]

{ #category : 'CairoPlugin basic' }
CairoPluginMirrorAthensCairoCanvas >> getScaledFont [
	"Installed by CairoPlugin (group #basic): primitiveGetScaledFont of the CairoPlugin, into a new
	CairoScaledFont as uFFI answers it; its original, the FFI callout of Athens, is #ffiGetScaledFont,
	which runs when the primitive fails."
	<cairoPluginPatch: #basic>
	^ self cairoPluginGetScaledFontInto: CairoScaledFont basicNew
]
