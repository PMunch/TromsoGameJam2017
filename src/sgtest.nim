import "../logger"
import sdl2
import sdl2.image
import sdl2.ttf
import sdl2.mixer
import times
import gamelib.animation
import gamelib.textureregion
import gamelib.ninepatch
import gamelib.textureatlas
import gamelib.collisions
import gamelib.text
import gamelib.scenegraph
import gamelib.tween
import math
import convparser
import dayendreports
import os
import tables
import strutils

import random

converter cintfloat(x:cint):float = x.float
converter intfloat(x:int):float = x.float
#converter floatcint(x:float):cint = x.cint
#converter floatint(x:float):int = x.int
converter cintint(x:cint):int = x.int
converter intcint(x:int):cint = x.cint

type
  Node = ref object
    renderer: proc (renderer: RendererPtr, x, y: cint)
    next: Node

type
  SDLException = object of Exception

type GameStage = enum
  Title, Introduction, Day1, Report1, Cutscene1, Day2, Report2, Cutscene2, Day3, Report3, Ending

var
  stage = GameStage.Title
  day = 0
  strikes = 5
  points = 0

const isMobile = defined(ios) or defined(android)

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

var 
  pendingConversation = -1
  callBuzzerChannel: cint

proc channelDone(channel: cint) {.cdecl.} =
  setupForeignThreadGC()
  if pendingConversation != -1 and channel == callBuzzerChannel:
    pendingConversation = -1
    strikes -= 1

