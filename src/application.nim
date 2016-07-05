import sdl2
import sdl2.image
import basic2d
import times
import os
import gamelib.animation
import gamelib.textureregion
import gamelib.textureatlas
import gamelib.logger

type
  SDLException = object of Exception

  Input {.pure.} = enum none, morph, jump, restart, quit

  Character {.pure.} = enum man, bear, pig

  Player = ref object
    #texture: TexturePtr
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

const isMobile = defined(ios) or defined(android)

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc newPlayer(texture: TextureRegion): Player =
  new result
  #result.texture = texture
  result.animation = newAnimation(texture,4,10,AnimationType.pingpong)
  result.pos = point2d(1022,600)
  result.vel = vector2d(0,0)
  result.character = Character.man

proc tick(player: Player, time: float) =
  player.animation.tick(time)

proc newGame(renderer: RendererPtr, window: WindowPtr, atlas: TextureAtlas): Game =
  new result
  result.renderer = renderer
  result.window = window
  result.atlas = atlas
  var tex = atlas.getTextureRegion("Main/mannbarschwein")
  tex.region.w = (tex.region.w/3).cint
  result.player = newPlayer(tex)

proc toInput(key: Scancode): Input =
  result=
    case key
    of SDL_SCANCODE_SPACE: Input.jump
    of SDL_SCANCODE_LSHIFT: Input.morph
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
      y = touch.y * h.cfloat
  else:
    let
      x = touch.x
      y = touch.y

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

proc render(game: Game, time: float) =
  # Draw over all drawings of the last frame with the default color
  game.renderer.clear()
  # Show the result on screen
  game.renderer.render(game.player)
  game.renderer.present()

  game.player.tick(time)

proc main =
  log "Starting SDL initialization"

  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
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

  log "Starting to load atlas"
  var atlas = renderer.loadAtlas("pack.atlas")
  log atlas.getTextureCount
  var
    game = newGame(renderer, window,atlas)
    lastTime = epochTime()
    time = lastTime
  #  timeSinceLastTick:float = 0

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
