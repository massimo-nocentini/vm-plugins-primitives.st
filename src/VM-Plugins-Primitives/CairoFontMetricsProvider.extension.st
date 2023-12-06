Extension { #name : 'CairoFontMetricsProvider' }

{ #category : '*VM-Plugins-Primitives' }
CairoFontMetricsProvider >> convertString: utf8String len: strlen ofFont: aScaledFont toGlyphs: glyphs numGlyphs: numGlyphs x: x y: y [

	<primitive: 'primitive_cairo_scaled_font_text_to_glyphs' module:
	'CairoGraphicsPlugin'>
	self primitiveFail.
	^ self
		  ffiConvertString: utf8String
		  len: strlen
		  ofFont: aScaledFont
		  toGlyphs: glyphs
		  numGlyphs: numGlyphs
		  x: x
		  y: y
]

{ #category : '*VM-Plugins-Primitives' }
CairoFontMetricsProvider >> ffiConvertString: utf8String len: strlen ofFont: aScaledFont toGlyphs: glyphs numGlyphs: numGlyphs x: x y: y [
"
all of this for using
http://www.cairographics.org/manual/cairo-User-Fonts.html#cairo-user-scaled-font-text-to-glyphs-func-t

"
	^ self ffiCall: #(
		cairo_status_t cairo_scaled_font_text_to_glyphs (void * aScaledFont,
			double x,
			double y,
			void * utf8String,
			int strlen,
			void ** glyphs,
			int * numGlyphs,
			NULL,
			NULL,
			NULL))
]

{ #category : '*VM-Plugins-Primitives' }
CairoFontMetricsProvider >> glyphsOf: aString from: start to: end [

	| len ptr glyphs lenValue glyphsSize utf8Len error |
	len := end - start + 1.
	utf8Len := utfConverter convert: aString from: start to: end.

	ptr := ExternalAddress new.
	lenValue := ByteArray new: 4.

	error := self
		         convertString: utfConverter buffer
		         len: utf8Len
		         ofFont: cairoFont getHandle
		         toGlyphs: ptr
		         numGlyphs: lenValue
		         x: 0.0
		         y: 0.0.

	error = CAIRO_STATUS_SUCCESS ifFalse: [ ^ CairoGlyphsArray new: 0 ].

	glyphsSize := lenValue unsignedLongAt: 1.
	
	cairoFont
		getExtentsOfGlyphs: ptr
		ofLength: glyphsSize
		into: glyphExtents.

	glyphs := CairoGlyphsArray new: glyphsSize.
	LibC
		memCopy: ptr
		to: glyphs getHandle
		size: glyphsSize * glyphs typeSize.
	"Apply kerning on glyphs if font supports it"
	font face hasKerning ifTrue: [
		self
			applyKerningOn: glyphs
			of: aString
			from: start
			to: end ].
	self freeGlyphs: ptr.

	^ glyphs
]