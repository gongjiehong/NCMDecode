//
//  LGAESEncryptor.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/20.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation
import CommonCrypto


/// 加密器出现的错误处理
///
/// - invalidKey: 加密key无效
/// - invalidInitializationVector: IV无效
/// - invalidInputData: 需要被加密的data无效
/// - invalidOutputData: 输出的数据无效
/// - failedWith: 处理过程失败，并携带错误码，错误码定义如下
public enum LGEncryptorError: Error {
    case invalidKey
    case invalidInitializationVector
    case invalidInputData
    case invalidOutputData
    case failedWith(code: Int32)
    /*
     enum {
     kCCSuccess          = 0,
     kCCParamError       = -4300,
     kCCBufferTooSmall   = -4301,
     kCCMemoryFailure    = -4302,
     kCCAlignmentError   = -4303,
     kCCDecodeError      = -4304,
     kCCUnimplemented    = -4305,
     kCCOverflow         = -4306,
     kCCRNGFailure       = -4307,
     kCCUnspecifiedError = -4308,
     kCCCallSequenceError= -4309,
     kCCKeySizeError     = -4310,
     };
     typedef int32_t CCCryptorStatus;
     */
}

/// 加密算法枚举，并处理各自情况下的一些属性
///
/// - des: 标准DES，64位秘钥
/// - des40: DES, 40位秘钥
/// - tripledes: 3DES, 192位秘钥
/// - rc4_40: 40位秘钥
/// - rc4_128: 128位秘钥
/// - rc2_40: 40位秘钥
/// - rc2_128: 128位秘钥
/// - aes_128: 128位秘钥
/// - aes_256: 256位秘钥
public enum LGEncryptorAlgorithm {
    case des
    case des40
    case tripledes
    case rc4_40
    case rc4_128
    case rc2_40
    case rc2_128
    case aes_128
    case aes_256
    
    /// 将当前枚举处理为CCAlgorithm
    public var ccAlgorithm: CCAlgorithm {
        switch self {
        case .des, .des40:
            return CCAlgorithm(kCCAlgorithmDES)
        case .tripledes:
            return CCAlgorithm(kCCAlgorithm3DES)
        case .rc4_40, .rc4_128:
            return CCAlgorithm(kCCAlgorithmRC4)
        case .rc2_40, .rc2_128:
            return CCAlgorithm(kCCAlgorithmRC2)
        case .aes_128, .aes_256:
            return CCAlgorithm(kCCAlgorithmAES)
        }
    }
    
    /// 所需秘钥长度
    public var keySize: Int {
        switch self {
        case .des:
            return kCCKeySizeDES
        case .des40:
            return 5 // 5 * 8 bits
        case .tripledes:
            return kCCKeySize3DES // 24
        case .rc4_40:
            return 5 // 5 * 8 bits
        case .rc4_128:
            return 16 // 16 * 8 bits
        case .rc2_40:
            return 5// 5 * 8 bits
        case .rc2_128:
            return kCCKeySizeMaxRC2 // 128
        case .aes_128:
            return kCCKeySizeAES128 // 16
        case .aes_256:
            return kCCKeySizeAES256 // 32
        }
    }
    
    /// 对应的加密块大小
    public var blockSize: Int {
        switch (self) {
        case .des, .des40:
            return kCCBlockSizeDES
        case .tripledes:
            return kCCBlockSize3DES
        case .rc4_40, .rc4_128:
            return 0
        case .rc2_40, .rc2_128:
            return kCCBlockSizeRC2
        case .aes_128, .aes_256:
            return kCCBlockSizeAES128
        }
    }
    
    /// 获取IV长度，ECB模式下不需要IV，直接处理为0
    ///
    /// - Parameter options: CCOptions
    /// - Returns: IV长度（Int）
    public func ivSize(with options: CCOptions) -> Int {
        // ECB 模式下无需IV
        if options & CCOptions(kCCOptionECBMode) != 0 {
            return 0
        }
        switch (self) {
        case .des, .des40:
            return kCCBlockSizeDES
        case .tripledes:
            return kCCBlockSize3DES
        case .rc4_40, .rc4_128:
            return 0
        case .rc2_40, .rc2_128:
            return kCCBlockSizeRC2
        case .aes_128, .aes_256:
            return kCCBlockSizeAES128
        }
    }
}

/// 加密器
public class LGEncryptor {
    
    /// 算法
    fileprivate var algorithm: LGEncryptorAlgorithm
    
    /// 填充模式
    fileprivate var padding: Int
    
    /// block mode
    fileprivate var blockMode: Int
    
    /// IV
    fileprivate var iv: Data?
    
    /// 初始化
    ///
    /// - Parameters:
    ///   - algorithm: 算法，默认aes_128
    ///   - options: 填充模式，默认PKCS7
    ///   - blockMode: blockMode，默认ECB
    ///   - iv: IV，默认nil
    ///   - ivEncoding: IV编码，默认UTF8
    public init(algorithm: LGEncryptorAlgorithm = LGEncryptorAlgorithm.aes_128,
                padding: Int = ccPKCS7Padding,
                blockMode: Int = kCCModeCBC,
                iv: String? = nil,
                ivEncoding: String.Encoding = String.Encoding.utf8)
    {
        self.algorithm = algorithm
        self.padding = padding
        self.blockMode = blockMode
        self.iv = iv?.data(using: ivEncoding, allowLossyConversion: false)
    }
    
