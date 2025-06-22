import CoreGraphics

class KeyboardMapping: Hashable {
  let key: Key
  let modifiers: [Modifier]

  struct ParseError: Error {
    let message: String
  }

  init(key: Key, modifiers: [Modifier] = []) {
    self.key = key
    self.modifiers = modifiers
  }

  static func == (lhs: KeyboardMapping, rhs: KeyboardMapping) -> Bool {
    return lhs.modifiers == rhs.modifiers && lhs.key == rhs.key
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(key)
    for mod in modifiers {
      hasher.combine(mod.rawValue)
    }
  }

  private func getPresentModifiers(event: CGEvent) -> [Modifier] {
    var modifiers: [Modifier] = []

    for mod in Modifier.allCases {
      if event.flags.contains(mod.cgEventFlag) {
        modifiers.append(mod)
      }
    }
    return modifiers
  }

  // TODO IFUCKING
  func matches(event: CGEvent) -> Bool {
    let modifiers = getPresentModifiers(event: event)
    if modifiers.sorted(by: <) != self.modifiers.sorted(by: <) {
      return false
    }

    return key.rawValue == event.getIntegerValueField(.keyboardEventKeycode)
  }

  static func itoa(key: Int64) -> String? {
    return valueToMapping[key]
  }

  func isNonPrintable() -> Bool {
    switch key {
    case Key.enter, Key.esc, Key.tab, Key.backspace:
      return true
    default:
      return false
    }
  }

  static func create(from: String) throws -> KeyboardMapping {
    var value = from
    if value.first == "'" && value.last == "'" && value.count >= 3 {
      value.removeLast()
      value.removeFirst()
    }
    var keyStr = ""
    while mappingToValue[keyStr] == nil {
      if let char = value.popLast() {
        keyStr.insert(char, at: keyStr.startIndex)
      } else {
        throw ParseError(message: "Failed to do something!! TODO ")
      }
    }

    guard let keyRaw = mappingToValue[keyStr], let key = Key(rawValue: keyRaw) else {
      throw ParseError(message: "Parsed key was not found in dict")
    }
    var modStr = ""
    var mods: [Modifier] = []
    while !value.isEmpty {
      guard let modValue = mappingToValue[modStr] else {
        modStr.insert(value.popLast()!, at: modStr.startIndex)
        continue
      }
      guard let mod = Modifier(rawValue: modValue) else {
        throw ParseError(message: "WARNING: Modifier failed to be parsed")
      }
      mods.append(mod)
      modStr.removeAll()
    }
    if modStr.isEmpty {
      return KeyboardMapping(key: key, modifiers: mods)
    }

    guard let modValue = mappingToValue[modStr] else {
      throw ParseError(message: "Mod value failed to parse '\(modStr)'")
    }
    guard let mod = Modifier(rawValue: modValue) else {
      throw ParseError(message: "WARNING: Modifier failed to be parsed")
    }
    mods.append(mod)
    return KeyboardMapping(key: key, modifiers: mods)
  }

  private static let mappingToValue: [String: Int64] = [
    "a": Key.a.rawValue,
    "s": Key.s.rawValue,
    "d": Key.d.rawValue,
    "f": Key.f.rawValue,
    "g": Key.g.rawValue,
    "h": Key.h.rawValue,
    "j": Key.j.rawValue,
    "k": Key.k.rawValue,
    "l": Key.l.rawValue,
    ";": Key.semicolon.rawValue,
    "'": Key.quote.rawValue,
    "z": Key.z.rawValue,
    "x": Key.x.rawValue,
    "c": Key.c.rawValue,
    "v": Key.v.rawValue,
    "b": Key.b.rawValue,
    "n": Key.n.rawValue,
    "m": Key.m.rawValue,
    ",": Key.comma.rawValue,
    ".": Key.dot.rawValue,
    "/": Key.slash.rawValue,

    "q": Key.q.rawValue,
    "w": Key.w.rawValue,
    "e": Key.e.rawValue,
    "r": Key.r.rawValue,
    "t": Key.t.rawValue,
    "y": Key.y.rawValue,
    "u": Key.u.rawValue,
    "i": Key.i.rawValue,
    "o": Key.o.rawValue,
    "p": Key.p.rawValue,

    "1": Key.one.rawValue,
    "2": Key.two.rawValue,
    "3": Key.three.rawValue,
    "4": Key.four.rawValue,
    "5": Key.five.rawValue,
    "6": Key.six.rawValue,
    "7": Key.seven.rawValue,
    "8": Key.eight.rawValue,
    "9": Key.nine.rawValue,
    "0": Key.zero.rawValue,
    "-": Key.minus.rawValue,
    "=": Key.equals.rawValue,

    "[": Key.leftBracket.rawValue,
    "]": Key.rightBracket.rawValue,
    "\\": Key.backslash.rawValue,
    "`": Key.backTick.rawValue,

    "<Left>": Key.left.rawValue,
    "<Right>": Key.right.rawValue,
    "<Down>": Key.down.rawValue,
    "<Up>": Key.up.rawValue,
    "<Space>": Key.space.rawValue,
    "<Caps>": Key.caps.rawValue,
    "<Tab>": Key.tab.rawValue,
    "<BS>": Key.backspace.rawValue,
    "<Esc>": Key.esc.rawValue,
    "<CR>": Key.enter.rawValue,

    "<Fn>": Modifier.fn.rawValue,
    "<S>": Modifier.shift.rawValue,
    "<C>": Modifier.control.rawValue,
    "<M>": Modifier.option.rawValue,
    "<D>": Modifier.command.rawValue,
  ]

  private static let valueToMapping: [Int64: String] = Dictionary(
    uniqueKeysWithValues: mappingToValue.map { key, val in (val, key) }
  )
}

enum Modifier: Int64, CaseIterable, Comparable {
  case shift = 56
  case control = 59
  case option = 58
  case command = 55
  case fn = 63

  var cgEventFlag: CGEventFlags {
    switch self {
    case .shift:
      return .maskShift
    case .control:
      return .maskControl
    case .command:
      return .maskCommand
    case .option:
      return .maskAlternate
    case .fn:
      return .maskSecondaryFn
    }
  }

  static func < (lhs: Modifier, rhs: Modifier) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}

enum Key: Int64 {
  case a = 0
  case s = 1
  case d = 2
  case f = 3
  case g = 5
  case h = 4
  case j = 38
  case k = 40
  case l = 37
  case semicolon = 41
  case quote = 39
  case z = 6
  case x = 7
  case c = 8
  case v = 9
  case b = 11
  case n = 45
  case m = 46
  case comma = 43
  case dot = 47
  case slash = 44
  case space = 49
  case q = 12
  case w = 13
  case e = 14
  case r = 15
  case t = 17
  case y = 16
  case u = 32
  case i = 34
  case o = 31
  case p = 35
  case one = 18
  case two = 19
  case three = 20
  case four = 21
  case five = 23
  case six = 22
  case seven = 26
  case eight = 28
  case nine = 25
  case zero = 29
  case minus = 27
  case equals = 24
  case leftBracket = 33
  case rightBracket = 30
  case backslash = 42
  case backTick = 50

  case caps = 57
  case tab = 48
  case esc = 53
  case backspace = 51
  case left = 123
  case right = 124
  case down = 125
  case up = 126
  case enter = 36
}
