"
I compute the layout table that `CairoPlugin bind` passes to the CairoPlugin (pharo-vm: `plugins/CairoPlugin/include/common/cpLayout.h`, `docs/CairoPlugin.md`), an Array of 33 elements:

- positions 1 to 29: SmallIntegers (the 0-based indices of the slots the plugin reads in the Athens objects, computed by name from the running image as uFFI computes its `instVarAt:` indices, and the Color constants);
- positions 30 to 33: the four string classes the text primitive takes (`ByteString`, `ByteSymbol`, `WideString`, `WideSymbol`).

My protocol:

- `CairoPluginLayout current` answers the Array, or nil when the image does not have a slot or a class variable the plugin needs (then `CairoPluginLayout problem` says which, and the plugin is neither bound nor installed); `CairoPluginLayout integers` its first 29 elements.
- `CairoPluginLayout entries` is the table: one row per position, `{ position. name. kind. className. variable }`.
"
Class {
	#name : 'CairoPluginLayout',
	#superclass : 'Object',
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'computing' }
CairoPluginLayout class >> compute [
	"Answer an Association layout -> problem: the Array of 33 elements and nil, or nil and a String saying what is missing"

	| layout |
	layout := Array new: self entries size.
	self entries do: [ :row |
		| value |
		value := self valueOf: row.
		value isString ifTrue: [ ^ nil -> value ].
		layout at: row first put: value ].
	self handleClassNames do: [ :name |
		| cls |
		cls := self globalClassNamed: name.
		cls ifNil: [ ^ nil -> ('class ' , name , ' is missing') ].
		(cls allInstVarNames indexOf: #handle) - 1
		= (layout at: self extObjHandlePosition) ifFalse: [
			^ nil -> (name , ' has its handle in another slot than ExternalObject') ] ].
	(Color classPool at: #ComponentMax ifAbsent: [ nil ])
	= (layout at: self componentMaskPosition) asFloat ifFalse: [
		^ nil -> 'Color ComponentMax is not ComponentMask asFloat' ].
	^ layout -> nil
]

{ #category : 'constants' }
CairoPluginLayout class >> componentMaskPosition [

	^ 27
]

{ #category : 'computing' }
CairoPluginLayout class >> current [
	"Answer the layout table of this image (an Array of 29 SmallIntegers and 4 classes), or nil when it cannot be computed (see #problem)"

	^ self compute key
]

{ #category : 'table' }
CairoPluginLayout class >> entries [
	"One row per position of the table: { position. name. kind. className. variable }, kind #slot (0-based index of the instance variable named variable in className), #classVar (the value of Color's class variable), #constant (variable is the value), #class (the class named className)"

	^ #(
	#( 1 #LAYOUT_VERSION #constant nil 1 )
	#( 2 #CANVAS_HANDLE #slot #AthensCairoCanvas #handle )
	#( 3 #CANVAS_PATH_TRANSFORM #slot #AthensCairoCanvas #pathTransform )
	#( 4 #CANVAS_PAINT #slot #AthensCairoCanvas #paint )
	#( 5 #CANVAS_SURFACE #slot #AthensCairoCanvas #surface )
	#( 6 #SURFACE_HANDLE #slot #AthensCairoSurface #handle )
	#( 7 #BUILDER_CONTEXT #slot #AthensCairoPathBuilder #context )
	#( 8 #EXTOBJ_HANDLE #slot #ExternalObject #handle )
	#( 9 #PAINTMODE_CANVAS #slot #AthensCairoPaintMode #canvas )
	#( 10 #STROKE_FILL_PAINT #slot #AthensCairoStrokePaint #fillPaint )
	#( 11 #STROKE_WIDTH #slot #AthensCairoStrokePaint #width )
	#( 12 #STROKE_CAP #slot #AthensCairoStrokePaint #capStyle )
	#( 13 #STROKE_JOIN #slot #AthensCairoStrokePaint #joinStyle )
	#( 14 #STROKE_DASHES #slot #AthensCairoStrokePaint #dashLenghts )
	#( 15 #STROKE_DASH_OFFSET #slot #AthensCairoStrokePaint #dashOffset )
	#( 16 #RENDERER_FONT #slot #CairoFreetypeFontRenderer #font )
	#( 17 #RENDERER_CANVAS #slot #CairoFreetypeFontRenderer #canvas )
	#( 18 #RENDERER_GLYPH_EXTENTS #slot #CairoFreetypeFontRenderer #glyphExtents )
	#( 19 #COLOR_RGB #slot #Color #rgb )
	#( 20 #COLOR_ALPHA #slot #Color #alpha )
	#( 21 #RECT_ORIGIN #slot #Rectangle #origin )
	#( 22 #RECT_CORNER #slot #Rectangle #corner )
	#( 23 #POINT_X #slot #Point #x )
	#( 24 #POINT_Y #slot #Point #y )
	#( 25 #COLOR_RED_SHIFT #classVar #Color #RedShift )
	#( 26 #COLOR_GREEN_SHIFT #classVar #Color #GreenShift )
	#( 27 #COLOR_COMPONENT_MASK #classVar #Color #ComponentMask )
	#( 28 #COLOR_ALPHA_MAX #constant nil 255 )
	#( 29 #SURFACE_CURRENT_CANVAS #slot #AthensCairoSurface #currentCanvas )
	#( 30 #CLASS_BYTE_STRING #class #ByteString nil )
	#( 31 #CLASS_BYTE_SYMBOL #class #ByteSymbol nil )
	#( 32 #CLASS_WIDE_STRING #class #WideString nil )
	#( 33 #CLASS_WIDE_SYMBOL #class #WideSymbol nil ) )
]

{ #category : 'constants' }
CairoPluginLayout class >> extObjHandlePosition [

	^ 8
]

{ #category : 'private' }
CairoPluginLayout class >> globalClassNamed: aSymbol [

	^ (Smalltalk globals at: aSymbol ifAbsent: [ nil ]) ifNotNil: [ :c |
		  c isBehavior
			  ifTrue: [ c ]
			  ifFalse: [ nil ] ]
]

{ #category : 'table' }
CairoPluginLayout class >> handleClassNames [
	"The classes whose handle the plugin reads at the slot EXTOBJ_HANDLE"

	^ #( #AthensCairoMatrix #AthensCairoPath #CairoScaledFont #CairoTextExtents #CairoFontExtents #AthensCairoPatternPaint )
]

{ #category : 'computing' }
CairoPluginLayout class >> integers [
	"The SmallInteger part of the table (positions 1 to 29), or nil"

	^ self current ifNotNil: [ :layout | layout first: 29 ]
]

{ #category : 'computing' }
CairoPluginLayout class >> problem [
	"Answer nil when the layout table can be computed, else a String saying what is missing"

	^ self compute value
]

{ #category : 'private' }
CairoPluginLayout class >> valueOf: row [
	"Answer the SmallInteger (or the class) of a row of #entries, or a String describing why it cannot be computed"

	| kind cls value |
	kind := row at: 3.
	kind = #constant ifTrue: [ ^ row at: 5 ].
	cls := self globalClassNamed: (row at: 4).
	cls ifNil: [ ^ 'class ' , (row at: 4) , ' is missing' ].
	kind = #class ifTrue: [ ^ cls ].
	kind = #slot ifTrue: [
		value := (cls allInstVarNames indexOf: (row at: 5)) - 1.
		value < 0 ifTrue: [
			^ (row at: 4) , ' has no instance variable ' , (row at: 5) ].
		^ value ].
	value := cls classPool at: (row at: 5) ifAbsent: [ nil ].
	value isInteger ifFalse: [
		^ (row at: 4) , ' has no Integer class variable ' , (row at: 5) ].
	^ value
]
