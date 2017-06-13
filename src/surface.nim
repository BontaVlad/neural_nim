import sequtils
import dom
import colors

import html5_canvas

const
  c_width = 28
  c_height = 28


var
  pos: tuple[x: int, y: int] = (0, 0)
  canvas: Canvas
  canvas_temp: Canvas
  ctx: CanvasRenderingContext2D
  ctx_temp: CanvasRenderingContext2D
  button_pressed = false
  img_data* {.extern: "$1".}: seq[uint8] = @[]

proc clear(e: Event) =
  ctx.clearRect(0, 0, canvas.width.float, canvas.height.float)

proc setPosition(e: Event) =
  pos.x = e.clientX
  pos.y = e.clientY


proc draw(e: Event) =
  if not button_pressed: return

  ctx.beginPath()
  ctx.lineWidth = 25
  ctx.lineCap = RoundCap
  ctx.strokeStyle = "red"
  ctx.moveTo(pos.x.float, pos.y.float) # from
  setPosition(e)
  ctx.lineTo(pos.x.float, pos.y.float) # to
  ctx.stroke() # draw it

proc down(e: Event) =
  button_pressed = true
  setPosition(e)

proc up(e: Event) =
  button_pressed = false


proc guess(e: Event) =
  img_data = @[]
  ctx_temp.drawImage(canvas, 5000.float, 5000.float, c_width.float, c_height.float)
  let raw_data = ctx_temp.getImageData(0, 0, c_width.float, c_height.float).data
  for i in countup(0, raw_data.len, 4):
    img_data.add(raw_data[i])

proc main(event: Event) =
  let
    clear_btn = dom.document.getElementById("clear-btn").Canvas
    guess_btn = dom.document.getElementById("guess-btn").Canvas
  canvas = dom.document.getElementById("surface").Canvas
  ctx = canvas.getContext2D()

  canvas_temp = dom.document.createElement("hidden").Canvas
  ctx_temp = canvas.getContext2D()

  canvas_temp.height = c_height
  canvas_temp.width = c_width
  canvas_temp.style.display = "none"

  canvas.addEventListener("mousemove", draw)
  canvas.addEventListener("mousedown", down)
  canvas.addEventListener("mouseup", up)
  canvas.addEventListener("mouseenter", setPosition)
  clear_btn.addEventListener("click", clear)
  guess_btn.addEventListener("click", guess)


dom.window.onload = main
