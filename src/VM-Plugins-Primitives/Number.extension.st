Extension { #name : 'Number' }

{ #category : '*VM-Plugins-Primitives' }
Number >> times: y plus: z [
	"Answer self * y + z. Float>>#times:plus: rounds it once"

	^ self * y + z
]
