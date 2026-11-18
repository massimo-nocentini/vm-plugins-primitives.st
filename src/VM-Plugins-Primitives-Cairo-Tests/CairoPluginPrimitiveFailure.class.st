"
I am what a method of `CairoPluginTestPrimitives` answers when its primitive fails: the failure code (a Symbol such as #'bad receiver', or nil when the primitive is missing) is my `code`.
"
Class {
	#name : 'CairoPluginPrimitiveFailure',
	#superclass : 'Object',
	#instVars : [
		'code'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'instance creation' }
CairoPluginPrimitiveFailure class >> code: aSymbol [

	^ self new setCode: aSymbol
]

{ #category : 'accessing' }
CairoPluginPrimitiveFailure >> code [

	^ code
]

{ #category : 'testing' }
CairoPluginPrimitiveFailure >> isPrimitiveFailure [

	^ true
]

{ #category : 'printing' }
CairoPluginPrimitiveFailure >> printOn: aStream [

	aStream
		nextPutAll: 'primitive failed: ';
		print: code
]

{ #category : 'initialization' }
CairoPluginPrimitiveFailure >> setCode: aSymbol [

	code := aSymbol
]
