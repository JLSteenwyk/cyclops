#!/usr/bin/env swift

import CryptoKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("usage: sparkle-public-key.swift <private-key-file>\n".utf8))
  exit(64)
}

let privateKeyURL = URL(fileURLWithPath: CommandLine.arguments[1])
let encodedSeed = try String(contentsOf: privateKeyURL, encoding: .utf8)
  .trimmingCharacters(in: .whitespacesAndNewlines)
guard let seed = Data(base64Encoded: encodedSeed) else {
  FileHandle.standardError.write(Data("Sparkle private key is not valid base64\n".utf8))
  exit(65)
}

let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
print(privateKey.publicKey.rawRepresentation.base64EncodedString())
