import sdl2
import basic2d
import textureregion

type
  AnimationType* {.pure.} = enum pingpong, cycle

  Animation* = ref object
    textureRegion: TextureRegion
    totalFrames:int
    frame: int
    timeSinceLastFrame: float
    longestFrameTime:float
    animationType: AnimationType
    speed: int
    frameWidth, frameHeight: cint

proc newAnimation*(textureRegion: TextureRegion, frames: int, fps: int, animationType: AnimationType): Animation =
  new result
  result.textureRegion = textureRegion
  result.totalFrames = frames-1
  result.longestFrameTime = 1/fps
  result.animationType = animationType
  result.speed = 1
  result.frameHeight = textureRegion.region.h
  result.frameWidth = (textureRegion.region.w/frames).cint

proc newAnimation*(texture: TexturePtr, region: Rect, frames: int, fps: int, animationType: AnimationType): Animation =
  newAnimation(texture.newTextureRegion(region),frames,fps,animationType)

proc tick*(animation: Animation, time: float) =
  animation.timeSinceLastFrame += time
  if animation.timeSinceLastFrame > animation.longestFrameTime:
    animation.frame += animation.speed
    if animation.frame >= animation.totalFrames or animation.frame <= 0:
      case animation.animationType:
        of AnimationType.cycle:
          animation.frame = 0
        of AnimationType.pingpong:
          animation.speed = if animation.speed == 1: -1 else: 1
    animation.timeSinceLastFrame -= animation.longestFrameTime

proc render*(renderer: RendererPtr, animation: Animation, pos: Point2d) =
  var
    src = rect(
      animation.textureRegion.region.x+animation.frameWidth*animation.frame.cint,
      animation.textureRegion.region.y,
      animation.frameWidth,
      animation.frameHeight)
    dst = rect(pos.x.cint,pos.y.cint,animation.frameWidth,animation.frameHeight)
  renderer.copyEx(animation.textureRegion.texture,
    src,
    dst,
    angle=0.0,
    center = nil,
    flip = SDL_FLIP_NONE)
