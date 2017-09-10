import strutils
import sequtils
import gamelib.files
import streams
import sdl2

type Conversation* = ref object
  startTime*: int
  caller*: string
  receiver*: string
  lines*: seq[tuple[caller: bool , sentence: string]]

proc parseConversationFile*(name: string): seq[Conversation] =
  let rwStream = newStreamWithRWops(rwFromFile(name, "rb"))
  defer: rwStream.close()
  result = @[]
  var
    currentConv: Conversation = nil
    callerSpeaking: bool
    lineNum = 1
  for line in rwStream.lines:
    if line.len == 0 or line.isSpaceAscii():
      continue
    if line.startsWith(" ") or line.startsWith("\t"):
      let sentences = line.split(";")
      for sentence in sentences:
        if sentence.len != 0:
          currentConv.lines.add((caller: callerSpeaking, sentence: sentence.strip()))
      callerSpeaking = not callerSpeaking
    else:
      if currentConv != nil:
        result.add currentConv
      try:
        let
          hour = line[0..1].parseInt()
          minutes = line[3..4].parseInt()
          callerreceiver = line[5..line.high].splitWhitespace
        currentConv = Conversation(startTime: hour*60+minutes, caller: callerreceiver[0], receiver: callerreceiver[1])
        currentConv.lines = @[]
        callerSpeaking = false
      except ValueError:
        echo "Error parsing conversations file " & name & " time " & line[0..4] & " on line " & $lineNum & " is not a valid integer"
        quit 1
  if currentConv != nil:
    result.add currentConv

proc addConversations*(c1: var seq[Conversation], c2: seq[Conversation]) =
  var pos = 0
  for c in c2:
    while pos < c1.len and c.startTime > c1[pos].startTime:
      pos+=1
    c1.insert(c, pos)

when isMainModule:
  var conversations = parseConversationFile("day1/convformat.txt")
  conversations.addConversations(parseConversationFile("day1/convformat2.txt"))
  echo conversations.len
  for conversation in conversations:
    echo conversation.caller
    echo conversation.receiver
    echo conversation.startTime
    for line in conversation.lines:
      echo line.sentence
      echo line.caller
