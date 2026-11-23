"
I record one change `CairoPluginInstaller` made to an Athens class, so that it can be undone exactly and redone without compiling.

Kind `#patch`: the method at `selector` was replaced by `method` (compiled from `source`, with the pragma `<cairoPluginPatch: group>`):

- `original` is the method that was there, as uFFI's source stub (`m propertyAt: #ffiNonCompiledMethod ifAbsent: [ m ]`: never a callout uFFI generated, which is bound to the libcairo path of the session that generated it), in the protocol `originalProtocol`;
- `ffiCopy` is the copy of the original compiled under `ffiSelector` (the fallback of the patch);
- `added` my records of kind `#added`.

Kind `#added`: `method` (from `source`, with the pragma `<cairoPluginAdded: group patch: selector>`) was added at `selector`, in `originalProtocol`.

After an uninstall the installer keeps me in its cache: a later install of the same original reuses my compiled methods.
"
Class {
	#name : 'CairoPluginPatchRecord',
	#superclass : 'Object',
	#instVars : [
		'targetClassName',
		'isMeta',
		'selector',
		'group',
		'kind',
		'original',
		'ffiSelector',
		'originalProtocol',
		'method',
		'source',
		'ffiCopy',
		'added'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'accessing' }
CairoPluginPatchRecord >> added [
	"My records of kind #added (an Array, empty for kind #added)"

	^ added ifNil: [ #(  ) ]
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> added: anArray [

	added := anArray
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> addedSources [
	"The sources of my added methods, in order"

	^ self added collect: [ :each | each source ]
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> ffiCopy [

	^ ffiCopy
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> ffiCopy: aCompiledMethod [

	ffiCopy := aCompiledMethod
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> ffiSelector [

	^ ffiSelector
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> ffiSelector: aSymbol [

	ffiSelector := aSymbol
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> group [

	^ group
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> group: aSymbol [

	group := aSymbol
]

{ #category : 'testing' }
CairoPluginPatchRecord >> isAdded [

	^ kind = #added
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> isMeta [

	^ isMeta
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> isMeta: aBoolean [

	isMeta := aBoolean
]

{ #category : 'testing' }
CairoPluginPatchRecord >> isPatch [

	^ kind = #patch
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> key [
	"The key of the patched method: { className. isMeta. selector }"

	^ { targetClassName. isMeta. selector }
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> kind [

	^ kind
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> kind: aSymbol [

	kind := aSymbol
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> method [

	^ method
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> method: aCompiledMethod [

	method := aCompiledMethod
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> methodName [
	"For reports: 'AthensCairoCanvas>>newPath'"

	^ targetClassName , (isMeta
		   ifTrue: [ ' class>>' ]
		   ifFalse: [ '>>' ]) , selector
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> original [

	^ original
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> original: aCompiledMethod [

	original := aCompiledMethod
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> originalProtocol [

	^ originalProtocol
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> originalProtocol: aSymbol [

	originalProtocol := aSymbol
]

{ #category : 'printing' }
CairoPluginPatchRecord >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: kind printString;
		space;
		nextPutAll: group printString;
		space;
		nextPutAll: self methodName;
		nextPut: $)
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> selector [

	^ selector
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> selector: aSymbol [

	selector := aSymbol
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> source [

	^ source
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> source: aString [

	source := aString
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> targetClass [
	"The class (or metaclass) I changed, or nil when it is not in the image any more"

	| cls |
	cls := Smalltalk globals at: targetClassName ifAbsent: [ ^ nil ].
	cls isBehavior ifFalse: [ ^ nil ].
	^ isMeta
		  ifTrue: [ cls class ]
		  ifFalse: [ cls ]
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> targetClassName [

	^ targetClassName
]

{ #category : 'accessing' }
CairoPluginPatchRecord >> targetClassName: aSymbol [

	targetClassName := aSymbol
]
