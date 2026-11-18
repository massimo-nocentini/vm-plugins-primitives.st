Extension { #name : 'Float' }

{ #category : '*VM-Plugins-Primitives' }
Float >> primitiveTimes: y plus: z [
	"Answer self * y + z rounded once, or nil when the primitive failed (y and z must be Floats)"

	<primitive: 'primitive_fma' module: 'UtilsPlugin'>
	^ nil
]

{ #category : '*VM-Plugins-Primitives' }
Float >> times: y plus: z [
	"Answer self * y asFloat + z asFloat rounded once (the fused multiply-add, C's fma): the Float nearest to the exact value"

	| fy fz |
	fy := y asFloat.
	fz := z asFloat.
	UtilsPlugin usesPlugin ifTrue: [
		(self primitiveTimes: fy plus: fz) ifNotNil: [ :result | ^ result ] ].
	^ UtilsPluginSmalltalk fma: self times: fy plus: fz
]
