//
//  Crypto.swift
//  
//
//  Created by Alsey Coleman Miller on 12/7/22.
//

import Foundation
import CryptoSwift

// MARK: - Key

public struct Key {
    
    public let data: Data
    
    internal init<C>(_ data: C) where C: Collection, C.Element == UInt8 {
        self.data = Data(data)
    }
}

public extension Key {
    
    /// Static Key used for login
    static var login: Key { Key([0xFF, 0xB3, 0xB3, 0xBE, 0xAE, 0x97, 0xAD, 0x83, 0xB9, 0x61, 0x0E, 0x23, 0xA4, 0x3C, 0x2E, 0xB0]) }
    
    /// Static ket used for passing command line arguments to client.
    static var commandLine: Key { Key([0xFA, 0xEE, 0x85, 0xF2, 0x40, 0x73, 0xD9, 0x16, 0x13, 0x90, 0x19, 0x7F, 0x6E, 0x56, 0x2A, 0x67]) }
}

public extension Key {
    
    /// Create session key.
    init(username: String, password: String, nonce: Nonce) {
        let plainText = Key.plainText(
            username: username,
            password: password,
            nonce: nonce
        )
        self.data = Crypto.SHA0.process(plainText)
    }
    
    internal static func plainText(username: String, password: String, nonce: Nonce) -> Data {
        var bytes = Data()
        bytes += username.data(using: .ascii) ?? Data()
        bytes += password.data(using: .ascii) ?? Data()
        let nonceBytes = nonce.rawValue.bigEndian.bytes
        bytes += nonceBytes.0
        bytes += nonceBytes.1
        bytes += nonceBytes.2
        bytes += nonceBytes.3
        let bitLength = UInt16(8 * bytes.count)
        bytes += [0x80]
        bytes += [UInt8](repeating: 0x00, count: 62 - bytes.count)
        let lengthBytes = bitLength.bigEndian.bytes
        bytes += [lengthBytes.0, lengthBytes.1]
        return bytes
    }
}

// MARK: - CustomStringConvertible

extension Key: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        data.toHexadecimal()
    }
    
    public var debugDescription: String {
        description
    }
}

// MARK: - Encryption

internal struct Crypto {
    
    enum AES {
        
        static func decrypt(_ data: Data, key: Key) throws -> Data {
            let aes = try CryptoSwift.AES(key: .init(key.data), blockMode: ECB(), padding: .noPadding)
            let decrypted = try aes.decrypt(.init(data))
            return Data(decrypted)
        }
        
        static func decrypt(_ data: Data, key: Key, opcode: Opcode) throws -> Data {
            let checksum = 0x8631607E + UInt32(opcode.rawValue)
            let decrypted = try decrypt(data, key: key)
            var processed = Data()
            var currentBlockCommand: UInt32 = 0
            for i in 0 ..< data.count {
                let internal128BitIndex = i % 16
                if internal128BitIndex < 4 {
                    currentBlockCommand |= UInt32(decrypted[i]) << internal128BitIndex * 8
                    if internal128BitIndex == 3 {
                        if currentBlockCommand != checksum {
                            // command checksum mismatch
                            throw GunBoundError.checksumMismatch(checksum, currentBlockCommand)
                        }
                        currentBlockCommand = 0
                    }
                } else {
                    processed.append(decrypted[i])
                }
            }
            return processed
        }
        
        /*
        func gunboundDynamicEncrypt(plainBytes: [UInt8], username: String, password: String, authToken: String, command: UInt32) -> [UInt8] {
            if plainBytes.count % 12 != 0 {
                print("gunbound_dynamic_encrypt: bytes are not aligned to 12-byte boundary")
                return [0xDE, 0xAD, 0xBE, 0xEF]
            }
            let packetCommand = 0x8631607E + command  // originally command - 0x79CE9F82, but inverted to avoid negative ops
            var packetCommandBytes = [UInt8]()
            packetCommandBytes.append(UInt8((packetCommand >> 0) & 0xFF))
            packetCommandBytes.append(UInt8((packetCommand >> 8) & 0xFF))
            packetCommandBytes.append(UInt8((packetCommand >> 16) & 0xFF))
            packetCommandBytes.append(UInt8((packetCommand >> 24) & 0xFF))
            var processed = [UInt8]()
            for i in 0..<plainBytes.count {
                if i % 12 == 0 {
                    processed.append(contentsOf: packetCommandBytes)
                }
                processed.append(plainBytes[i])
            }
            let encryptedBytes = gunboundDynamicEncryptRaw(processed: processed, username: username, password: password, authToken: authToken)
            return encryptedBytes
        }
        */
    }
    
    enum SHA0 {
        
