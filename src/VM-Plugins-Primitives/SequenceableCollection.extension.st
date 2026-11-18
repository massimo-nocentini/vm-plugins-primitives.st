Extension { #name : 'SequenceableCollection' }

{ #category : '*VM-Plugins-Primitives' }
SequenceableCollection >> bezierPointAt: t [
	"Answer the point at the parameter t of the Bezier curve of my Points, its control points: the first one at 0, the last one at 1"

	^ (self bezierPointsAt: { t }) first
]

{ #category : '*VM-Plugins-Primitives' }
SequenceableCollection >> bezierPointsAt: parameters [
	"Answer an Array of the points at each of parameters (Numbers) of the Bezier curve of my Points, its control points, by the de Casteljau scheme of UtilsPlugin class>>#deCasteljau:into:at:"

	| points |
	points := Array new: parameters size.
	UtilsPlugin deCasteljau: self asArray into: points at: parameters asArray.
	^ points
]
