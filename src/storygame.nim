import "../logger"
import sdl2
import sdl2.gfx
import sdl2.image
import sdl2.ttf
import times
import math
import gamelib.animation
import gamelib.textureregion
import gamelib.ninepatch
import gamelib.textureatlas
import gamelib.collisions
import gamelib.text
import game.king
import game.citizen
import game.gameobject

converter intToCint(x: int): cint = x.cint

type
  SDLException = object of Exception
  Input {.pure.} = enum none, left, right, down
  Inputs = array[Input, bool]

const isMobile = defined(ios) or defined(android)

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc toInput(key: Scancode): Input =
  result=
    case key
    of SDL_SCANCODE_LEFT: Input.left
    of SDL_SCANCODE_RIGHT: Input.right
    of SDL_SCANCODE_DOWN: Input.down
    else: Input.none

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
    let window = createWindow(title = "Our own 1D RTS",
      x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
      w = 1280, h = 720, flags = SDL_WINDOW_SHOWN)
  else:
    var displayMode : DisplayMode
    discard getDesktopDisplayMode(0, displayMode)
    let window = createWindow(title = "Our own 1D RTS",
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

  let
    renderTexture = createTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, 1280, 572)

  renderTexture.setTextureBlendMode(BLENDMODE_BLEND)
  renderer.setDrawBlendMode(BLENDMODE_BLEND)

  when isMobile:
    var
      w,h:cint
    window.getSize(w,h)
    renderer.setScale(w/1280,h/720)

  var
    game = new GameObject
  game.levelWidth = 1248
  var
    atlas = renderer.loadAtlas("pack.atlas")
    #font = openFont("alphbeta.ttf", 25)
    font = openFont("dpcomic.ttf", 26)
    #font = openFont("chary___.ttf", 25)
    #font = openFont("Inconsolata-Regular.ttf", 22)
    text = renderer.newText(font,"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",blendMode = TextBlendMode.blended,maxWidth=380)
    optLeft = renderer.newText(font,"Maecenas sit amet accumsan mi. Vivamus maximus augue ultrices vestibulum condimentum.",blendMode = TextBlendMode.blended,maxWidth=280)
    optRight = renderer.newText(font,"Suspendisse eu bibendum enim. Vestibulum congue turpis nec sem posuere sollicitudin.",blendMode = TextBlendMode.blended,maxWidth=280)
    optSelected = 0
    talking = false
    citAvatar = atlas.getTextureRegion("citizen_avatar")
    kingAvatar = atlas.getTextureRegion("king_avatar")
    coinRequired = atlas.getTextureRegion("coin_required")
    coin = atlas.getTextureRegion("coin_single")
    plagueDoctorTexReg = newTextureRegion(renderer.loadTexture("plague-doctor.png"),rect(0,0,256,32),rect(256,32,0,0))
    plagueDoctor = newAnimation(plagueDoctorTexReg,8,10)
    coins = 0
    lastCoin = 0.0
    shop = newAnimation(atlas.getTextureRegion("shop"),10,0)
    king = newKing(atlas,350)
    groundtiles = atlas.getTextureRegion("tiles")
    ground = newAnimation(groundtiles,19,0,AnimationType.pingpong)
    citizen = game.newCitizen(atlas,800)
    inputs: Inputs
    lastTime = epochTime()
    time = lastTime
    tickLength = 0.0
    ended = false
    level = [7,8,9,10,8,9,8,9,10,9,10,8,9,8,9,7]
    citizenTex = atlas.getTextureRegion("citizen")

  shop.frame = 5
  plagueDoctor.textureRegions.delete(7)
  plagueDoctor.textureRegions.delete(7)

  while not ended:
    time = epochTime()
    tickLength = time - lastTime
    #echo 1/tickLength
    # Check events
    var event = defaultEvent
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        ended = true
      of KeyDown:
        inputs[event.key.keysym.scancode.toInput] = true
      of KeyUp:
        inputs[event.key.keysym.scancode.toInput] = false
      else:
        discard
    renderer.setRenderTarget(renderTexture)
    renderer.setDrawColor(r = 255, g = 255, b = 255)
    renderer.clear()

    # Background gradient
    for i in 0..(572):#-32*4):
      renderer.setDrawColor(r = (109+(146*(i/572))).uint8, g = (145+(110*(i/572))).uint8, b = 255)
      renderer.drawLine(0,i,1280,i)

    # Level
    for i in 0..level.high:#(1280/(32)*3).int:
      ground.frame = level[i]
      renderer.render(ground,i*(32*3)-(king.world_pos-king.camera_pos).cint,572-(32*3),scaleX = 3*pow(-1.0,i.float), scaleY = 3)

    # Game logic
    if (king.camera_pos+64*3).cint>(citizen.pos.int+32-(king.world_pos-king.camera_pos).cint) and king.camera_pos.cint<(citizen.pos.int+32-(king.world_pos-king.camera_pos).cint):
      citizen.playerClose = true
      if inputs[Input.down] and not talking:
        talking = true
        optSelected = 0
        inputs[Input.left] = false
        inputs[Input.right] = false
        inputs[Input.down] = false
    else:
      citizen.playerClose = false

      if (king.camera_pos+64*3).cint>(100+64-(king.world_pos-king.camera_pos).cint) and king.camera_pos.cint<(100+64-(king.world_pos-king.camera_pos).cint):
        if inputs[Input.down]:
          if time - lastCoin > 0.5:
            if coins < 3:
              lastCoin = time
              coins+=1
            else:
              coins = 0
              shop.frame += 1
              if shop.frame>9:
                shop.frame = 5
              lastCoin = time
        else:
          coins = 0
        renderer.render(if coins<2: coinRequired else: coin,100+32*2-10-(king.world_pos-king.camera_pos).int,572-(32*3)-(64*2)+13,scaleX=2,scaleY=2)
        renderer.render(if coins == 0: coinRequired else: coin,100+32*2-10-25-(king.world_pos-king.camera_pos).int,572-(32*3)-(64*2)+16,scaleX=2,scaleY=2)
        renderer.render(if coins != 3 : coinRequired else: coin,100+32*2-10+25-(king.world_pos-king.camera_pos).int,572-(32*3)-(64*2)+16,scaleX=2,scaleY=2)
      else:
        coins = 0

    # Characters
    renderer.render(shop,100-(king.world_pos-king.camera_pos).int,572-(32*3)-(64*2)+13,scaleX=2,scaleY=2)
    renderer.render(citizen,(king.world_pos-king.camera_pos).cint)
    renderer.render(plagueDoctor,800,394,scaleX=3, scaleY=3)
    renderer.render(king)

    if not talking:
      plagueDoctor.tick(tickLength)
      citizen.tick(tickLength)
      king.tick(tickLength,inputs)

    # Draw the renderer twice to create water reflection
    renderer.setRenderTarget(nil)
    renderer.setDrawColor(255,255,255,255)
    renderer.clear()
    for i in 0..(572):#-32*4):
      renderer.setDrawColor(r = (109+(146*(i/572))).uint8, g = (145+(110*(i/572))).uint8, b = 255)
      renderer.drawLine(0,i,1280,i)

    var r = rect(0,572,1280,148)
    renderer.setDrawColor(r = 0, g = 55, b = 128, a = 128)
    renderer.fillRect(r)
    var
      f = rect(0,0,1280,572)
      t = rect(0,0,1280,572)
      all = rect(0,0,1280,720)
      tr = rect(0,572,1280,381)
    discard renderer.copyEx(renderTexture,f,t,0,nil,SDL_FLIP_NONE)
    renderTexture.setTextureAlphaMod(128)
    discard renderer.copyEx(renderTexture,f,tr,0,nil,SDL_FLIP_VERTICAL)
    renderTexture.setTextureAlphaMod(255)

    if talking:
      renderer.setDrawColor(0,0,0,210)
      renderer.fillRect(all)

      if inputs[Input.left]:
        optSelected = -1
      if inputs[Input.right]:
        optSelected = 1
      if inputs[Input.down] and optSelected != 0:
        talking = false
        inputs[Input.down] = false

      renderer.render(text,450,400)
      renderer.render(optLeft,150,600,alpha=(if optSelected == -1: 255 else: 130))
      renderer.render(optRight,450+380+20,600,alpha=(if optSelected == 1: 255 else: 130))
      renderer.render(citAvatar,490,50,scaleX= 30*king.dir * -1,scaleY=30)
      #renderer.render(kingAvatar,490,50,scaleX= 30,scaleY=30)

    renderer.present()

    lastTime = time

main()
