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
    maxWidth: uint32

proc render* (renderer: RendererPtr, text:Text, x,y:cint, rotation: float = 0, scaleX, scaleY: float = 1, alpha: uint8 = 255) =
  #var source = rect(0, 0, text.region.w, text.region.h)
  var dest = rect(x, y, (text.region.w.float*scaleX).cint, (text.region.h.float*scaleY).cint)

  text.texture.setTextureAlphaMod(alpha)
  renderer.copyEx(text.texture, text.region, dest, angle = rotation, center = nil,
                  flip = SDL_FLIP_NONE)

proc createTexture(text:Text) =
  #[var
    str = @[""]
    line = 0
  for c in text.lastString:
    if c == "\n":
      line+=1
    str[line] = str[line] & c]#
  let surface =
    if text.blendMode == TextBlendMode.blended:
      text.font.renderUtf8BlendedWrapped(text.lastString, text.color,text.maxWidth)
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

proc setMaxWidth*(text:Text, maxWidth:uint32) =
  if text.maxWidth != maxWidth:
    text.maxWidth = maxWidth
    text.createTexture

proc setBackground*(text:Text, background: Color) =
  if text.background != background:
    text.background = background
    text.createTexture

proc newText* (renderer: RendererPtr, font: FontPtr, text: string, color:Color = color(255,255,255,0), blendMode: TextBlendMode = TextBlendMode.solid, maxWidth: uint32 = uint32.high): Text =
  new result
  result.lastString = text
  result.font = font
  result.renderer = renderer
  result.color = color
  result.maxWidth = maxWidth
  result.blendMode = blendMode
  if result.blendMode != TextBlendMode.shaded:
    result.createTexture
