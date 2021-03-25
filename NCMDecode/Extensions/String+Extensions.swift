//
//  LGXOREncryptHelper.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/1/5.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation
import CommonCrypto


extension String {
    
    /// 返回当前String的MD5值
    ///
    /// - Returns: 当前String的MD5或nil
    public func md5Hash() -> String? {
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        
        return data.md5Hash()
    }
    
    /// 返回当前String的SHA1值
    ///
    /// - Returns: 当前String的SHA1或nil
    public func sha1() -> String? {
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        
        return data.sha1()
    }
    
    /// 当前String的长度，Swift4以后新换为count
    public var length: Int {
        return self.count
    }
    
    // MARK: -  String 操作
    
    /// 截取第i个字符
    ///
    /// - Parameter i: String
    public subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }
    
    /// 从fromIndex处开始截取字符串
    ///
    /// - Parameter fromIndex: 开始下标
    /// - Returns: String
    public func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    
    /// 从开头截取到第toIndex个字符
    ///
    /// - Parameter toIndex: 结束下标
    /// - Returns: String
    public func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    
    /// 通过range截取字符串
    ///
    /// - Parameter r: String
    public subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    

    // MARK: -  异或加密
    
    /// 将当前String异或加密
    ///
    /// - Parameter key: 加密的Key
    /// - Returns: String
    public func XOREncrypt(withKey key: String) -> String {
        guard let realKey = key.md5Hash() else {
            return ""
        }
        
        // 需要加密的字符串长度
        let dataLen = self.utf8.count
        
        // 加密key长度
        let keyLen = realKey.utf8.count
        
        var resultBuffer = String()
        var j: Int = 0
        var nt: Unicode.UTF8.CodeUnit
        var d: Unicode.UTF8.CodeUnit
        var k: Unicode.UTF8.CodeUnit
        for i in 0..<dataLen {
            d = self.utf8[self.utf8.index(self.utf8.startIndex, offsetBy: i)]
            k = realKey.utf8[realKey.utf8.index(realKey.utf8.startIndex, offsetBy: j)]
            nt = d ^ k
            resultBuffer.append(Character(UnicodeScalar(nt)))

            j += 1
            if j >= keyLen {
                j = 0
            }
        }
        return resultBuffer//String(bytes: resultBuffer, encoding: String.Encoding.utf8) ?? ""
    }
    
    // MARK: -  base64 data
    
    /// 将当前字符串base64加密
    ///
    /// - Returns: base64 Data
    public func base64EncodedData() -> Data? {
        let data = self.data(using: String.Encoding.utf8)
        return data?.base64EncodedData(options: Data.Base64EncodingOptions.endLineWithLineFeed)
    }
 
    public func lg_validateNumber() -> Bool {
        let  number = "^[0-9]+$"
        let numberPre = NSPredicate(format: "SELF MATCHES %@", number)
        return numberPre.evaluate(with: self)
    }
}


