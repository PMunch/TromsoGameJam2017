import sdl2
#import math

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
  newTextureRegion(texture,region,size,point(0,0),false)

template newTextureRegion*(texture: TexturePtr, x,y,w,h: cint): TextureRegion =
  newTextureRegion(texture,rect(x,y,w,h),rect(x,y,w,h))

proc render*(renderer: RendererPtr, textureRegion: TextureRegion, x,y: cint, rotation:float = 0, scaleX, scaleY:float = 1, alpha: uint8 = 255) =
  var
    scaleXmod = scaleX
    scaleYmod = scaleY
    offsetX = textureRegion.offset.x
    offsetY = textureRegion.offset.y
  if scaleX<0:
    scaleXmod *= -1
    if not textureRegion.rotated:
      offsetX = textureRegion.size.x-textureRegion.region.w-textureRegion.offset.x
    else:
      offsetY = textureRegion.size.y-textureRegion.region.h-textureRegion.offset.y
  if scaleY<0:
    scaleYmod *= -1
    if textureRegion.rotated:
      offsetX = textureRegion.size.x-textureRegion.region.w-textureRegion.offset.x
    else:
      offsetY = textureRegion.size.y-textureRegion.region.h-textureRegion.offset.y
  var
    sX = scaleXmod
    sY = scaleYmod
  if textureRegion.rotated:
    let s = scaleXmod
    sX = scaleYmod
    sY = s
  var
    src = rect(textureRegion.region.x,textureRegion.region.y,textureRegion.region.w,textureRegion.region.h)
    c = point(
      ((textureRegion.size.x/2)-offsetX.float)*sX,
      ((textureRegion.size.y/2)-offsetY.float)*sY
    )
    #r = ((textureRegion.region.w-textureRegion.region.h)/2)
    r = (if textureRegion.rotated: c.x-c.y else: 0)
    ox = (if textureRegion.rotated: offsetY else: offsetX)
    oy = (if textureRegion.rotated: offsetX else: offsetY)
    dst = rect(
      ((x-r).float+ox.float*scaleXmod).cint,
      ((y+r).float+oy.float*scaleYmod).cint,
      (textureRegion.region.w.float*sX).cint,
      (textureRegion.region.h.float*sY).cint)

  #renderer.drawRect(dst)
  textureRegion.texture.setTextureAlphaMod(alpha)
  renderer.copyEx(textureRegion.texture,
    src,
    dst,
    angle = (if textureRegion.rotated: 90 else: 0) + rotation,
    center = c.addr,
    flip = (if scaleX<0: (if textureRegion.rotated: SDL_FLIP_VERTICAL else: SDL_FLIP_HORIZONTAL) else: SDL_FLIP_NONE) or (if scaleY<0: (if textureRegion.rotated: SDL_FLIP_HORIZONTAL else: SDL_FLIP_VERTICAL) else: SDL_FLIP_NONE))
  textureRegion.texture.setTextureAlphaMod(255)
  #[var
    dst = if textureRegion.rotated:
        rect(
        x+((textureRegion.offset.x.float+ -textureRegion.region.w/2+textureRegion.region.h/2).float*scaleX).cint,
        y+((textureRegion.offset.y.float+ -textureRegion.region.w/2+textureRegion.region.h/2).float*scaleY).cint,
        (textureRegion.region.w.float * scaleY).cint,
        (textureRegion.region.h.float * scaleX).cint)
      else:
        rect(
        x+(textureRegion.offset.x.float * scaleX).cint,
        y+(textureRegion.offset.y.float * scaleY).cint,
        (textureRegion.region.w.float * scaleX).cint,
        (textureRegion.region.h.float * scaleY).cint)
    ctr = if textureRegion.rotated:
        point(((textureRegion.size.y/2-textureRegion.offset.x.float)*scaleX).cint,((textureRegion.size.x/2-textureRegion.offset.y.float)*scaleY).cint)
      else: point(((textureRegion.size.x/2-textureRegion.offset.x.float)*scaleX).cint,((textureRegion.size.y/2-textureRegion.offset.y.float)*scaleY).cint)
  renderer.copyEx(textureRegion.texture,
    textureRegion.region,
    dst,
    angle = rotation + (if textureRegion.rotated: 90.0 else: 0.0),
    center = ctr.addr,
    flip = SDL_FLIP_NONE)]#

template render*(renderer: RendererPtr, textureRegion: TextureRegion, pos: Point, rotation:float = 0, scaleX, scaleY: float = 1, alpha:uint8 = 255) =
  renderer.render(textureRegion, pos.x.cint, pos.y.cint, rotation, scaleX, scaleY,alpha)
