import "../logger"
import sdl2
import sdl2.image
import sdl2.ttf
import times
import gamelib.animation
import gamelib.textureregion
import gamelib.ninepatch
import gamelib.textureatlas
import gamelib.collisions
import gamelib.text

converter intToCint(x: int): cint = x.cint

type
  SDLException = object of Exception

const isMobile = defined(ios) or defined(android)

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

  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "0")):
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

  sdlFailIf(ttfInit() == SdlError): "SDL2 TTF initialization failed"
  defer: ttfQuit()

  let renderer = window.createRenderer(index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync)
  sdlFailIf renderer.isNil: "Renderer could not be created"
  defer: renderer.destroy()

  when isMobile:
    var
      w,h:cint
    window.getSize(w,h)
    renderer.setScale(w/1280,h/720)

  var
    atlas = renderer.loadAtlas("pack.atlas")
    lastTime = epochTime()
    time = lastTime
    tick = 0.0
    ended = false
    r1 = rect(200,300,100,100)
    r2 = rect(200,300,50,50)
    anim = atlas.getAnimation("king_walk")
    animStrip = atlas.getTextureRegion("beggar")
    kingstand = atlas.getTextureRegion("king_stand")
    animStrip2 = atlas.getTextureRegion("citizen")
    anim2 = newAnimation(animStrip, 11, 12, AnimationType.pingpong)
    anim3 = newAnimation(animStrip2, 8, 12, AnimationType.pingpong)
    stat1 = atlas.getTextureRegion("citizen")
    stat2 = atlas.getTextureRegion("beggar")
    ninepatch = atlas.getNinePatch("ninepatch_bubble")
    tex = renderer.loadTexture("king_stand.png")
    ninepatchRegion = rect(700,300,150,300)
    nph = 150.0
    npw = 300.0
    grow = true
    font = openFont("DejaVuSans.ttf", 28)
    text = renderer.newText(font,"Text",color(0,0,0,255),TextBlendMode.blended)
    rot = 0.0

  while not ended:
    time = epochTime()
    tick = time - lastTime
    var event = defaultEvent
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        ended = true
      of MouseMotion:
        r2.x = event.evMouseMotion.x
        r2.y = event.evMouseMotion.y
      else:
        discard
    var collision = collides(r1,r2)
    renderer.setDrawColor(r = 255, g = 255, b = 255)
    renderer.clear()
    renderer.setDrawColor(r = 0, g = 0, b = 174)
    discard renderer.drawRect(r1)
    renderer.setDrawColor(r = 0, g = 174, b = 0)
    discard renderer.drawRect(r2)
    renderer.setDrawColor(r = 174, g = 0, b = 0)
    discard renderer.drawRect(collision.rect)
    if collision == nil:
      text.setText("No collision")
    else:
      text.setText("Collision direction: " & $collision.direction)
    anim.tick(tick)
    anim2.tick(tick)
    anim3.tick(tick)
    var kingbox = rect(400,364,24,128)
    renderer.render(kingstand,400,364,0,2,2)
    renderer.render(anim,400,364,0,2,2)
    renderer.drawRect(kingbox)
    var pos = 400
    for tex in anim.textureRegions:
      renderer.render(tex,pos,300)
      var box = rect(pos,300,64,64)
      renderer.drawRect(box)
      pos+=64
    renderer.render(anim2,400,100,rot,2,2)
    var r6 = rect(500,400,352,32)
    #var r7 = rect(400,100,32,32)
    renderer.render(stat1,500,200)
    renderer.render(stat2,500,400)
    var r10 = rect(500,200,256,32)
    #var r11 = rect(700,300,96*2,160*2)
    #renderer.render(stat1,700,300,0,2,2)
    discard renderer.drawRect(r10)
    discard renderer.drawRect(r6)
    renderer.render(anim3,500,100,rot,2,2)
    #discard renderer.drawRect(r7)
    #renderer.render(stat2,300,450,2,2)
    #var r3 = rect(500,300,192,320)
    #var r5 = rect(500,300,96,160)
    #var r4 = rect(300,450,128,128)
    var
      w = 54
      h = 64
      offset = point(0,0)
      rotated = true
      scaleX = 3
      scaleY = 3
    if rotated:
      let s = scaleX
      scaleX = scaleY
      scaleY = s
    var
      src = rect(offset.x,offset.y,w,h)
      #dst = rect(100+10*scaleX+(if rotated: h/2*scaleY.float-(w/2).float*scaleX.float else: 0).cint,100+offset.y*scaleY+(if rotated: (w/2).cint*scaleX-(h/2).cint*scaleY else: 0),(w-10)*scaleX,(h-offset.y)*scaleY)
      r8 = rect(100,100,64*scaleX,64*scaleY)
      #c = point(((w/2).cint-offset.x)*scaleX,((h/2).cint-offset.y)*scaleY)
      dst = rect(130,100,54*3,64*3)
      c = point(22*3,32*3)
    #echo dst
    renderer.copyEx(tex,
      src,
      dst,
      angle = rot,
      center = c.addr,
      flip = SDL_FLIP_NONE)
    renderer.drawRect(r8)
    #discard renderer.drawRect(r4)
    #discard renderer.drawRect(r5)
    #discard renderer.drawRect(r6)
    #discard renderer.drawRect(r7)
    rot += 30*tick
    ninepatchRegion.w = npw.cint
    ninepatchRegion.h = nph.cint
    #renderer.renderForRegion(ninepatch,ninepatchRegion)
    #discard renderer.drawRect(ninepatchRegion)
    renderer.render(text,20,20)
    renderer.present()
    if grow:
      nph += 10*(tick)
      npw += 40*(tick)
    else:
      nph -= 10*(tick)
      npw -= 40*(tick)
    if npw>450:
      grow = false
    elif npw<300:
      grow = true
    lastTime = time

main()
