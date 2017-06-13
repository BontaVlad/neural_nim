import math
import future
import streams
import parsecsv
import strutils
import sequtils

import alea
import random/urandom, random/mersenne
import matrix
import progress
import input_weights
import hidden_weights


type
  NN = object
    inodes: int
    hnodes: int
    onodes: int
    lr: float
    wih: Matrix[float]
    who: Matrix[float]


proc load_csv(filename: string): seq[CsvRow] =
  var
    stream = newFileStream(filename, fmRead)
    parser: CsvParser

  result = @[]
  if stream == nil: quit("could not open file " & filename)
  open(parser, stream, filename)
  while readRow(parser):
    result.add(parser.row)
  close(parser)


proc expit(x: float): float =
  result = 1 / (1+exp(-x))


proc argmax(inp: Matrix[float]):int =
  var
    max_value = 0.0
  echo inp
  echo "----"
  for e in 0 .. inp.rows - 1:
    if inp[e, 0] > max_value:
      max_value = inp[e, 0]
      result = e


proc newNN*(inodes, hnodes, onodes: int, lr: float): NN {.exportc.}=
  # let
  #   a = gaussian(mu = 0.0, sigma = pow(inodes.float, -0.5))
  #   b = gaussian(mu = 0.0, sigma = pow(hnodes.float, -0.5))
  # var
  #   rng = wrap(initMersenneTwister(urandom(16)))

  result.inodes = inodes
  result.hnodes = hnodes
  result.onodes = onodes
  result.lr = lr

  # random values sampled from a normal(Gaussian) distribution
  # result.wih = makeMatrix(hnodes, inodes, proc(i, j: int): float64 = rng.sample(a))
  # result.who = makeMatrix(onodes, hnodes, proc(i, j: int): float64 = rng.sample(b))
  # result.wih = zeros[float](hnodes, inodes).map(proc(x: float): float = rng.sample(a))
  # result.who = zeros[float](onodes, hnodes).map(proc(x: float): float = rng.sample(b))
  result.wih = newMatrix[float](hnodes, inodes, whi)
  result.who = newMatrix[float](onodes, hnodes, who)


proc learn(nn: var NN, inp, tar: seq[float]) =
  let
    inputs = newMatrix(1, inp.len, inp).transpose
    targets = newMatrix(1, tar.len, tar).transpose
    hidden_inputs = nn.wih * inputs
    hidden_outputs = hidden_inputs.map(proc(x: float64): float64 = expit(x))
    final_inputes = nn.who * hidden_outputs
    final_outputs = final_inputes.map(proc(x: float64): float64 = expit(x))
    output_errors = targets - final_outputs
    hidden_errors = nn.who.transpose * output_errors

  nn.who = nn.who + nn.lr * (output_errors *. final_outputs *. (final_outputs.map(proc(x: float64): float64 = 1.0 - x))) * hidden_outputs.transpose
  nn.wih = nn.wih + nn.lr * (hidden_errors *. hidden_outputs *. (hidden_outputs.map(proc(x: float64): float64 = 1.0 - x))) * inputs.transpose


proc query*(nn: NN, inp: seq[float]):int {.exportc.}=
  let
    inputs = newMatrix(1, inp.len, inp).transpose
    hidden_inputs = nn.wih * inputs
    hidden_outputs = hidden_inputs.map(proc(x: float): float = expit(x))
    final_inputes = nn.who * hidden_outputs
  result = argmax(final_inputes.map(proc(x: float): float = expit(x)))


proc train(nn: var NN, filename: string, epoch: int) =
  let
    training_data = load_csv(filename)

  # echo "training"
  var bar = newProgressBar(total=training_data.len * epoch)
  for _ in 0 .. epoch:
    for row in training_data:
      bar.increment()
      var
        targets = @[0.01].cycle(nn.onodes)
        inputs  = lc[(x.parseFloat / 255.0 * 0.99) + 0.01 | (x <- row[1 .. ^1]), float]
      targets[row[0].parseInt] = 0.99
      nn.learn(inputs, targets)
  bar.finish()

proc examine(nn: NN, filename: string): seq[int] =
  let test_data = load_csv(filename)

  var
    scorecard: seq[int] = @[]

  for row in test_data:
    let
      correct_label = row[0].parseInt
      inputs  = lc[(x.parseFloat / 255.0 * 0.99) + 0.01 | (x <- row[1 .. ^1]), float]
      label = nn.query(inputs)
    echo "label: $# --> $#" % [$label, $correct_label]
    if label == correct_label:
      scorecard.add(1)
    else:
      scorecard.add(0)
  return scorecard


proc dump(fn: string, success_rate: float, w_name: string, weights: Matrix[float]) =
  var fs = newFileStream(fn, fmWrite)
  defer: close(fs)

  if isNil(fs):
    quit("Could not open filename $#" % fn)
  fs.writeLine("const success_rate* = $#" % $success_rate)
  fs.writeLine("let $#* = @[" % w_name)
  for e in weights.data:
    fs.writeLine("  $#," % $e)
  fs.writeLine("]")




when isMainModule:
  var nn = newNN(784, 200, 10, 0.01)
  # nn.train("data/mnist_train.csv", epoch=10)
  let
    scorecard = nn.examine("data/mnist_test.csv")
    performance = scorecard.sum / scorecard.len

  echo "performance= ", performance
  # dump("src/input_weights.nim", performance, "whi", nn.wih)
  # dump("src/hidden_weights.nim", performance, "who", nn.who)
