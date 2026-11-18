"
I hold one method per drawing primitive of the CairoPlugin (pharo-vm: plugins/CairoPlugin/tests/primitives.txt), for the tests of the primitives' contract (`CairoPluginPrimitiveTest`): each runs its named primitive with no fallback, and answers what the primitive answers, or a `CairoPluginPrimitiveFailure` holding the failure code.

My methods are never sent to my instances: `CairoPluginTestSupport class>>#primitive:receiver:arguments:` runs them with any receiver (`CompiledMethod>>#valueWithReceiver:arguments:`), an Athens object or a corrupted copy of one, as the patched Athens methods do. A selector is the primitive's name, with `with:` keywords for the arguments after the first: `primitiveBuilderMoveTo:with:`. The methods whose selector ends with `WrongArity` call a primitive with one argument too many or too few.
"
Class {
	#name : 'CairoPluginTestPrimitives',
	#superclass : 'Object',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveAppendPath: a1 [

	<primitive: 'primitiveAppendPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderArc: a1 with: a2 with: a3 with: a4 with: a5 [

	<primitive: 'primitiveBuilderArc' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderArcNegative: a1 with: a2 with: a3 with: a4 with: a5 [

	<primitive: 'primitiveBuilderArcNegative' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderClosePath [

	<primitive: 'primitiveBuilderClosePath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderCopyPath: a1 [

	<primitive: 'primitiveBuilderCopyPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderCurveTo: a1 with: a2 with: a3 with: a4 with: a5 with: a6 [

	<primitive: 'primitiveBuilderCurveTo' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderLineTo: a1 with: a2 [

	<primitive: 'primitiveBuilderLineTo' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderMoveTo: a1 with: a2 [

	<primitive: 'primitiveBuilderMoveTo' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives - wrong arity' }
CairoPluginTestPrimitives >> primitiveBuilderMoveToWrongArity: a1 with: a2 with: a3 [

	<primitive: 'primitiveBuilderMoveTo' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveBuilderNewPath [

	<primitive: 'primitiveBuilderNewPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveClip [

	<primitive: 'primitiveClip' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveFill [

	<primitive: 'primitiveFill' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveFillPathColor: a1 with: a2 [

	<primitive: 'primitiveFillPathColor' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveFillPreserve [

	<primitive: 'primitiveFillPreserve' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveFillRectangleColor: a1 with: a2 [

	<primitive: 'primitiveFillRectangleColor' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives - wrong arity' }
CairoPluginTestPrimitives >> primitiveFillRectangleColorWrongArity: a1 [

	<primitive: 'primitiveFillRectangleColor' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveGetCurrentPoint [

	<primitive: 'primitiveGetCurrentPoint' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveGetOperator [

	<primitive: 'primitiveGetOperator' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveGetScaledFont: a1 [

	<primitive: 'primitiveGetScaledFont' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveGlyphFree: a1 [

	<primitive: 'primitiveGlyphFree' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInit: a1 with: a2 with: a3 with: a4 with: a5 with: a6 [

	<primitive: 'primitiveMatrixInit' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInitIdentity [

	<primitive: 'primitiveMatrixInitIdentity' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInitRotate: a1 [

	<primitive: 'primitiveMatrixInitRotate' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInitScale: a1 with: a2 [

	<primitive: 'primitiveMatrixInitScale' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInitTranslate: a1 with: a2 [

	<primitive: 'primitiveMatrixInitTranslate' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixInvert [

	<primitive: 'primitiveMatrixInvert' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixMultiply: a1 [

	<primitive: 'primitiveMatrixMultiply' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixRotate: a1 [

	<primitive: 'primitiveMatrixRotate' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixScale: a1 with: a2 [

	<primitive: 'primitiveMatrixScale' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixTransformPoint: a1 with: a2 [

	<primitive: 'primitiveMatrixTransformPoint' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveMatrixTranslate: a1 with: a2 [

	<primitive: 'primitiveMatrixTranslate' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveNewPath [

	<primitive: 'primitiveNewPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives - wrong arity' }
CairoPluginTestPrimitives >> primitiveNewPathWrongArity: a1 [

	<primitive: 'primitiveNewPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitivePaint [

	<primitive: 'primitivePaint' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitivePathDestroy: a1 [

	<primitive: 'primitivePathDestroy' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveRectangle: a1 with: a2 with: a3 with: a4 [

	<primitive: 'primitiveRectangle' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveResetClip [

	<primitive: 'primitiveResetClip' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveResetDash: a1 [

	<primitive: 'primitiveResetDash' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveRestore [

	<primitive: 'primitiveRestore' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSave [

	<primitive: 'primitiveSave' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveScaledFontExtents: a1 [

	<primitive: 'primitiveScaledFontExtents' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveScaledFontGlyphExtents: a1 with: a2 with: a3 [

	<primitive: 'primitiveScaledFontGlyphExtents' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveScaledFontLockFace [

	<primitive: 'primitiveScaledFontLockFace' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveScaledFontTextExtents: a1 with: a2 [

	<primitive: 'primitiveScaledFontTextExtents' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveScaledFontUnlockFace [

	<primitive: 'primitiveScaledFontUnlockFace' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetAntialias: a1 [

	<primitive: 'primitiveSetAntialias' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetDash: a1 with: a2 with: a3 [

	<primitive: 'primitiveSetDash' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetFillRule: a1 [

	<primitive: 'primitiveSetFillRule' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetFontSize: a1 [

	<primitive: 'primitiveSetFontSize' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetLineCap: a1 [

	<primitive: 'primitiveSetLineCap' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetLineJoin: a1 [

	<primitive: 'primitiveSetLineJoin' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetLineWidth: a1 [

	<primitive: 'primitiveSetLineWidth' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives - wrong arity' }
CairoPluginTestPrimitives >> primitiveSetLineWidthWrongArity [

	<primitive: 'primitiveSetLineWidth' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetMatrix: a1 [

	<primitive: 'primitiveSetMatrix' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetOperator: a1 [

	<primitive: 'primitiveSetOperator' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetPathMatrix [

	<primitive: 'primitiveSetPathMatrix' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetScaledFont: a1 [

	<primitive: 'primitiveSetScaledFont' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetSource: a1 [

	<primitive: 'primitiveSetSource' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSetSourceRGBA: a1 with: a2 with: a3 with: a4 [

	<primitive: 'primitiveSetSourceRGBA' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveShowGlyphs: a1 with: a2 [

	<primitive: 'primitiveShowGlyphs' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveShowString: a1 with: a2 with: a3 with: a4 with: a5 [

	<primitive: 'primitiveShowString' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives - wrong arity' }
CairoPluginTestPrimitives >> primitiveShowStringWrongArity: a1 with: a2 with: a3 with: a4 [

	<primitive: 'primitiveShowString' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveStroke [

	<primitive: 'primitiveStroke' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveStrokePath: a1 with: a2 with: a3 [

	<primitive: 'primitiveStrokePath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveStrokeRectangle: a1 with: a2 with: a3 [

	<primitive: 'primitiveStrokeRectangle' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveSurfaceFlush [

	<primitive: 'primitiveSurfaceFlush' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveTextPath: a1 [

	<primitive: 'primitiveTextPath' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]

{ #category : 'primitives' }
CairoPluginTestPrimitives >> primitiveTextToGlyphs: a1 with: a2 with: a3 with: a4 with: a5 with: a6 with: a7 [

	<primitive: 'primitiveTextToGlyphs' module: 'CairoPlugin' error: ec>
	^ CairoPluginPrimitiveFailure code: ec
]
