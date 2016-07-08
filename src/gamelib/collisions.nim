import sdl2

type
  Direction* {.pure.} = enum north, northeast, east, southeast, south, southwest, west, northwest, none

  Collision* = ref object
    collision*: Rect
    direction*: Direction

proc collides*(rect1, rect2: Rect): Collision =
  var rect:Rect
  let
    x1inx2 = (rect1.x>=rect2.x and rect1.x<=rect2.x+rect2.w)
    x2inx1 = (rect2.x>=rect1.x and rect2.x<=rect1.x+rect1.w)
    y1iny2 = (rect1.y>=rect2.y and rect1.y<=rect2.y+rect2.h)
    y2iny1 = (rect2.y>=rect1.y and rect2.y<=rect1.y+rect1.h)
  if
    (x1inx2 or x2inx1) and
    (y1iny2 or y2iny1):
      echo "collision"
      return nil
  else:
    return nil