    /// 通过需要被加密的字符和key进行加密
    ///
    /// - Parameters:
    ///   - string: 需要被加密的字符串
    ///   - key: 加密key
    /// - Returns: 加密后的data
    /// - Throws: 整个生命周期中的异常
    public func crypt(string: String, key: String) throws -> Data {
        guard let data = string.data(using: String.Encoding.utf8) else {
            throw LGEncryptorError.invalidInputData
        }
        return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCEncrypt))
    }
    
    
    /// 通过需要被加密的Data和key进行加密
    ///
    /// - Parameters:
    ///   - data: 需要被加密的data
    ///   - key: 加密key
    /// - Returns: 加密后的data
    /// - Throws: 整个生命周期中的异常
    public func crypt(data: Data, key: String) throws -> Data {
        return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCEncrypt))
    }
    
    /// 通过key解密需要被解密的Data
    ///
    /// - Parameters:
    ///   - data: 需要被解密的Data
    ///   - key: 解密Key
    /// - Returns: 解密后的Data
    /// - Throws: 整个生命周期中的异常
    public func decrypt(_ data: Data, key: String) throws -> Data  {
        return try self.cryptoOperation(data, key: key, operation: CCOperation(kCCDecrypt))
    }
    
    /// 内部执行加密解密操作
    ///
    /// - Parameters:
    ///   - inputData: 需要被加密或解密的Data
    ///   - key: 加密或解密Key
    ///   - operation: 控制加密或解密，kCCEncrypt & kCCDecrypt
    /// - Returns: 加密或解密的结果
    /// - Throws: 整个过程中出现的错误
    fileprivate func cryptoOperation(_ inputData: Data,
                                     key: String,
                                     operation: CCOperation) throws -> Data {
        // 除ECB模式外均需要IV
        if iv == nil && (self.padding & kCCOptionECBMode != 0) {
            throw(LGEncryptorError.invalidInitializationVector)
        }
        
        // key长度是否合法
        if key.count != self.algorithm.keySize {
            throw(LGEncryptorError.invalidKey)
        }
        
        // 组装KeyData和buffer
        guard let keyData = key.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            throw(LGEncryptorError.invalidKey)
        }
        
        let keyBytes = keyData.withUnsafeBytes { (bytes) in
            return bytes.baseAddress?.assumingMemoryBound(to:  UInt8.self)
        }
        
        
        let keyLength = algorithm.keySize
        
        // 需要被加密的相关信息组装
        let dataLength = inputData.count
        let dataBytes = inputData.withUnsafeBytes { (bytes) in
            return bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
        }
        // 输出buffer组装
        var outputBufferData = Data(count: dataLength + algorithm.blockSize)
        let outputBufferPointer = outputBufferData.withUnsafeMutableBytes { (bytes) in
            return bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
        }
        
        var resultBuffer = Data()
        
        // 组装IV
        var ivBuffer: UnsafePointer<UInt8>?
        if let iv = iv {
            ivBuffer = iv.withUnsafeBytes { (bytes) in
                return bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            }
        }

        var bytesDecrypted: Int = 0
        
        /// 创建加解密工具
        var cryptorRef: CCCryptorRef? = nil
        var cryptStatus = CCCryptorCreateWithMode(operation,
                                                  CCMode(self.blockMode),
                                                  self.algorithm.ccAlgorithm,
                                                  CCPadding(self.padding),
                                                  ivBuffer,
                                                  keyBytes,
                                                  keyLength,
                                                  nil,
                                                  0,
                                                  0,
                                                  CCModeOptions(),
                                                  &cryptorRef)
        
        guard cryptorRef != nil && kCCSuccess == cryptStatus else {
            throw(LGEncryptorError.failedWith(code: cryptStatus))
        }
        
        // 获取输出buffer大小 结果等于dataLength + blockSize
        let outputLength = CCCryptorGetOutputLength(cryptorRef, dataLength, true)
        
        cryptStatus = CCCryptorUpdate(cryptorRef,
                                      dataBytes,
                                      dataLength,
                                      outputBufferPointer,
                                      outputLength,
                                      &bytesDecrypted)
        
        guard cryptorRef != nil && kCCSuccess == cryptStatus else {
            throw(LGEncryptorError.failedWith(code: cryptStatus))
        }
        
        // 加入第一部分结果
        resultBuffer.append(outputBufferData.subdata(in: 0..<bytesDecrypted))
        
        cryptStatus = CCCryptorFinal(cryptorRef,
                                     outputBufferPointer,
                                     outputLength,
                                     &bytesDecrypted)
        
        // 加入最终结果
        resultBuffer.append(outputBufferData.subdata(in: 0..<bytesDecrypted))
        
        // 手动释放
        CCCryptorRelease(cryptorRef)
        
        
        
        if kCCSuccess == cryptStatus {
            guard bytesDecrypted >= 0 else {
                throw LGEncryptorError.invalidOutputData
            }
            return resultBuffer
        } else {
            throw(LGEncryptorError.failedWith(code: cryptStatus))
        }
    }
}
