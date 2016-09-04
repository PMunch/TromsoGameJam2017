import sdl2
import sdl2.image
import sdl2.haptic
import basic2d
import times
import os
import json
import streams
import tables
import gamelib.animation
import gamelib.textureregion
import gamelib.textureatlas
import gamelib.logger
import gamelib.files
import gamelib.collisions

type
  SDLException = object of Exception

  Input {.pure.} = enum none, morph, jump, restart, quit

  Character {.pure.} = enum man, bear, pig

  Player = ref object
    animation: Animation
    pos: Point2D
    vel: Vector2D
    character:Character

  Game = ref object
    inputs: array[Input, bool]
    renderer: RendererPtr
    window: WindowPtr
    player: Player
    atlas: TextureAtlas
    level: JsonNode
    progress: float
    obstacleTiles: seq[TextureRegion]
    backgrounds: seq[TextureRegion]
    entityTextures: Table[string,seq[TextureRegion]]

const isMobile = defined(ios) or defined(android)

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc newPlayer(texture: TextureRegion): Player =
  new result
  #result.texture = texture
  result.animation = newAnimation(texture,4,10,AnimationType.pingpong)
  result.pos = point2d(1022,510)
  result.vel = vector2d(0,350)
  result.character = Character.man

proc tick(player: Player, time: float) =
  player.animation.tick(time)
  player.pos.y += player.vel.y*time

proc newGame(renderer: RendererPtr, window: WindowPtr, atlas: TextureAtlas, level: JsonNode): Game =
  new result
  result.renderer = renderer
  result.window = window
  result.atlas = atlas
  var
    tex = atlas.getTextureRegion("Main/mannbarschwein")
    texCp = new TextureRegion
  texCp.texture = tex.texture
  texCp.region = tex.region
  #tex.region.w = (tex.region.w/3).cint
  result.player = newPlayer(texCp)
  result.level = level
  result.obstacleTiles = @[
    atlas.getTextureRegion("Main/tile1"),
    atlas.getTextureRegion("Main/obstacle1"),
    atlas.getTextureRegion("Main/obstacle2")]
  result.backgrounds = @[
    atlas.getTextureRegion("Intro/bakgrunn1"),
    atlas.getTextureRegion("Intro/bakgrunn2"),
    atlas.getTextureRegion("Background/bakgrunn3")]
  result.entityTextures = initTable[string,seq[TextureRegion]]()
  result.entityTextures.add("EntityPickup",@[
    atlas.getTextureRegion("Main/pickup1"),
    atlas.getTextureRegion("Main/pickup2"),
    atlas.getTextureRegion("Main/pickup3")])
  result.entityTextures.add("EntityGate",@[
    atlas.getTextureRegion("Main/gate"),
    atlas.getTextureRegion("Main/skog"),
    atlas.getTextureRegion("Main/sump4")])

proc toInput(key: Scancode): Input =
  result=
    case key
    of SDL_SCANCODE_UP: Input.jump
    of SDL_SCANCODE_DOWN: Input.morph
    of SDL_SCANCODE_R: Input.restart
    of SDL_SCANCODE_Q: Input.quit
    else: Input.none

proc toInput(touch: TouchFingerEventPtr, window: WindowPtr): Input =
  log "Finger down! x: " & $touch.x & ", y: " & $touch.y
  var
    w,h: cint
  window.getSize(w,h)
  when isMobile:
    let
      x = touch.x * w.cfloat
      #y = touch.y * h.cfloat
  else:
    let
      x = touch.x
      #y = touch.y

  if x>w/2:
    return Input.jump
  else:
    return Input.morph

proc handleInput(game: Game) =
  var event = defaultEvent
  while pollEvent(event):
    case event.kind
    of QuitEvent:
      game.inputs[Input.quit] = true
    of KeyDown:
      game.inputs[event.key.keysym.scancode.toInput] = true
    of KeyUp:
      game.inputs[event.key.keysym.scancode.toInput] = false
    of FingerDown:
      game.inputs[event.EvTouchFinger.toInput(game.window)] = true
    of FingerUp:
      game.inputs[event.EvTouchFinger.toInput(game.window)] = false
    else:
      discard

proc render(renderer: RendererPtr, player: Player) =
  renderer.render(player.animation,player.pos)

