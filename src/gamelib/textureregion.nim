import sdl2
#import basic2d

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
