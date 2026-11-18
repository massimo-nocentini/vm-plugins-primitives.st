"
I mirror CairoFreetypeFontRenderer: I declare exactly its instance variables, in its order, so that my methods compile here and, unchanged, in CairoFreetypeFontRenderer (see CairoPluginMirrorAthensCairoCanvas). I am never instantiated.
"
Class {
	#name : 'CairoPluginMirrorCairoFreetypeFontRenderer',
	#superclass : 'Object',
	#instVars : [
		'font',
		'utfConverter',
		'canvas',
		'advance',
		'originalFont',
		'fontExtents',
		'glyphExtents'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'CairoPlugin text' }
CairoPluginMirrorCairoFreetypeFontRenderer >> cairoPluginShowString: aString from: start to: end pixelSize: pixelSize colorClass: aClass [
	<cairoPluginAdded: #text patch: #renderCharacters:from:to:>
	<primitive: 'primitiveShowString' module: 'CairoPlugin'>
	^ nil
]

{ #category : 'CairoPlugin text' }
CairoPluginMirrorCairoFreetypeFontRenderer >> renderCharacters: aString from: start to: end [
	"Installed by CairoPlugin (group #text): the whole drawString: in one primitive when the font has no
	kerning and the paint is a Color; otherwise, or on failure, the original (#ffiRenderCharacters:from:to:)."
	<cairoPluginPatch: #text>
	| ok |
	(originalFont face hasKerning not and: [ canvas paint class == Color ]) ifTrue: [
		ok := self cairoPluginShowString: aString from: start to: end pixelSize: originalFont pixelSize colorClass: Color.
		ok == true ifTrue: [ ^ advance := glyphExtents width @ glyphExtents height ].
		ok == false ifTrue: [ ^ advance ] ].
	^ self ffiRenderCharacters: aString from: start to: end
]
