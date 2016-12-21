import sdl2
import math
import random
import times
#import king
import gameobject
import "../gamelib/textureregion"
import "../gamelib/textureatlas"
import "../gamelib/animation"

converter intToCint(x: int): cint = x.cint

type
  Citizen* = ref object
    citizen: Animation
    attention: Animation
    extra_height: int
    extra_height_topi: float
    extra_height_dir: int
    playerClose*: bool
    pos*: float
    target*: float
    dir:int
    totalOffset:float
    startPos:float
    game:GameObject

proc newCitizen*(game: GameObject, atlas: TextureAtlas, pos: float): Citizen =
  new result
  var citizen_tex = atlas.getTextureRegion("citizen")
  result.citizen = newAnimation(citizen_tex,8,10,AnimationType.pingpong)
  result.attention = atlas.getAnimation("arrow")
  result.citizen.textureRegions.delete(7)
  result.citizen.textureRegions.delete(6)
  result.attention.setFPS(0)
  result.attention.frame=1
  result.extra_height = 0
  result.extra_height_topi = 3.14
  result.extra_height_dir = 1
  result.pos = pos
  result.startPos = pos
  result.target = -1
  result.game = game
  randomize(epochTime().int)
  while(result.target<0 or result.target>game.levelWidth.float):
    result.target = result.startPos - (100 + random(250.0))
    echo result.target
    #result.totalOffset = 50-random(250.0)
    #result.target = pos-result.totalOffset

{.this: self.}
proc tick*(self:Citizen, tickLength: float) =
  if playerClose:
    if extra_height_dir == 1 and extra_height_topi>3.14:
      extra_height_dir = -1
    elif extra_height_dir == -1 and extra_height_topi<0:
      extra_height_dir = 1

    extra_height_topi += tickLength*6*extra_height_dir.float
  elif extra_height_topi<3.14:
      extra_height_topi += (tickLength*6).float

  extra_height = ((cos(extra_height_topi)+1)*6).int
  if pos!=target:
    citizen.tick(tickLength)
    if pos>target:
      pos -= min(pos-target, tickLength*40)
      dir = -1
    else:
      pos += min(target-pos, tickLength*40)
      dir = 1
  else:
    target = -1
    while target<0 or target>game.levelWidth.float:
      target = startPos - (100 + random(250.0))*dir.float
      #target = 32*1.5+pos-target-(abs(totalOffset)+100+random(200.0))*dir.float
    #totalOffset += target - pos
    echo target-800
    citizen.frame = 0


proc render*(renderer:RendererPtr, citizen:Citizen, renderPos: cint) =
  renderer.render(citizen.attention,citizen.pos.int+35-renderPos,572-(32*6)+20-citizen.extra_height,scaleX = 3*citizen.dir.float, scaleY = 3)
  renderer.render(citizen.citizen,citizen.pos.int-renderPos,572-(32*6)+13,scaleX = 3*citizen.dir.float, scaleY = 3)
