import strutils
import sequtils
import gamelib.files
import streams
import sdl2
import random

type
  Entry* = ref object
    text*: string
    correct*: bool
  Option* = ref object
    entries*: seq[Entry]
    selected*: int
    size*: Rect
  Report* = ref object
    lines*: seq[string]
    options*: seq[Option]

proc parseReportFile*(name: string): Report =
  let rwStream = newStreamWithRWops(rwFromFile(name, "rb"))
  defer: rwStream.close()
  new result
  result.lines = @[]
  result.options = @[]
  var
    isOption = false
    wasOption = false
    lastLen = 0
    currentOption: Option #tuple[options: seq[tuple[text: string, correct: bool]], selected: int, size: Rect]
  for line in rwStream.lines:
    if line.len == 0: continue
    if line[0] != '#' and isOption == false:
      if not wasOption:
        result.lines.add line
      else:
        wasOption = false
        result.lines[result.lines.high] = result.lines[result.lines.high] & line
    elif line.allCharsInSet(Whitespace):
      isOption = false
      wasOption = true
      currentOption.entries.shuffle()
      result.options.add currentOption
    elif isOption:
      var entry = new Entry
      entry.text = line[(if line[0]=='+': 1 else: 0)..line.high]
      entry.correct = line[0] == '+'
      currentOption.entries.add entry
      #currentOption.options.add((text: line[(if line[0]=='+': 1 else: 0)..line.high], correct: line[0] == '+'))
    else:
      isOption = true
      #currentOption = (options: @[], selected: -1, size: rect((result.lines[result.lines.high].len*10).cint, (result.lines.len*17).cint ,(line.len*10).cint ,17))
      currentOption = new Option
      currentOption.entries = @[]
      currentOption.selected = -1
      currentOption.size = rect((result.lines[result.lines.high].len*10).cint, (result.lines.len*17).cint ,(line.len*10).cint ,17)
      result.lines[result.lines.high] = result.lines[result.lines.high] & " ".repeat(line.len+1)


when isMainModule:
  var report = parseReportFile("day1report.txt")
  echo report.text
  for opt in report.options:
    echo opt.pos
