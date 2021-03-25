//
//  NCMDump.swift
//  NCMDecode
//
//  Created by 龚杰洪 on 2021/3/24.
//

import Foundation
import CommonCrypto
import TagLibWrapper

fileprivate let coreKey: String = "hzHRAmso5kInbaxW"

fileprivate let metaKey: String = "#14ljk_!\\]&0U<'("

/// 用户判断文件是否为PNG格式，由于jpg有好几种，这里就直接判断PNG，剩下全部jpg处理，严格意义上讲，PNG只用判断（0x0D, 0x0A, 0x1A, 0x0A）
fileprivate let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

class NCMDump {
    private var readStream: InputStream!
    private var outputDir: String
    private var originFilePath: String
    
    init(filePath: String, outputDir: String) throws {
        self.originFilePath = filePath
        self.outputDir = outputDir
        let url = URL(fileURLWithPath: filePath)
        guard let stream = InputStream(url: url) else {
            throw NCMDumpError.readFileToStreamFailed
        }
        stream.open()
        self.readStream = stream
        
        if !isNCMFile() {
            throw NCMDumpError.notNCMFormat
        }
    }
    
    func isNCMFile() -> Bool {
        var headerBuffer: [UInt8] = [UInt8](repeating: 0, count: 8)
        let readLength = self.readStream.read(&headerBuffer, maxLength: 8)
        
        // 懒得转整, 直接判断字节是否相等比较省事儿
        if readLength != 8 || headerBuffer != [67, 84, 69, 78, 70, 68, 65, 77] {
            return false
        }
        return true
    }
    
    var keyBox = [UInt8]()
    func buildKeyBox(_ key: [UInt8], length: Int) {
        for index in 0..<256 {
            keyBox.append(UInt8(index))
        }
        
        var swap: UInt8 = 0
        var c: Int = 0
        var lastByte: Int = 0
        var keyOffset: Int = 0
        
        
        for index in 0..<256 {
            swap = keyBox[index]
            c = ((Int(swap) + Int(lastByte) + Int(key[Int(keyOffset)]))) & 255
            keyOffset += 1
            if keyOffset >= length {
                keyOffset = 0
            }
            keyBox[index] = keyBox[c]
            keyBox[c] = swap
            lastByte = c
        }
    }
    
