import math
import future
import streams
import parsecsv
import strutils
import sequtils

import alea
import neo
import random/urandom, random/mersenne


type
  NN = object
    inodes: int
    hnodes: int
    onodes: int
    lr: float
    wih: Matrix[float]
    who: Matrix[float]


proc load_csv(filename: string): seq[CsvRow] =
  result = @[]
  var stream = newFileStream(filename, fmRead)
  if stream == nil: quit("could not open file " & filename)
  var parser: CsvParser
  open(parser, stream, filename)
  while readRow(parser):
    result.add(parser.row)
  close(parser)


proc expit(x: float): float =
  result = 1 / (1+exp(-x))


proc newNN*(inodes, hnodes, onodes: int, lr: float): NN {.exportc.}=
  let
    a = gaussian(mu = 0.0, sigma = pow(inodes.float, -0.5))
    b = gaussian(mu = 0.0, sigma = pow(hnodes.float, -0.5))
  var
    rng = wrap(initMersenneTwister(urandom(16)))

  result.inodes = inodes
  result.hnodes = hnodes
  result.onodes = onodes
  result.lr = lr

  # random values sampled from a normal(Gaussian) distribution
  result.wih = makeMatrix(hnodes, inodes, proc(i, j: int): float64 = rng.sample(a))
  result.who = makeMatrix(onodes, hnodes, proc(i, j: int): float64 = rng.sample(b))


proc learn(nn: var NN, inp, tar: seq[float]) =
  let
    inputs = vector(inp)
    targets = vector(tar)
    hidden_inputs = nn.wih * inputs
    hidden_outputs = hidden_inputs.map(proc(x: float64): float64 = expit(x))
    final_inputes = nn.who * hidden_outputs
    final_outputs = final_inputes.map(proc(x: float64): float64 = expit(x))
    output_errors = targets - final_outputs
    hidden_errors = nn.who.t * output_errors
    who = nn.lr * (output_errors * final_outputs * (final_outputs.map(proc(x: float64): float64 = 1.0 - x))) * hidden_outputs
    wih = nn.lr * (hidden_errors * hidden_outputs * (hidden_outputs.map(proc(x: float64): float64 = 1.0 - x))) * inputs

  # nn.who += nn.lr * (output_errors * final_outputs * (final_outputs.map(proc(x: float64): float64 = 1.0 - x))) * hidden_outputs
  # nn.wih += nn.lr * (hidden_errors * hidden_outputs * (hidden_outputs.map(proc(x: float64): float64 = 1.0 - x))) * inputs


# proc query(nn: NN, inp: seq[float]): Matrix[float]=
#   let
#     inputs = vector(inp)
#     hidden_inputs = nn.wih * inputs
#     hidden_outputs = hidden_inputs.map(proc(x: float64): float64 = expit(x))
#     final_inputes = nn.who * hidden_outputs
#   result = final_inputes.map(proc(x: float64): float64 = expit(x))


proc train(nn: var NN, filename: string, epoch: int) =
  let
    training_data = load_csv(filename)

  for _ in 0 .. epoch:
    for row in training_data:
      var
        targets = @[0.01].cycle(nn.onodes)
        inputs  = lc[(x.parseFloat / 255.0 * 0.99) + 0.01 | (x <- row[1 .. ^1]), float]
      targets[row[0].parseInt] = 0.99
      nn.learn(inputs, targets)
      return


# proc examinate(nn: NN, filename: string): seq[int] =
#   let test_data = load_csv(filename)

#   var scorecard: seq[int] = @[]

#   for row in test_data:
#     let
#       correct_label = row[0].parseInt
#       inputs  = lc[(x.parseFloat / 255.0 * 0.99) + 0.01 | (x <- row[1 .. ^1]), float]
#       outputs = nn.query(inputs)
#       label = outputs.max.round.int

#     if label == correct_label:
#       scorecard.add(1)
#     else:
#       scorecard.add(0)


when isMainModule:
  var nn = newNN(784, 200, 10, 0.01)
  nn.train("data/mnist_train_100.csv", epoch=10)
  # let scorecard = nn.examinate("data/mnist_test_10.csv")
  # echo "performance= ", scorecard.sum / scorecard.len
