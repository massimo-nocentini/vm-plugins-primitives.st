"
I provide values through slots instead of interpreting a `ByteArray`.
"
Class {
	#name : 'CairoFontExtentsBySlots',
	#superclass : 'CairoFontExtents',
	#instVars : [
		'ascent',
		'descent',
		'width',
		'height',
		'max_x_advance',
		'max_y_advance'
	],
	#category : 'VM-Plugins-Primitives',
	#package : 'VM-Plugins-Primitives'
}

{ #category : 'accessing - structure variables' }
CairoFontExtentsBySlots >> ascent [

	^ ascent
]

{ #category : 'accessing - structure variables' }
CairoFontExtentsBySlots >> ascent: anObject [

	ascent := anObject
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> descent [

	^ descent
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> descent: anObject [

	descent := anObject
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> height [

	^ height
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> height: anObject [

	height := anObject
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> max_x_advance [

	^ max_x_advance
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> max_x_advance: anObject [

	max_x_advance := anObject
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> max_y_advance [

	^ max_y_advance
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> max_y_advance: anObject [

	max_y_advance := anObject
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> width [

	^ width
]

{ #category : 'accessing' }
CairoFontExtentsBySlots >> width: anObject [

	width := anObject
]
