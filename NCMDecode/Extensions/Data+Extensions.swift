//
//  Data+Extensions.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/20.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation
import CommonCrypto

extension Data {
    
    /// 返回当前Data的MD5值
    ///
    /// - Returns: 当前Data的MD5或nil
    public func md5Hash() -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var dataCopy = self
        
        let pointer = dataCopy.withUnsafeMutableBytes { dataBytes in
            dataBytes.baseAddress?.assumingMemoryBound(to: UnsafePointer<Data>.self)
        }
        
        var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(pointer, CC_LONG(self.count), &hash)
        
        return (0..<length).map { String(format: "%02x", hash[$0]) }.joined()
    }
    
    /// 返回当前Data的SHA1值
    ///
    /// - Returns: 当前Data的SHA1或nil
    public func sha1() -> String {
        let length = Int(CC_SHA1_DIGEST_LENGTH)
        var dataCopy = self
        
        let pointer = dataCopy.withUnsafeMutableBytes { dataBytes in
            dataBytes.baseAddress?.assumingMemoryBound(to: UnsafePointer<Data>.self)
        }
        
        var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH * 2))
        CC_SHA1(pointer, CC_LONG(self.count), &hash)
        
        return (0..<length).map { String(format: "%02x", hash[$0]) }.joined()
    }
}