proc render(game: var Game, time: float) =
  # Draw over all drawings of the last frame with the default color
  game.renderer.clear()
  # Show the result on screen
  game.renderer.render(game.backgrounds[game.player.character.int],0,0)

  var
    firstLine:float = (game.level["layer"][1]["width"].num - 30).float - game.progress
    y: int = 0
    grounded = false
  for line in game.level["layer"][1]["data"]:
    for tNum in (firstLine.int)..(firstLine.int + 29):
      var tile:int = (line[tNum].num - 1).int
      if tile != -1:
        if tNum > firstLine.int + 20:
          let collision = collides(rect(game.player.pos.x.cint,game.player.pos.y.cint,90,90),rect(((tNum.float - firstLine)*45).cint, (y*45).cint,45,45))
          if collision != nil:
            if collision.direction == Direction.southwest or
               collision.direction == Direction.south or
               collision.direction == Direction.southeast:
              if tile == 2:
                game = newGame(game.renderer, game.window,game.atlas,game.level)
              grounded = true
              if game.player.vel.y > 0:
                game.player.pos.y -= collision.rect.h.float
                game.player.vel.y = 0
            elif collision.direction == Direction.northwest or
                 collision.direction == Direction.north or
                 collision.direction == Direction.northeast:
              if game.player.vel.y < 0:
                game.player.vel.y = 0
                game.player.pos.y += collision.rect.h.float+1
              else:
                game = newGame(game.renderer, game.window,game.atlas,game.level)
            else:
              game = newGame(game.renderer, game.window,game.atlas,game.level)
          #game.renderer.setDrawColor(r = 174, g = 0, b = 0)
          #var r = rect(((tNum.float - firstLine)*45).cint, (y*45).cint,45,45)
          #discard game.renderer.drawRect(r)
          #game.renderer.setDrawColor(r = 110, g = 132, b = 174)
        game.renderer.render(game.obstacleTiles[tile], ((tNum.float - firstLine)*45).cint, (y*45).cint)
    y+=1

  for entity in game.level["entities"]:
    if entity["type"].str == "EntityGate":
      let
        entityX = 1200+(entity["x"].num-(1200*45-game.progress*45).int).cint
        entityY = entity["y"].num.cint
        tex = game.entityTextures["EntityGate"][int(entity["settings"]["particleType"].num-1)]
      if entityX + 480 > 0 and entityX < 1280:
          var halfWidth = (tex.region.w/2).cint
          tex.region.w -= halfWidth
          tex.region.x += halfWidth
          game.renderer.render(
            tex,
            entityX+halfWidth,
            entityY)
          tex.region.w += halfWidth
          tex.region.x -= halfWidth

  game.renderer.render(game.player)
  game.player.tick(time)

  for entity in game.level["entities"]:
    let
      entityX = 1200+(entity["x"].num-(1200*45-game.progress*45).int).cint
      entityY = entity["y"].num.cint
    if
      entity["type"].str != "EntityPlayer" and entity["type"].str != "EntityRocket" and
      entityX + 480 > 0 and entityX < 1280:
      if entity["type"].str=="EntityPickup":
        game.renderer.render(
          game.entityTextures[entity["type"].str][int(entity["settings"]["particleType"].num-1)],
          entityX,
          entityY)
        if collides(rect(game.player.pos.x.cint+10,game.player.pos.y.cint+10,70,70),rect(entityX+10,
          entityY+10,60,60)) != nil:
          echo "Collision"
          entity["x"].num = 0
      else:
        let tex = game.entityTextures["EntityGate"][int(entity["settings"]["particleType"].num-1)]
        var halfWidth = (tex.region.w/2).cint
        tex.region.w -= halfWidth
        game.renderer.render(
          tex,
          entityX,
          entityY)
        tex.region.w += halfWidth

  if game.inputs[Input.morph]:
    game.inputs[Input.morph] = false
    game.player.character = Character((ord(game.player.character)+1) mod 3)
    if ord(game.player.character) == 0:
      game.player.animation.textureRegions[0].region.x -= 90*4*2
    else:
      game.player.animation.textureRegions[0].region.x += 90*4
  if game.inputs[Input.jump]:
    if grounded:
      game.inputs[Input.jump] = false
      game.player.vel.y = -800
      grounded = false

  if not grounded:
    game.player.vel.y += 35

  game.progress += time*12
  if game.progress > 1200:
    log "Game Over"

  game.renderer.present()

proc main =
  log "Starting SDL initialization"

  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_JOYSTICK or INIT_HAPTIC)):
    "SDL2 initialization failed"

  # defer blocks get called at the end of the procedure, even if an
  # exception has been thrown
  defer: sdl2.quit()

  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"

  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"
  defer: image.quit()

  when not isMobile:
    let window = createWindow(title = "Our own 2D platformer",
      x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
      w = 1280, h = 720, flags = SDL_WINDOW_SHOWN)
  else:
    var displayMode : DisplayMode
    discard getDesktopDisplayMode(0, displayMode)
    let window = createWindow(title = "Our own 2D platformer",
      x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
      w = displayMode.w, h = displayMode.h, flags =  SDL_WINDOW_OPENGL or SDL_WINDOW_FULLSCREEN)

  sdlFailIf window.isNil: "Window could not be created"
  defer: window.destroy()

  let renderer = window.createRenderer(index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync)
  sdlFailIf renderer.isNil: "Renderer could not be created"
  defer: renderer.destroy()

  when isMobile:
    var
      w,h:cint
    window.getSize(w,h)
    renderer.setScale(w/1280,h/720)
  # Set the default color to use for drawing
  renderer.setDrawColor(r = 110, g = 132, b = 174)

  log "Haptic units: " & $numHaptics()
  log mouseIsHaptic()
  var haptic = hapticOpen(0)
  log $cast[uint](haptic)
  if haptic != nil:
    discard haptic.rumblePlay(0.5,1000)

  log "Starting to load atlas"
  var
    levelStream = newStreamWithRWops(rwFromFile("level1.js", "rb"))
    level = parseJson(levelStream,"level1.json")
    atlas = renderer.loadAtlas("pack.atlas")
    lastTime = epochTime()
    time = lastTime
    tex = atlas.getTextureRegion("Main/mannbarschwein")
  tex.region.w = (tex.region.w/3).cint

  for gate in @[
    atlas.getTextureRegion("Main/gate"),
    atlas.getTextureRegion("Main/skog"),
    atlas.getTextureRegion("Main/sump4")]:
    gate.region.w = (gate.region.w/2).cint
  var
    game = newGame(renderer, window,atlas,level)

  levelStream.close()


  # Game loop, draws each frame
  while not game.inputs[Input.quit]:
    time = epochTime()
    #timeSinceLastTick += time-lastTime
    #if timeSinceLastTick > 1/30:
    game.handleInput()
    game.render(time-lastTime)
    #log "FPS: " & $(1/(time-lastTime))
    lastTime = time
    #  timeSinceLastTick -= 1/30
    #else:
    #  sleep((100/30).int)


main()
