Extension { #name : 'String' }

{ #category : '*VM-Plugins-Primitives' }
String >> linesIncludeEmptySubstrings: aBoolean [
	"Answer my lines, an Array of Strings: those of #lines (CR, LF and CR LF each end a line; a last empty line does not count), without the empty ones unless aBoolean"

	(aBoolean and: [ self includesSubstring: String crlf ]) ifTrue: [
		^ self lines asArray ].
	^ self strtok: String crlf inclusive: aBoolean
]

{ #category : '*VM-Plugins-Primitives' }
String >> primStrtok: delimiters inclusive: aBoolean [
	"Answer the pieces of a byte string, or nil when the primitive failed"

	<primitive: 'primitive_strtok_r' module: 'UtilsPlugin'>
	^ nil
]

{ #category : '*VM-Plugins-Primitives' }
String >> strtok: delimiters inclusive: aBoolean [
	"Answer an Array of new Strings, my pieces between the characters of delimiters (a String, or a collection of Characters): with aBoolean false the maximal runs of non-delimiters, as strtok_r(3); with aBoolean true every field between delimiters, empty ones too, but an empty last one (so that the line ends as delimiters answer the lines)"

	UtilsPlugin usesPlugin ifTrue: [
		(self primStrtok: delimiters inclusive: aBoolean) ifNotNil: [ :pieces |
			^ pieces ] ].
	^ UtilsPluginSmalltalk split: self by: delimiters inclusive: aBoolean
]
