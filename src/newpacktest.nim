import sdl2
import sdl2.image
import basic2d
import times
import gamelib.animation
import gamelib.textureregion
import gamelib.ninepatch
import gamelib.textureatlas
import gamelib.logger
import gamelib.files
import gamelib.collisions

type
  SDLException = object of Exception

const isMobile = false

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

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
  #[var t = @[0]
  t.insert(2,1)
  t.insert(5,min(5,t.len))
  echo t]#
  var
    atlas = renderer.loadAtlas("ninepack.atlas")
    #gate = atlas.getTextureRegion("tree_dead")
    #trollanim = atlas.getAnimation("frame")
    np = atlas.getNinePatch("ninepatch_bubble")
    #trollanim = newAnimation(bigtroll,18,10,AnimationType.pingpong)
    lastTime = epochTime()
    time = lastTime
    ended = false

  # Game loop, draws each frame
  var
    r1 = rect(300,300,100,100)
    r2 = rect(200,200,300,200)
  while not ended:
    time = epochTime()
    var event = defaultEvent
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        ended = true
      of MouseMotion:
        r2.w = event.evMouseMotion.x - 200
        r2.h = event.evMouseMotion.y - 200
      else:
        discard
    #var collision = collides(r1,r2)
    renderer.setDrawColor(r = 255, g = 255, b = 255)
    renderer.clear()
    #[renderer.setDrawColor(r = 0, g = 0, b = 174)
    discard renderer.drawRect(r1)
    renderer.setDrawColor(r = 0, g = 174, b = 0)
    discard renderer.drawRect(r2)
    renderer.setDrawColor(r = 174, g = 0, b = 0)
    discard renderer.drawRect(collision.rect)
    ]#
    renderer.renderForRegion(np,200,200,r2.w,r2.h)
    #var r = rect(200,200,300,200)
    renderer.setDrawColor(r = 0, g = 174, b = 0)
    discard renderer.drawRect(r2)
    #[renderer.setDrawColor(r = 0, g = 174, b = 0)
    var rect = np.cornerTL
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.cornerTR
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.cornerBR
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.cornerBL
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    renderer.setDrawColor(r = 0, g = 0, b = 174)
    rect = np.centerT
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.centerR
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.centerL
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    rect = np.centerB
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)
    renderer.setDrawColor(r = 174, g = 0, b = 0)
    rect = np.center
    rect.x -= np.region.x - 200
    rect.y -= np.region.y - 200
    discard renderer.drawRect(rect)]#
    renderer.present()
    lastTime = time

main()
