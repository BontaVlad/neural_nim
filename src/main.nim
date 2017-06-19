import sequtils
import dom
import colors

import html5_canvas
import neural

const
  c_width = 28
  c_height = 28


var
  pos: tuple[x: int, y: int] = (0, 0)
  canvas: Canvas
  canvas_temp: Canvas
  ctx: CanvasRenderingContext2D
  ctx_temp : CanvasRenderingContext2D
  button_pressed = false
  img_data: seq[cuint] = @[]
  nn = newNN(784, 200, 10, 0.01)
  lineWidth = 25
  is_touch = false


proc clear(e: Event) =
  ctx.clearRect(0, 0, canvas.width.float, canvas.height.float)


proc setPosition(e: Event) =
  if is_touch:
    let ev = e.TouchEvent.targetTouches.item(0)
    pos.x = ev.clientX
    pos.y = ev.clientY
    return
  pos.x = e.offsetX
  pos.y = e.offsetY


# crappy hack because I can't differentiate between events and touchEvents
proc setPositionTouch(e: Event) =
  is_touch = true
  setPosition(e)


proc draw(e: Event) =
  e.preventDefault()
  if not button_pressed: return

  ctx.beginPath()
  ctx.lineWidth = lineWidth.float
  ctx.lineCap = RoundCap
  ctx.strokeStyle = "red"
  ctx.moveTo(pos.x.float, pos.y.float) # from
  setPosition(e)
  ctx.lineTo(pos.x.float, pos.y.float) # to
  ctx.stroke() # draw it

proc down(e: Event) =
  e.preventDefault()
  button_pressed = true
  setPosition(e)

proc up(e: Event) =
  e.preventDefault()
  button_pressed = false


proc boundingBox(data: seq[uint8], alphaThreashold = 15, margin = 50): tuple[x, y, minX, minY, maxX, maxY, w, h: int] =
  # code stollen from http://phrogz.net/tmp/canvas_bounding_box.html

  let
    w = canvas.width
    h = canvas.height
  var
    minX= 100_000
    minY= 100_000
    maxX= -1
    maxY= -1
    a: uint8

  for x in 0 .. w - 1:
    for y in 0 .. h - 1:
      a = data[(w*y+x)*4+3]
      if a > alphaThreashold.uint8:
        if x > maxX:
          maxX = x
        if x < minX:
           minX = x
        if y > maxY:
          maxY = y
        if y < minY:
          minY = y
  result.x = minX - margin
  result.y = minY - margin
  result.maxX = maxX
  result.maxY = maxY
  result.minX = minX
  result.minY = minY
  result.w = maxX - minX + margin * 2
  result.h = maxY - minY + margin * 2


proc guess(e: Event) =
  img_data = @[]
  let
    sure = dom.document.getElementById("sure").Node
    maybe = dom.document.getElementById("maybe").Node
    raw_data = ctx.getImageData(0, 0, canvas.width.float, canvas.height.float).data
    bbox = boundingBox(raw_data)
  ctx_temp.drawImage(canvas, bbox.x.float, bbox.y.float, bbox.w.float, bbox.h.float, 0, 0, c_width.float, c_height.float)
  let data = ctx_temp.getImageData(0, 0, c_width.float, c_height.float).data
  for i in countup(0, data.len - 1, 4):
    img_data.add(data[i])
  let output = nn.query(img_data)
  sure.innerHtml = $output.sure
  maybe.innerHtml = $output.maybe


proc correct(e: Event) =
  let
    correct_input = dom.document.getElementById("correct-input").OptionElement
    value = correct_input.value.parseInt
  if img_data.len == 0:
    echo "You must guess something first!"
    return
  nn.correct(img_data, value)


proc resize(e: Event) =
  let
    size = dom.window.innerWidth - 30
  if size > 500:
    return
  canvas.width = size
  canvas.height = size
  if size < 400:
    lineWidth = 15

proc main(event: Event) =
  let
    clear_btn = dom.document.getElementById("clear-btn").Node
    guess_btn = dom.document.getElementById("guess-btn").Node
    correct_btn = dom.document.getElementById("correct-btn").Node
  canvas = dom.document.getElementById("surface").Canvas
  ctx = canvas.getContext2D()

  canvas_temp = dom.document.createElement("hidden").Canvas
  ctx_temp = canvas.getContext2D()

  canvas_temp.height = c_height
  canvas_temp.width = c_width
  canvas_temp.style.display = "none"

  dom.window.addEventListener("resize", resize)
  canvas.addEventListener("mousemove", draw)
  canvas.addEventListener("touchmove", draw)
  canvas.addEventListener("touchmove", setPositionTouch)
  canvas.addEventListener("mousedown", down)
  canvas.addEventListener("touchstart", down)
  canvas.addEventListener("mouseup", up)
  canvas.addEventListener("touchend", up)
  canvas.addEventListener("mouseenter", setPosition)
  clear_btn.addEventListener("click", clear)
  guess_btn.addEventListener("click", guess)
  correct_btn.addEventListener("click", correct)


dom.window.onload = main
