import sdl2
import sdl2.ttf

type
  TextBlendMode* {.pure.} = enum solid, shaded, blended
  Text* = ref object
    lastString: cstring
    texture: TexturePtr
    color: Color
    background: Color
    region: Rect
    font: FontPtr
    renderer: RendererPtr
    blendMode: TextBlendMode

proc render* (renderer: RendererPtr, text:Text, x,y:cint) =
  #var source = rect(0, 0, text.region.w, text.region.h)
  var dest = rect(x, y, text.region.w, text.region.h)

  renderer.copyEx(text.texture, text.region, dest, angle = 0.0, center = nil,
                  flip = SDL_FLIP_NONE)

proc createTexture(text:Text) =
  let surface =
    if text.blendMode == TextBlendMode.blended:
      text.font.renderUtf8Blended(text.lastString, text.color)
    elif text.blendMode == TextBlendMode.solid:
      text.font.renderUtf8Solid(text.lastString, text.color)
    elif text.blendMode == TextBlendMode.shaded:
      text.font.renderUtf8Shaded(text.lastString, text.color, text.background)
    else:
      nil
  text.region = rect(0,0,surface.w,surface.h)

  discard surface.setSurfaceAlphaMod(text.color.a)
  if text.texture != nil:
    text.texture.destroy()
  text.texture = text.renderer.createTextureFromSurface(surface)
  surface.freeSurface()

proc setText*(text:Text, str:string) =
  if text.lastString != str:
    text.lastString = str
    text.createTexture

proc setColor*(text:Text, color:Color) =
  if text.color != color:
    text.color = color
    text.createTexture

proc setFont*(text:Text, font: FontPtr) =
  if text.font != font:
    text.font = font
    text.createTexture

proc setBackground*(text:Text, background: Color) =
  if text.background != background:
    text.background = background
    text.createTexture

proc newText* (renderer: RendererPtr, font: FontPtr, text: string, color:Color, blendMode: TextBlendMode): Text =
  new result
  result.lastString = text
  result.font = font
  result.renderer = renderer
  result.color = color
  result.blendMode = blendMode
  if result.blendMode != TextBlendMode.shaded:
    result.createTexture