    func convert() throws {
        // 拿走两个无用字节
        var notForUserBuffer: [UInt8] = [UInt8](repeating: 0, count: 2)
        var readLength = self.readStream.read(&notForUserBuffer, maxLength: 2)
        if readLength != 2 {
            throw NCMDumpError.canNotSeekFile
        }
        
        // 读取key长度
        var keyLengthBuffer: [UInt8] = [UInt8](repeating: 0, count: 4)
        readLength = self.readStream.read(&keyLengthBuffer, maxLength: 4)
        if readLength <= 0 {
            throw NCMDumpError.canNotReadKeyLength
        }
        let keyLengthValue = keyLengthBuffer.withUnsafeBufferPointer {
            ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        }.pointee
        
        // 读取和组装key
        let keyLength = Int(keyLengthValue)
        var keyBuffer: [UInt8] = [UInt8](repeating: 0, count: keyLength)
        readLength = self.readStream.read(&keyBuffer, maxLength: keyLength)
        if readLength <= 0 {
            throw NCMDumpError.canNotReadKey
        }
        for (index, value) in keyBuffer.enumerated() {
            keyBuffer[index] = value ^ 0x64
        }
                
        // 构造解密,AES128位ECB模式PKCS7填充，不需要iv
        let encryptor = LGEncryptor(algorithm: LGEncryptorAlgorithm.aes_128,
                                    padding: ccPKCS7Padding,
                                    blockMode: kCCModeECB,
                                    iv: nil,
                                    ivEncoding: String.Encoding.utf8)
        let decrypted = try encryptor.decrypt(Data(keyBuffer), key: coreKey)
        let decryptedBytes = [UInt8](decrypted)
        let subKeyData = [UInt8](decrypted[17...decryptedBytes.count - 1])
        buildKeyBox(subKeyData, length: decryptedBytes.count - 17)
        
        // 读取meta信息长度
        var metaLengthBuffer: [UInt8] = [UInt8](repeating: 0, count: 4)
        readLength = self.readStream.read(&metaLengthBuffer, maxLength: 4)
        if readLength <= 0 {
            throw NCMDumpError.canNotReadMetaLength
        }
        let metaLengthValue = metaLengthBuffer.withUnsafeBufferPointer {
            ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        }.pointee
        
        if metaLengthValue <= 0 {
            print("未读取到meta信息长度，可能无法写入歌曲信息")
        } else {
            // 读取meta信息
            var metaInfoBuffer: [UInt8] = [UInt8](repeating: 0, count: Int(metaLengthValue))
            readLength = self.readStream.read(&metaInfoBuffer, maxLength: Int(metaLengthValue))
            
            for (index, value) in metaInfoBuffer.enumerated() {
                metaInfoBuffer[index] = value ^ 0x63
            }
            
            
            let metaData = Data([UInt8](metaInfoBuffer[22...metaInfoBuffer.count - 1]))
            guard let base64Decode = Data(base64Encoded: metaData) else {
                throw NCMDumpError.metaInfoBase64DecodeFailed
            }
            let decryptedMetaData = try encryptor.decrypt(base64Decode, key: metaKey)
            let metaJsonData = Data(decryptedMetaData[6...decryptedMetaData.count - 1])
            let jsonObj = try JSONSerialization.jsonObject(with: metaJsonData,
                                                           options: JSONSerialization.ReadingOptions.fragmentsAllowed)
            if let dic = jsonObj as? [String: Any] {
                self.metaInfoDictionary = dic
            }
        }
        
        // 跳过读取crc32的过程，懒得做crc校验
        var tempBuffer: [UInt8] = [UInt8](repeating: 0, count: 9)
        readLength = self.readStream.read(&tempBuffer, maxLength: 9)
        if readLength != 9 {
            throw NCMDumpError.canNotSeekFile
        }
        tempBuffer = []
        
        // 读取封面长度
        var albumImageLengthBuffer: [UInt8] = [UInt8](repeating: 0, count: 4)
        readLength = self.readStream.read(&albumImageLengthBuffer, maxLength: 4)
        if readLength <= 0 {
            throw NCMDumpError.canNotReadMetaLength
        }
        let albumImageLength = albumImageLengthBuffer.withUnsafeBufferPointer {
            ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        }.pointee
        
        if albumImageLength > 0 {
            var imageBuffer: [UInt8] = [UInt8](repeating: 0, count: Int(albumImageLength))
            readLength = self.readStream.read(&imageBuffer, maxLength: Int(albumImageLength))
            if readLength <= 0 {
                print("未读取到专辑封面数据，不会写入封面图片")
            }
            metaInfoDictionary["albumImage"] = Data(imageBuffer)
        } else {
            print("未读取到专辑封面数据长度，不会写入封面图片")
        }
        
        // 读取真正的音频数据并写入
        let inputURL = URL(fileURLWithPath: self.originFilePath)
        var outputURL = URL(fileURLWithPath: self.outputDir)
        outputURL.appendPathComponent(inputURL.lastPathComponent)
        outputURL.deletePathExtension()
        if let format = metaInfoDictionary["format"] as? String {
            outputURL.appendPathExtension(format)
        }
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        guard let outputStream = OutputStream(url: outputURL, append: true) else {
            throw NCMDumpError.outputFileStreamInvalid
        }
        outputStream.open()
        defer {
            outputStream.close()
        }
        
        let realMusicBufferSize: Int = 0x8000
        while self.readStream.hasBytesAvailable {
            var buffer: [UInt8] = [UInt8](repeating: 0, count: realMusicBufferSize)
            readLength = self.readStream.read(&buffer, maxLength: realMusicBufferSize)
            if let streamError = readStream.streamError {
                throw streamError
            }
            
            if readLength > 0 {
                for index in 0..<readLength {
                    let temp = (index + 1) & 255
                    buffer[index] ^= keyBox[(Int(keyBox[temp]) + Int(keyBox[(Int(keyBox[temp]) + temp) & 255])) & 255]
                }
                    
                let writeLength = outputStream.write(&buffer, maxLength: readLength)
                if writeLength <= 0 {
                    if let streamError = outputStream.streamError {
                        throw streamError
                    }
                }
            }
        }
        
        self.readStream.close()
        self.buildAndWriteMetaData(outputURL.path)
    }
    
    var metaInfoDictionary: [String: Any] = [String: Any]()
    func buildAndWriteMetaData(_ path: String) {
        let meta = TLAudio(fileAtPath: path)
        if let title = metaInfoDictionary["musicName"] as? String {
            meta?.title = title
        }
        
        if let artistArray = metaInfoDictionary["artist"] as? [String], let artist = artistArray.first {
            meta?.artist = artist
        }
        
        if let album = metaInfoDictionary["album"] as? String {
            meta?.album = album
        }
        
        if let frontCoverPicture = metaInfoDictionary["albumImage"] as? Data {
            meta?.frontCoverPicture = frontCoverPicture
        }
        
        meta?.save()
    }
    
    deinit {
        self.readStream.close()
    }
}
