import unittest
import std/strutils
import std/sequtils

import seance/uuid

suite "UUID v7":
  test "uuidv7 generates valid UUIDs":
    let uuid = uuidv7()
    let str = $uuid
    
    check:
      str.len == 36
      str[8] == '-'
      str[13] == '-'
      str[18] == '-'
      str[23] == '-'
      all(str.replace("-", ""), proc(c: char): bool = c in {'0'..'9', 'a'..'f'})

    # Check version and variant
    check (uuid[6] and 0xF0'u8) == 0x70'u8  # Version 7
    check (uuid[8] and 0xC0'u8) == 0x80'u8  # Variant 1

  test "UUID string formatting matches bytesToHexGroups":
    let testBytes = @[byte 0x01, 0x97, 0xFF, 0x4B, 0xF0, 0x2E, 0x00, 0xF7,
      0x0B, 0xBB, 0x36, 0x64, 0xFD, 0x9E, 0x09, 0x12]
    var arr: array[16, byte]
    for i in 0 ..< 16:
      arr[i] = testBytes[i]
    let uuid = UUID(arr)
    let str = $uuid
    
    check:
      str.len == 36
      str[8] == '-'
      str[13] == '-'
      str[18] == '-'
      str[23] == '-'
      str == "0197ff4b-f02e-00f7-0bbb-3664fd9e0912"

  test "UUID string maintains correct case":
    let testBytes = [byte 0xAB, 0xCD, 0xEF, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    let str = $UUID(testBytes)

    check str.startsWith("abcdef")


  test "multiple uuidv7 calls generate unique UUIDs":
    let uuid1 = uuidv7()
    let uuid2 = uuidv7()
    
    check $uuid1 != $uuid2