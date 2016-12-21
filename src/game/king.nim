import sdl2
import "../gamelib/textureregion"
import "../gamelib/textureatlas"
import "../gamelib/animation"

converter intToCint(x: int): cint = x.cint

type
  King* = ref object
    king_stand: TextureRegion
    king_walk: Animation
    walking: bool
    dir*: float
    world_pos*: float
    camera_pos*: float
  Input {.pure.} = enum none, left, right, down
  Inputs = array[Input, bool]

proc newKing*(atlas: TextureAtlas, pos: float): King=
  new result
  result.king_stand = atlas.getTextureRegion("king_stand")
  result.king_walk = atlas.getAnimation("king_walk")
  result.world_pos = pos
  result.camera_pos = 350
  result.dir = 1

{.this: self.}
proc tick*(self: King, tickLength: float, inputs: Inputs) =
  king_walk.tick(tickLength)
  if not inputs[Input.right] and not inputs[Input.left]:
    walking = false
  else:
    dir = (if inputs[Input.left]: -1 else: 1)
    if (dir == -1 and world_pos+40>0) or (dir == 1 and world_pos+64*3-40<(32*3)*14):#level.len):
      if not walking:
        king_walk.frame = 0
      walking = true
      world_pos += 185*tickLength*dir
    else:
      walking = false

  if dir == -1 and camera_pos<738:
    camera_pos += tickLength*2000
  elif dir == 1 and camera_pos>350:
    camera_pos -= tickLength*2000

proc render*(renderer:RendererPtr, king:King) =
  if king.walking:
    renderer.render(king.king_walk,king.camera_pos.int,572-(32*9)+13,scaleX = 3*king.dir, scaleY = 3)
  else:
    renderer.render(king.king_stand,king.camera_pos.int,572-(32*9)+13,scaleX = 3*king.dir, scaleY = 3)
