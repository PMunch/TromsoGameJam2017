import sdl2
import basic2d

type
  TextureRegion* = ref object
    texture*: TexturePtr
    region*: Rect

proc newTextureRegion*(texture: TexturePtr, region: Rect):TextureRegion =
  new result
  result.texture = texture
  result.region = region

proc newTextureRegion*(texture: TexturePtr, x,y,w,h: cint): TextureRegion =
  return newTextureRegion(texture,rect(x,y,w,h))

proc render*(renderer: RendererPtr, textureRegion: TextureRegion, x,y: cint) =
  var
    dst = rect(x,y,textureRegion.region.w,textureRegion.region.h)
  renderer.copyEx(textureRegion.texture,
    textureRegion.region,
    dst,
    angle=0.0,
    center = nil,
    flip = SDL_FLIP_NONE)

proc render*(renderer: RendererPtr, textureRegion: TextureRegion, pos: Point2d) =
  renderer.render(textureRegion, pos.x.cint, pos.y.cint)
