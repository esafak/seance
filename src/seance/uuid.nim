import std/[sysrand, strutils, times]

type
  UUID* = distinct array[16, byte]

proc `$`*(uuid: UUID): string =
  let bytes = array[16, byte](uuid)
  result = newString(36)
  var pos = 0

  template addGroup(start, size: int) =
    for i in start ..< (start + size):
      result[pos .. pos + 1] = toLowerAscii(toHex(bytes[i], 2))
      pos += 2
    if pos < 36:
      result[pos] = '-'
      inc pos

  addGroup(0, 4)
  addGroup(4, 2)
  addGroup(6, 2)
  addGroup(8, 2)
  addGroup(10, 6)

proc uuidv7*(): UUID =
  var arr: array[16, byte]
  if not urandom(arr):
    raise newException(IOError, "Failed to generate random bytes for UUID")

  let timestamp = epochTime().uint64 * 1000
  arr[0] = (timestamp shr 40).byte and 0xFF
  arr[1] = (timestamp shr 32).byte and 0xFF
  arr[2] = (timestamp shr 24).byte and 0xFF
  arr[3] = (timestamp shr 16).byte and 0xFF
  arr[4] = (timestamp shr 8).byte and 0xFF
  arr[5] = timestamp.byte and 0xFF

  arr[6] = (arr[6] and 0x0F) or 0x70
  arr[8] = (arr[8] and 0x3F) or 0x80

  result = UUID(arr)

proc `[]`*(u: UUID, i: int): byte =
  array[16, byte](u)[i]

proc `[]=`*(u: var UUID, i: int, val: byte) =
  var arr = array[16, byte](u)
  arr[i] = val
  u = UUID(arr)
