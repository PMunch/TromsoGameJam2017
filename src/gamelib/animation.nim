import sdl2
import textureregion

type
  AnimationType* {.pure.} = enum pingpong, cycle

  Animation* = ref object
    textureRegions*: seq[TextureRegion]
    totalFrames*:int
    frame: int
    timeSinceLastFrame: float
    longestFrameTime:float
    animationType: AnimationType
    speed: int
    frameWidth, frameHeight: cint

proc newAnimation*(textureRegions: seq[TextureRegion]): Animation =
  new result
  result.textureRegions = textureRegions
  result.totalFrames = textureRegions.len - 1
  result.longestFrameTime = 1/12
  result.animationType = AnimationType.cycle
  result.speed = 1
  result.frameHeight = textureRegions[0].size.h
  result.frameWidth = textureRegions[0].size.w

proc newAnimation*(textureRegion: TextureRegion, frames: int, fps: int, animationType: AnimationType): Animation =
  new result
  result.textureRegions = @[textureRegion]
  result.totalFrames = frames-1
  result.longestFrameTime = 1/fps
  result.animationType = animationType
  result.speed = 1
  if not textureRegion.rotated:
    result.frameHeight = textureRegion.region.h
    result.frameWidth = (textureRegion.region.w/frames).cint
  else:
    result.frameHeight = (textureRegion.region.h/frames).cint
    result.frameWidth = textureRegion.region.w

template newAnimation*(texture: TexturePtr, region: Rect, frames: int, fps: int, animationType: AnimationType): Animation =
  newAnimation(texture.newTextureRegion(region),frames,fps,animationType)

proc setFps*(animation: Animation, fps:int) =
  animation.longestFrameTime = 1/fps

proc setAnimationType*(animation: Animation, animationType: AnimationType) =
  animation.animationType = animationType

proc tick*(animation: Animation, time: float) =
  animation.timeSinceLastFrame += time
  while animation.timeSinceLastFrame > animation.longestFrameTime:
    animation.frame += animation.speed
    if animation.frame >= animation.totalFrames or animation.frame <= 0:
      case animation.animationType:
        of AnimationType.cycle:
          animation.frame = 0
        of AnimationType.pingpong:
          animation.speed = if animation.speed == 1: -1 else: 1
    animation.timeSinceLastFrame -= animation.longestFrameTime

template render*(renderer: RendererPtr, animation: Animation, pos: Point) =
  render(renderer,animation,pos.x,pos.y)

proc render*(renderer: RendererPtr, animation: Animation, x,y: cint) =
  var
    activeFrame: TextureRegion
    src, dst: Rect
  if animation.textureRegions.len == 1:
    activeFrame = animation.textureRegions[0]
    if not activeFrame.rotated:
      src = rect(
        activeFrame.region.x+animation.frameWidth*animation.frame.cint,
        activeFrame.region.y,
        animation.frameWidth,
        animation.frameHeight )
    else:
      src = rect(
        activeFrame.region.x,
        activeFrame.region.y+animation.frameWidth*animation.frame.cint,
        animation.frameWidth,
        animation.frameHeight )
    dst = rect(
      x+activeFrame.offset.x,
      y+activeFrame.offset.y,
      animation.frameWidth,
      animation.frameHeight)
  else:
    activeFrame = animation.textureRegions[animation.frame]
    src = rect(
      activeFrame.region.x,
      activeFrame.region.y,
      activeFrame.region.w,
      activeFrame.region.h )
    dst = rect(
      x+activeFrame.offset.x,
      y+activeFrame.offset.y,
      activeFrame.region.w,
      activeFrame.region.h )

  renderer.copyEx(activeFrame.texture,
    src,
    dst,
    angle=if activeFrame.rotated: 90.0 else: 0.0,
    center = nil,
    flip = SDL_FLIP_NONE)
