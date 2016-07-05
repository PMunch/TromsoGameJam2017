import textureregion
import tables
import sdl2
import sdl2.image
import strutils
import files
import streams

type
  TextureAtlas* = ref object
    regions: Table[string,TextureRegion]

  State = enum space, fname, size, format, filter, repeat, texName, texRot, texPos, texSize, texOrig, texOffset, texIndex

proc getTextureCount*(atlas: TextureAtlas): int =
  return atlas.regions.len

proc getTextureRegion*(atlas: TextureAtlas, name: string): TextureRegion =
  return atlas.regions[name]

proc loadAtlas*(renderer: RendererPtr, atlasFileName: string): TextureAtlas =
  new result
  result.regions = initTable[string,TextureRegion]()
  var
    state = State.space
    texture: TexturePtr
    name: string
    region:Rect
    rwStream = newStreamWithRWops(rwFromFile(atlasFileName, "rb"))
  defer: rwStream.close()
  for line in rwStream.lines:
    if line=="":
      state = space
    else:
      if ord(state)<6:
        state = State((ord(state) + 1))
      else:
        state = State(6 + ((ord(state) - 5) mod 7))
    case state:
      of space:
        continue
      of fname:
        texture = renderer.loadTexture(line)
      of size:
        continue
      of format:
        continue
      of filter:
        continue
      of repeat:
        continue
      of texName:
        name = line
      of texRot:
        continue
      of texPos:
        var words = line.split
        words[1].removeSuffix(',')
        let
          x = words[1].parseInt.cint
          y = words[2].parseInt.cint
        region = rect(x,y)
      of texSize:
        var words = line.split
        words[1].removeSuffix(',')
        let
          w = words[1].parseInt.cint
          h = words[2].parseInt.cint
        region.w = w
        region.h = h

        # All data is gathered, add the texture
        result.regions.add(name, newTextureRegion(texture,region))
      of texOrig:
        continue
      of texOffset:
        continue
      of texIndex:
        continue