proc main =
  log "Starting SDL initialization"

  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_JOYSTICK or INIT_HAPTIC)):
    "SDL2 initialization failed"

  # defer blocks get called at the end of the procedure, even if an
  # exception has been thrown
  defer: sdl2.quit()

  var
    channel: cint
    audio_rate : cint
    audio_format : uint16
    audio_buffers : cint    = 4096
    audio_channels : cint   = 6
  sdlFailIf(mixer.openAudio(audio_rate, audio_format, audio_channels, audio_buffers) != 0):
    "Failed to open audio"
  defer: mixer.closeAudio()
  discard mixer.allocateChannels(256)

  #sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "0")):
  #  "Linear texture filtering could not be enabled"

  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"
  defer: image.quit()

  when not isMobile:
    let window = createWindow(title = "Our own 2D platformer",
      x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
      w = 1920, h = 1080, flags = SDL_WINDOW_SHOWN)
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
    flags = Renderer_Accelerated)# or Renderer_PresentVsync)
  sdlFailIf renderer.isNil: "Renderer could not be created"
  defer: renderer.destroy()

  when isMobile:
    var
      w, h:cint
    window.getSize(w,h)
    renderer.setScale(w/1920,h/1080)
  else:
    if renderer.setLogicalSize(1920,1080) < 0:
      echo getError()

  type
    Plug = ref object
      texture: TextureRegion
      x, y: cint
      ix, iy: cint
      mx, my: cint
      tween: Tween
      dragging: bool
      connectedWith: Room
    Room = ref object
      guest: string
      #texture: TextureRegion
      #x, y: cint
      collision: Rect
      connectedWith: Plug
      connectedTime: float
      currentConversation: Conversation
      currentTween: Tween
    People = Table[string, Text]

  var
    titleTexture = newTextureRegion(renderer.loadTexture("art/TITLE.png"), 0, 0, 1920, 1080)
    background = newTextureRegion(renderer.loadTexture("art/SWITCHBOARDv3.png"), 0, 0, 1920, 1080)
    dayreportbgs = [
      newTextureRegion(renderer.loadTexture("art/DOC day 1.PNG"), 0, 0, 795, 991),
      newTextureRegion(renderer.loadTexture("art/DOC day 2.PNG"), 0, 0, 795, 991),
      newTextureRegion(renderer.loadTexture("art/DOC day 3.PNG"), 0, 0, 795, 991)
    ]
    cutscenebg = newTextureRegion(renderer.loadTexture("art/Paper big.png"), 0, 0, 799, 988)
    submitbutton = newTextureRegion(renderer.loadTexture("submit.png"), 0, 0, 211, 125)
    continuebutton = newTextureRegion(renderer.loadTexture("continue.png"), 0, 0, 245, 142)
    submitdisabled = newTextureRegion(renderer.loadTexture("submit_disabled.png"), 0, 0, 211, 125)
    reportX = 562
    reportY = 50
    allSelected = false
    font = openFont("digital_counter_7.ttf", 24)
    typewriterText = renderer.newText(openFont("Erika Ormig.ttf", 17), "Hello World", color = color(0,0,0,255), blendMode = TextBlendMode.blended)
    #text = renderer.newText(font, "Hello, world!", blendMode = TextBlendMode.blended, hasTexture = false)
    clockText = renderer.newText(font, "18:56", color = color(255,0,0,255), blendMode = TextBlendMode.blended)
    timeOfDay = 18'f*60 + 55
    oldTimeOfDay = timeOfDay
    incomingCallTexture = newTextureRegion(renderer.loadTexture("art/CALL COMING.png"), 0, 0, 186, 170)
    plugLight = newTextureRegion(renderer.loadTexture("art/PLUG IN USE.png"), 0, 0, 55, 39)
    callBuzzer = mixer.loadWAV("audio/intensifying_beep_5sec.flac")
    ambience = mixer.loadWAV("audio/room_ambient_loop.flac")
    statementSounds = [
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long1.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long2.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long3.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long4.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long5.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Long/statement_long6.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium1.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium2.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium3.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium4.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium5.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Medium/statement_medium6.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short1.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short2.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short3.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short4.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short5.flac"),
      mixer.loadWAV("audio/Chatter on the line/Statements/Short/statement_short6.flac")
    ]
    pickUpSound = [
      mixer.loadWAV("audio/plugin1_grab.flac"),
      mixer.loadWAV("audio/plugin2_grab.flac"),
      mixer.loadWAV("audio/plugin3_grab.flac")
    ]
    plugInSound = [
      mixer.loadWAV("audio/plugin1_insert.flac"),
      mixer.loadWAV("audio/plugin2_insert.flac"),
      mixer.loadWAV("audio/plugin3_insert.flac")
    ]
    plugOutSound = [
      mixer.loadWAV("audio/plugout1.flac"),
      mixer.loadWAV("audio/plugout2.flac"),
      mixer.loadWAV("audio/plugout3.flac")
    ]
    wireTexture = newTextureRegion(renderer.loadTexture("wire.png"), 0, 0, 9, 39)
    plugTexture = newTextureRegion(renderer.loadTexture("art/Plug resting.png"), 0, 0, 88, 137)
    plugConnectedTexture = newTextureRegion(renderer.loadTexture("art/Plug half in.png"), 0, 0, 88, 137)
    people = {
      "OutsideCaller": renderer.newText(
        openFont("font/OutsideCaller.ttf", 28), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "ErnaJensberg": renderer.newText(
        openFont("font/Erna_Jensberg_arial.ttf", 24), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "SvetlanaAksakova": renderer.newText(
        openFont("font/Svetlana_Aksakova_Kremlin Kommisar.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "RubenSchulz": renderer.newText(
        openFont("font/Ruben_Shulz_Merriweather-Bold.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "SovietSpy": renderer.newText(
        openFont("font/Soviet_Spy_SAVINGSB_.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "JuhaniSarpola": renderer.newText(
        openFont("font/Juhani_Sarpola_CWDRKAGE.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "PaulGreening": renderer.newText(
        openFont("font/Paul_Greening_Amatic-Bold.ttf", 28), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "NeilMoore": renderer.newText(
        openFont("font/Neil_Moore_BreeSerif-Regular.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "HansBraun": renderer.newText(
        openFont("font/Hans_Braun_cambriab.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "LauraClarke": renderer.newText(
        openFont("font/Laura_Clarke_PlayfairDisplay-Bold.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false),
      "ZsofiFekete": renderer.newText(
        openFont("font/Zsofi_Fekete_VarelaRound-Regular.ttf", 26), "Hello", blendMode = TextBlendMode.blended, hasTexture = false)
      }.toTable
    postits = [
      newTextureRegion(renderer.loadTexture("art/Post-it notes/postit YOU ARE UNDERCOVER.png"), 0, 0, 320, 270),
      newTextureRegion(renderer.loadTexture("art/Post-it notes/postit STAY ALERT.png"), 0, 0, 320, 270),
      newTextureRegion(renderer.loadTexture("art/Post-it notes/postit NO SLACKING.png"), 0, 0, 320, 270),
      newTextureRegion(renderer.loadTexture("art/Post-it notes/postit I AM WARNING YOU.png"), 0, 0, 320, 270),
      newTextureRegion(renderer.loadTexture("art/Post-it notes/postit LAST WARNING.png"), 0, 0, 320, 270)
    ]
    plugs = [
      Plug(texture: plugTexture, x: 740, y: 800),
      Plug(texture: plugTexture, x: 905, y: 800),
      Plug(texture: plugTexture, x: 1070, y: 800)
    ]
    rooms = [
      Room(guest: "LauraClarke", collision: rect(755,248,150,150)),
      Room(guest: "JuhaniSarpola", collision: rect(998,248,150,150)),
      Room(guest: "PaulGreening", collision: rect(1238,248,150,150)),
      Room(guest: "SvetlanaAksakova", collision: rect(755,465,150,150)),
      Room(guest: "NeilMoore", collision: rect(998,465,150,150)),
      Room(guest: "HansBraun", collision: rect(1238,465,150,150)),
      Room(guest: "ErnaJensberg", collision: rect(755,675,150,150)),
      Room(guest: "RubenSchulz", collision: rect(998,675,150,150)),
      Room(guest: "ZsofiFekete", collision: rect(1238,675,150,150)),
    ]
    mask = createTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, 1280, 720)
    textmap = createTexture(renderer, SDL_PIXELFORMAT_RGB888, SDL_TEXTUREACCESS_STREAMING, 100,100)
    scenegraph = newSceneGraph()
    lastTime = epochTime()
    time = lastTime
    tickLength = 0.0
    ended = false
    s = rect(0,0,1280,720)
    mouseX:cint = 0
    mouseY:cint = 0
    days: seq[seq[Conversation]] = @[newSeq[Conversation](),newSeq[Conversation](),newSeq[Conversation]()]
    nextConversation = 0
    reports = [
      parseReportFile("day1report.txt"),
      parseReportFile("day2report.txt"),
      parseReportFile("day3report.txt")
    ]
    cutscenes = [
      parseReportFile("intro1.txt"),
      parseReportFile("cutscene1-2.txt"),
      parseReportFile("cutscene2-3.txt"),
      parseReportFile("ending-win.txt"),
      parseReportFile("ending-lose.txt")
    ]
  for kind, path in walkDir("day1"):
    if kind == pcFile:
      days[0].addConversations(parseConversationFile(path))
  for kind, path in walkDir("day2"):
    if kind == pcFile:
      days[1].addConversations(parseConversationFile(path))
  for kind, path in walkDir("day3"):
    if kind == pcFile:
      days[2].addConversations(parseConversationFile(path))

  for plug in plugs.mitems:
    plug.ix = plug.x
    plug.iy = plug.y
  proc drawCable(renderer: RendererPtr, sx, sy, ex, ey: cint) =
    let
      totalLength = 600
      lineLen = sqrt((sx-ex).float.pow(2)+(sy-ey).float.pow(2))
    if lineLen < totalLength:
      let
        midx = sx + (ex-sx) div 2
        x1 = sx.float64
        x2 = midx.float64
        x3 = ex.float64
        y1 = sy.float64
        #y2 = my
        y3 = ey.float64
        z = totalLength.float64
        midy =  (-4*x1.pow(2)*y1 + 4* x1.pow(2 )*y3 + sqrt((4* x1.pow(2 )*y1 - 4* x1.pow(2 )*y3 - 8* x1* x2* y1 + 8 * x1* x2* y3 + 8* x2* x3* y1 - 8* x2* x3* y3 - 4* x3.pow(2 )*y1 + 4* x3.pow(2 )*y3 + 4* y1.pow(3 )- 4* y1.pow(2 )*y3 - 4* y1* y3.pow(2 )- 4* y1* z.pow(2 )+ 4* y3.pow(3 )- 4* y3* z.pow(2)).pow(2 )- 4* (-4* y1.pow(2 )+ 8* y1* y3 - 4* y3.pow(2 )+ 4* z.pow(2))* (-x1.pow(4 )+ 4* x1.pow(3 )*x2 - 4* x1.pow(2 )*x2.pow(2 )- 4* x1.pow(2 )*x2* x3 + 2* x1.pow(2 )*x3.pow(2 )- 2* x1.pow(2 )*y1.pow(2 )+ 2* x1.pow(2 )*y3.pow(2 )+ 2* x1.pow(2 )*z.pow(2 )+ 8* x1* x2.pow(2 )*x3 - 4* x1* x2* x3.pow(2 )+ 4* x1* x2* y1.pow(2 )- 4* x1* x2* y3.pow(2 )- 4* x1* x2* z.pow(2 )- 4* x2.pow(2 )*x3.pow(2 )+ 4* x2.pow(2 )*z.pow(2 )+ 4* x2* x3.pow(3 )- 4* x2* x3* y1.pow(2 )+ 4 * x2* x3* y3.pow(2 )- 4* x2* x3* z.pow(2 )- x3.pow(4 )+ 2* x3.pow(2 )*y1.pow(2 )- 2* x3.pow(2 )*y3.pow(2 )+ 2* x3.pow(2 )*z.pow(2 )- y1.pow(4 )+ 2* y1.pow(2 )*y3.pow(2 )+ 2* y1.pow(2 )*z.pow(2 )- y3.pow(4 )+ 2* y3.pow(2 )*z.pow(2 )- z.pow(4))) + 8* x1* x2* y1 - 8* x1* x2* y3 - 8* x2* x3* y1 + 8* x2* x3* y3 + 4* x3.pow(2 )*y1 - 4* x3.pow(2 )*y3 - 4* y1.pow(3 )+ 4* y1.pow(2 )*y3 + 4 * y1* y3.pow(2 )+ 4* y1* z.pow(2 )- 4* y3.pow(3 )+ 4* y3* z.pow(2))/(2 * (-4* y1.pow(2 )+ 8* y1* y3 - 4* y3.pow(2 )+ 4 * z.pow(2)))
        tx = (midx-sx)/(if ex==sx: 1 else: ex-sx)
        ty = (midy-ey)/(if sy == ey: 1 else: sy-ey)
        t = initTween(1,tx,ty,tx,ty)
      var
        ox = ex
        oy = ey
      for i in 0..10:
        let
          cx = (ex+(1-i*((1/10))*(ex-sx))).cint
          cy = (sy+(1-t.value)*(ey-sy)).cint
          angle = arctan2(cy - oy, cx - ox) * 180 / PI
          len = sqrt((ox-cx).float.pow(2)+(oy-cy).float.pow(2))
        renderer.render(wireTexture,ox,oy, rotation = angle-90, scaley = len/31)
        ox = cx
        oy = cy
        t.tick(1/10)
    else:
      var
        ox = ex
        oy = ey
      for i in 0..10:
        let
          cx = (ex + ((sx-ex)/10)*i).cint
          cy = (ey + ((sy-ey)/10)*i).cint
          angle = arctan2(cy - oy, cx - ox) * 180 / PI
          len = sqrt((ox-cx).float.pow(2)+(oy-cy).float.pow(2))
        renderer.render(wireTexture,ox,oy, rotation = angle-90, scaley = len/31)
        ox = cx
        oy = cy

  let sound2 = mixer.loadMUS("audio/Disco_radio.ogg")
  if isNil(sound2):
    quit("Unable to load sound file")

  discard mixer.playMusic(sound2, -1); #ogg/flac
  discard mixer.playChannel(-1, ambience, -1)
  mixer.channelFinished(channelDone)

  while not ended:
    time = epochTime()
    tickLength = time - lastTime
    lastTime = time
    var event = defaultEvent
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        ended = true
      of MouseMotion:
        mouseX = event.motion.x
        mouseY = event.motion.y
      of MouseButtonDown:
        if stage == Day1 or stage == Day2 or stage == Day3:
          for plug in plugs.mitems:
            if plug.tween == nil and  point(mouseX, mouseY).within rect(plug.x, plug.y, plug.texture.size.w, plug.texture.size.h):
              plug.mx = mouseX - plug.x
              plug.my = mouseY - plug.y
              plug.dragging = true
              if plug.connectedWith != nil:
                if plug.connectedWith.currentConversation != nil and plug.connectedWith.connectedTime + plug.connectedWith.currentConversation.lines.len*2 > timeOfDay:
                  strikes -= 1
                plug.connectedWith.currentConversation = nil
                plug.connectedWith.connectedWith = nil
                plug.connectedWith = nil
                plug.texture = plugTexture
                discard mixer.playChannel(-1,plugOutSound[plugOutSound.high.rand], 0); #ogg/flac  
              else:
                discard mixer.playChannel(-1,pickUpSound[pickUpSound.high.rand], 0); #ogg/flac  
      of MouseButtonUp:
        if stage == Introduction or stage == Cutscene1 or stage == Cutscene2 or stage == Ending:
          var r = continuebutton.region
          r.x += 450 + reportX
          r.y += 750 + reportY
          if point(mouseX, mouseY).within r:
            if stage == Ending:
              points = 0
              strikes = 5
            timeOfDay = 18'f*60 + 55
            stage = if stage == Introduction: Day1 elif stage == Cutscene1: Day2 elif stage == Cutscene2: Day3 else: Title
        if stage == Report1 or stage == Report2 or stage == Report3:
          for option in reports[(if stage == Report1: 0 elif stage == Report2: 1 else: 2)].options:
            var r = option.size
            r.x += 130 + reportX
            r.y += 245 + reportY
            if point(mouseX, mouseY).within r:
              option.selected = (option.selected + 1) mod option.entries.len 
          if allSelected:
            var r = submitbutton.region
            r.x += 500 + reportX
            r.y += 750 + reportY
            if point(mouseX, mouseY).within r:
              let neededPoints = if stage == Report1: 3 elif stage == Report2: 2 else: 2
              var
                reportPoints = 0
                seenBefore:seq[string] = @[]
              for option in reports[(if stage == Report1: 0 elif stage == Report2: 1 else: 2)].options:
                if not seenBefore.contains option.entries[option.selected].text:
                  seenBefore.add option.entries[option.selected].text
                  if option.entries[option.selected].correct:
                    reportPoints += 1
              if reportPoints >= neededPoints:
                stage = if stage == Report1: Cutscene1 elif stage == Report2: Cutscene2 else: Ending
                points += reportPoints
              else:
                stage = Ending
              day += 1
        if stage == Day1 or stage == Day2 or stage == Day3:
          var firstUnconnected = false
          for plug in plugs.mitems:
            if not firstUnconnected and plug.connectedWith == nil:
              firstUnconnected = true
            else:
              firstUnconnected = false
            if plug.dragging:
              if firstUnconnected:
                for room in rooms.mitems:
                  if point(mouseX-plug.mx+25, mouseY-plug.my+60).within room.collision:
                    if room.connectedWith == nil and pendingConversation != -1 and room.guest == days[day][pendingConversation].receiver:
                      plug.connectedWith = room
                      room.connectedWith = plug
                      plug.x = room.collision.x
                      plug.y = room.collision.y
                      plug.texture = plugConnectedTexture
                      room.currentConversation = days[day][pendingConversation]
                      room.connectedTime = timeOfDay
                      discard mixer.playChannel(-1,plugInSound[plugInSound.high.rand], 0); #ogg/flac  
                      pendingConversation = -1
                      discard mixer.haltChannel(callBuzzerChannel)
                      break
                    else:
                      strikes -= 1
              if plug.connectedWith == nil:
                plug.tween = initTween(1, Ease.OutElastic)
                plug.x = mouseX-plug.mx
                plug.y = mouseY-plug.my
            plug.dragging = false
        if stage == Title:
          stage = Introduction
      else:
        discard

    renderer.setRenderTarget(nil)
    renderer.setDrawColor(r = 0, g = 0, b = 0)
    renderer.clear()
    renderer.render(background,0,0)
    #let alpha = 255'u8 - min(255.float, max(0.float, sqrt((200-mouseX).float.pow(2)+(200-mouseY).float.pow(2)))).uint8 
    #renderer.setDrawColor(255,0,0,alpha)
    renderer.setDrawBlendMode(BLENDMODE_BLEND)
    if strikes > 0:
      renderer.render(postits[5-strikes], 1550, 200)
    else:
      renderer.render(postits[4], 1550, 200)

    renderer.render(clockText, 170, 900)
    renderer.setDrawColor(255,255,255,255)
    for plug in plugs.mitems:
      if plug.tween != nil:
        plug.tween.tick(tickLength)
      if plug.dragging:
        renderer.drawCable(plug.ix+40,plug.iy + 170, mouseX-plug.mx + 40, mouseY-plug.my + 110)
        renderer.render(plug.texture, mouseX - plug.mx, mouseY - plug.my)
      else:
        if plug.tween != nil:
          let
            x = (plug.x + (plug.ix-plug.x)*plug.tween.value).cint
            y = (plug.y + (plug.iy-plug.y)*plug.tween.value).cint
          renderer.drawCable(plug.ix + 40, plug.iy + 170, x + 40, y + 110)
          renderer.render(plug.texture, x, y)
          if plug.tween.t >= plug.tween.duration:
            plug.tween = nil
            plug.x = plug.ix
            plug.y = plug.iy
        elif plug.connectedWith != nil:
          renderer.drawCable(plug.ix + 40, plug.iy + 170, plug.x + 50, plug.y + 110)
          renderer.render(plug.texture, plug.x + 23, plug.y + 5)
        else:
          renderer.drawCable(plug.ix + 40, plug.iy + 170,plug.ix+40,plug.iy+110)
          renderer.render(plug.texture, plug.ix, plug.iy)
    for room in rooms.mitems:
      #renderer.drawRect(room.collision)
      #renderer.render(room.texture, room.x, room.y)
      if room.currentConversation != nil:
        let
          duration = timeOfDay - room.connectedTime
          lineNumber = (duration / 2).int
          oldLineNumber = ((oldTimeOfDay - room.connectedTime) / 2).int
          timeShown = (duration mod 2)
        if lineNumber < room.currentConversation.lines.len:
          let
            currentLine = room.currentConversation.lines[lineNumber]
            currentSpeaker = people[if currentLine.caller: room.currentConversation.caller else: room.currentConversation.receiver]
          currentSpeaker.setText(currentLine.sentence)
          if oldLineNumber != lineNumber or room.currentTween == nil:
            room.currentTween = initTween(0.5, Ease.OutSine)
            let mumbleID = rand(5) + (if currentLine.sentence.len < 6: 12 else: 6)
            discard mixer.playChannel(-1,statementSounds[mumbleID],0)
          if timeShown > 1.5:
            room.currentTween.tick(tickLength)
          discard currentSpeaker.surface.lockSurface()
          var pixels = cast[ptr array[0..int.high, uint32]](currentSpeaker.surface.pixels)
          for i in 0..<currentSpeaker.surface.w*currentSpeaker.surface.h:
            let initialAlpha = ((pixels[][i] shr (8*3)) and 0xff).uint8
            if initialAlpha != 0:
              let
                x = room.collision.x + i mod currentSpeaker.surface.w - (currentSpeaker.surface.w/2 - room.collision.w/2).int
                y = room.collision.y + i div currentSpeaker.surface.w - (room.currentTween.value * 30).cint
                alpha = initialAlpha.float - min(initialAlpha.float, max(0'f, sqrt((x-mouseX).float.pow(2)+(y-mouseY).float.pow(2))/2))
              renderer.setDrawColor(255,255,255,(alpha*(1-room.currentTween.value)).uint8)
              renderer.drawPoint(x, y)
          currentSpeaker.surface.unlockSurface()
        else:
          room.currentConversation = nil
          room.currentTween = nil

    if pendingConversation != -1:
      renderer.setDrawColor(255,0,0,255)
      renderer.render(incomingCallTexture, 510,160)
      for plug in plugs:
        if plug.connectedWith == nil:
          #var plugLight = rect(plug.ix,plug.iy, 30,30)
          renderer.render(plugLight, plug.ix - 55, plug.iy + 150)
          let currentSpeaker = people[days[day][pendingConversation].caller]
          #echo days[day][pendingConversation].receiver
          #currentSpeaker.setText("Connect me to " & days[day][pendingConversation].receiver & " please")
          var i = 0
          for room in rooms:
            if room.guest == days[day][pendingConversation].receiver:
              break
            i+=1
          currentSpeaker.setText("Connect me to " & $(1+(i div 3)) & "0" & $(1+(i mod 3)) & " please")
          discard currentSpeaker.surface.lockSurface()
          var pixels = cast[ptr array[0..int.high, uint32]](currentSpeaker.surface.pixels)
          for i in 0..<currentSpeaker.surface.w*currentSpeaker.surface.h:
            let initialAlpha = ((pixels[][i] shr (8*3)) and 0xff).uint8
            if initialAlpha != 0:
              let
                x = (if plug.dragging: mouseX-plug.mx else: plug.x) + i mod currentSpeaker.surface.w + (plugTexture.region.w/2 - currentSpeaker.surface.w/2).int
                y = (if plug.dragging: mouseY-plug.my else: plug.y) + i div currentSpeaker.surface.w
                alpha = initialAlpha.float - min(initialAlpha.float, max(0'f, sqrt((x-mouseX).float.pow(2)+(y-mouseY).float.pow(2))/2))
              renderer.setDrawColor(255,255,255,alpha.uint8)
              renderer.drawPoint(x, y)
          currentSpeaker.surface.unlockSurface()
          break
    #echo 1/tickLength
    if stage == Day1 or stage == Day2 or stage == Day3:
      oldTimeOfDay = timeOfDay
      timeOfDay += tickLength
      if timeOfDay.int mod 60 != oldTimeOfDay.int mod 60:
        #echo $(timeOfDay.int div 60) & ":" & $(timeOfDay.int mod 60)
        if nextConversation < days[day].len and days[day][nextConversation].startTime <= timeOfDay:
          #echo days[day][nextConversation].receiver
          pendingConversation = nextConversation
          nextConversation+=1
          callBuzzerChannel = mixer.playChannel(-1, callBuzzer, 0)
          #echo days[day][nextConversation].caller
        #text.setText($(timeOfDay.int div 60) & ":" & align($(timeOfDay.int mod 60), 2,'0'))
        clockText.setText($(timeOfDay.int div 60) & ":" & align($(timeOfDay.int mod 60), 2,'0'))
      if timeOfDay >= 25*60:
        stage = if stage == Day1: Report1 elif stage == Day2: Report2 else: Report3

    #typewriterText.setText(day1report.text)
    if stage == Report1 or stage == Report2 or stage == Report3:
      renderer.setDrawColor(0,0,0,150)
      var screen = rect(0,0,1920,1080)
      renderer.fillRect(screen)
      renderer.render(dayreportbgs[(if stage == Report1: 0 elif stage == Report2: 1 else: 2)], reportX, reportY)
      var l = 0
      for line in reports[(if stage == Report1: 0 elif stage == Report2: 1 else: 2)].lines:
        if line.len != 0:
          typewriterText.setColor color(0,0,0,255)
          typewriterText.setText(line)
          renderer.render(typewriterText, 120 + reportX, 260+l*17 + reportY)
        l+=1
      allSelected = true
      for option in reports[(if stage == Report1: 0 elif stage == Report2: 1 else: 2)].options:
        var r = option.size
        r.x += 130 + reportX
        r.y += 245 + reportY
        renderer.setDrawColor(0,0,0,255)
        renderer.fillRect(r)
        if option.selected != -1:
          typewriterText.setColor color(230,230,230,255)
          typewriterText.setText(option.entries[option.selected].text)
          renderer.render(typewriterText, r.x,r.y-2)
        else:
          allSelected = false
      renderer.render(if allSelected: submitbutton else: submitdisabled, 500+reportX, 750+reportY)

    if stage == Introduction or stage == Cutscene1 or stage == Cutscene2 or stage == Ending:
      renderer.setDrawColor(0,0,0,150)
      var screen = rect(0,0,1920,1080)
      renderer.fillRect(screen)
      renderer.render(cutscenebg, reportX, reportY)
      var
        l = 0
        currentcutscene = cutscenes[if stage == Introduction: 0 elif stage == Cutscene1: 1 elif stage == Cutscene2: 2 else: (if strikes != 0 and points >= 7: 3 else: 4)]
      for line in currentcutscene.lines:
        if line.len != 0:
          typewriterText.setColor color(0,0,0,255)
          typewriterText.setText(line)
          renderer.render(typewriterText, 120 + reportX, 100+l*17 + reportY)
        l+=1
      renderer.render(continuebutton, 450+reportX, 750+reportY)

    if stage == Title:
      renderer.render(titleTexture, 0, 0)

    if strikes == 0:
      stage = GameStage.Ending

    renderer.present()

main()