        static func process(_ block: Data) -> Data {
            /*
             the final hash value is computed by adding the values of the five 32-bit words in the sha_h array to the corresponding words in the sha_h array. The resulting array is then converted into a byte array by converting each 32-bit word into a 4-byte big-endian representation. Finally, the first four bytes are removed from the resulting byte array, and the endianness of each 4-byte block is reversed. This transforms the SHA-0 hash into a "gunbound-sha" hash.
             */
            return Data(compute_gunbound_sha(.init(block)))
        }
        
        static func compute_gunbound_sha(_ chunk: [UInt8]) -> [UInt8] {
            /*
             This implementation first calls the sha0_process_block function to compute the SHA-0 hash of the input chunk. It then adds the values of the five words in the sha_h array to the corresponding words in the sha_h array. The resulting array is converted into a byte array by reversing the endianness of each 4-byte block and appending it to the result array. The first four bytes are not included in the final result array,
             */
            
            // Process the chunk and compute the SHA-0 hash
            let sha_h = sha0_process_block(chunk)
            
            // changes a typical SHA-0 into "gunbound-sha" by removing 4 bytes and swapping the DWORD endian
            var result = [UInt8]()
            for block_index in 0..<4 {
                let bytes = sha_h[block_index].littleEndian.bytes
                result += [bytes.0, bytes.1, bytes.2, bytes.3]
            }

            return result
        }
        
        static func left_rotate(_ n: UInt32, _ b: UInt32) -> UInt32 {
            return ((n << b) | (n >> (32 - b))) & 0xffffffff
        }
        
        static func sha0_process_block(_ chunk: [UInt8]) -> [UInt32] {
                        
            var w = [UInt32]()
            sha0_process_block_0(chunk, w: &w)
            sha0_process_block_1(chunk, w: &w)
            sha0_process_block_2(chunk, w: &w)

            // actually mangle the data
            var sha_h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

            var a = sha_h[0]
            var b = sha_h[1]
            var c = sha_h[2]
            var d = sha_h[3]
            var e = sha_h[4]

            for i: UInt32 in 0 ..< 80 {
                var k: UInt32 = 0
                var f: UInt32 = 0

                if 0 <= i && i <= 19 {
                    // BODY_16_19
                    f = d ^ (b & (c ^ d))
                    k = 0x5A827999
                } else if 20 <= i && i <= 39 {
                    // BODY_20_31, BODY_32_39
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                } else if 40 <= i && i <= 59 {
                    // BODY_40_59
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                } else if 60 <= i && i <= 79 {
                    // BODY_60_79
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }
                
                let tmp = (a: a, b: b, c: c, d: d, e: e)
                var tmpA = UInt64(left_rotate(tmp.a, 5))
                tmpA += UInt64(f)
                tmpA += UInt64(tmp.e)
                tmpA += UInt64(k)
                tmpA += UInt64(w[Int(i)])
                tmpA = tmpA & 0xffffffff
                a = UInt32(tmpA)
                b = tmp.a
                c = left_rotate(tmp.b, 30)
                d = tmp.c
                e = tmp.d
            }
            
            // Add this chunk's hash to result
            sha_h[0] = UInt32( (UInt64(sha_h[0]) + UInt64(a)) & 0xffffffff )
            sha_h[1] = UInt32( (UInt64(sha_h[1]) + UInt64(b)) & 0xffffffff )
            sha_h[2] = UInt32( (UInt64(sha_h[2]) + UInt64(c)) & 0xffffffff )
            sha_h[3] = UInt32( (UInt64(sha_h[3]) + UInt64(d)) & 0xffffffff )
            sha_h[4] = UInt32( (UInt64(sha_h[4]) + UInt64(e)) & 0xffffffff )
            
            return sha_h
        }
        
        static func sha0_process_block_0(
            _ chunk: [UInt8],
            w: inout [UInt32]
        ) {
            // break 64-byte chunk to 16 big-endian DWORDs
            for i in 0..<16 {
                let chunk_byte1 = UInt32(chunk[i * 4 + 3]) << (0 * 8)
                let chunk_byte2 = UInt32(chunk[i * 4 + 2]) << (1 * 8)
                let chunk_byte3 = UInt32(chunk[i * 4 + 1]) << (2 * 8)
                let chunk_byte4 = UInt32(chunk[i * 4 + 0]) << (3 * 8)
                w.append(chunk_byte1 | chunk_byte2 | chunk_byte3 | chunk_byte4)
            }
        }
        
        static func sha0_process_block_1(
            _ chunk: [UInt8],
            w: inout [UInt32]
        ) {
            //w.extend(bytes.fromhex("00" * (80 - 16)))
            w += [UInt32].init(repeating: 0x00, count: (80 - 16))
        }
        
        static func sha0_process_block_2(
            _ chunk: [UInt8],
            w: inout [UInt32]
        ) {
            // expand the 16 DWORDs into 80 DWORDs
            for i in 16..<80 {
                // left rotate 0 for SHA-0, left rotate 1 for SHA-1
                w[i] = left_rotate(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 0)
            }
        }
    }
}
