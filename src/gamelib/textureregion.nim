import sdl2

type
  TextureRegion* = ref object
    texture*: TexturePtr
    region*: Rect
    size*: Rect
    offset*: Point
    rotated*: bool

proc newTextureRegion*(texture: TexturePtr, region: Rect, size: Rect, offset: Point, rotated: bool):TextureRegion =
  new result
  result.texture = texture
  result.region = region
  result.size = size
  result.offset = offset
  result.rotated = rotated

template newTextureRegion*(texture: TexturePtr, region: Rect, size: Rect):TextureRegion =
  return newTextureRegion(texture,region,size,point(0,0),false)

template newTextureRegion*(texture: TexturePtr, x,y,w,h: cint): TextureRegion =
  return newTextureRegion(texture,rect(x,y,w,h),rect(x,y,w,h))

proc render*(renderer: RendererPtr, textureRegion: TextureRegion, x,y: cint) =
  var
    dst = rect(
      x+textureRegion.offset.x,
      y+textureRegion.offset.y,
      textureRegion.region.w,
      textureRegion.region.h)
  renderer.copyEx(textureRegion.texture,
    textureRegion.region,
    dst,
    angle = if textureRegion.rotated: 90.0 else: 0.0,
    center = nil,
    flip = SDL_FLIP_NONE)

template render*(renderer: RendererPtr, textureRegion: TextureRegion, pos: Point) =
  renderer.render(textureRegion, pos.x.cint, pos.y.cint)
