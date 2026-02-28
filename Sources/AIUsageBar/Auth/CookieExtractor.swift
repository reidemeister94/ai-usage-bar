import Foundation
import SQLite3
import Security

// CommonCrypto constants
private let kCCSuccess: Int32 = 0
private let kCCDecrypt: UInt32 = 1
private let kCCAlgorithmAES128: UInt32 = 0
private let kCCOptionPKCS7Padding: UInt32 = 1
private let kCCKeySizeAES128 = 16
private let kCCBlockSizeAES128 = 16
private let kCCPBKDF2: UInt32 = 2
private let kCCPRFHmacAlgSHA1: UInt32 = 1

// CommonCrypto function bridges
@_silgen_name("CCKeyDerivationPBKDF")
private func _CCKeyDerivationPBKDF(
    _ algorithm: UInt32,
    _ password: UnsafePointer<Int8>?,
    _ passwordLen: Int,
    _ salt: UnsafePointer<UInt8>?,
    _ saltLen: Int,
    _ prf: UInt32,
    _ rounds: UInt32,
    _ derivedKey: UnsafeMutablePointer<UInt8>?,
    _ derivedKeyLen: Int
) -> Int32

@_silgen_name("CCCrypt")
private func _CCCrypt(
    _ op: UInt32,
    _ alg: UInt32,
    _ options: UInt32,
    _ key: UnsafeRawPointer?,
    _ keyLength: Int,
    _ iv: UnsafeRawPointer?,
    _ dataIn: UnsafeRawPointer?,
    _ dataInLength: Int,
    _ dataOut: UnsafeMutableRawPointer?,
    _ dataOutAvailable: Int,
    _ dataOutMoved: UnsafeMutablePointer<Int>
) -> Int32

enum CookieExtractor {
    static func extractSessionKey(source: CookieSource = .automatic) -> String? {
        switch source {
        case .automatic:
            return extractFromChrome() ?? extractFromSafari()
        case .chrome:
            return extractFromChrome()
        case .safari:
            return extractFromSafari()
        }
    }

    // MARK: - Chrome

    private static func extractFromChrome() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cookiePath = home
            .appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")
            .path

        guard FileManager.default.fileExists(atPath: cookiePath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(cookiePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = "SELECT encrypted_value, value FROM cookies WHERE host_key LIKE '%claude.ai' AND name = 'sessionKey' LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        // Try plaintext value first
        if let plaintext = sqlite3_column_text(stmt, 1) {
            let value = String(cString: plaintext)
            if value.hasPrefix("sk-ant-") { return value }
        }

        // Try decrypting encrypted_value
        let blobLen = sqlite3_column_bytes(stmt, 0)
        guard blobLen > 0, let blobPtr = sqlite3_column_blob(stmt, 0) else { return nil }
        let encryptedData = Data(bytes: blobPtr, count: Int(blobLen))

        return decryptChromeCookie(encryptedData)
    }

    private static func decryptChromeCookie(_ data: Data) -> String? {
        guard data.count > 3 else { return nil }
        let prefix = String(data: data[0..<3], encoding: .utf8)
        guard prefix == "v10" else { return nil }

        guard let key = getChromeEncryptionKey() else { return nil }

        guard let aesKey = pbkdf2(password: key, salt: "saltysalt", iterations: 1003, keyLength: 16) else {
            return nil
        }

        let iv = Data(repeating: 0x20, count: 16)
        let encrypted = data[3...]

        guard let decrypted = aes128CBCDecrypt(data: Data(encrypted), key: aesKey, iv: iv) else {
            return nil
        }

        let value = String(data: decrypted, encoding: .utf8) ?? ""
        return value.hasPrefix("sk-ant-") ? value : nil
    }

    private static func getChromeEncryptionKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Chrome Safe Storage",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func pbkdf2(password: String, salt: String, iterations: Int, keyLength: Int) -> Data? {
        guard let passwordData = password.data(using: .utf8),
              let saltData = salt.data(using: .utf8) else { return nil }

        var derivedKey = Data(count: keyLength)
        let result = derivedKey.withUnsafeMutableBytes { derivedBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    _CCKeyDerivationPBKDF(
                        kCCPBKDF2,
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        kCCPRFHmacAlgSHA1,
                        UInt32(iterations),
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        return result == kCCSuccess ? derivedKey : nil
    }

    private static func aes128CBCDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0

        let status = buffer.withUnsafeMutableBytes { bufferBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        _CCCrypt(
                            kCCDecrypt,
                            kCCAlgorithmAES128,
                            kCCOptionPKCS7Padding,
                            keyBytes.baseAddress, kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            bufferBytes.baseAddress, bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytesDecrypted)
    }

    // MARK: - Safari

    private static func extractFromSafari() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent("Library/Cookies/Cookies.binarycookies"),
            home.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"),
        ]

        for path in paths {
            if let key = parseSafariBinaryCookies(at: path.path) {
                return key
            }
        }
        return nil
    }

    private static func parseSafariBinaryCookies(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard data.count > 4 else { return nil }

        let magic = String(data: data[0..<4], encoding: .ascii)
        guard magic == "cook" else { return nil }

        // Search for sk-ant-sid pattern in raw binary data
        guard let content = String(data: data, encoding: .ascii) else { return nil }
        let pattern = "sk-ant-sid[a-zA-Z0-9_-]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, range: range) {
            let matchRange = Range(match.range, in: content)!
            return String(content[matchRange])
        }
        return nil
    }
}
