//
//  NCMDumpError.swift
//  NCMDecode
//
//  Created by 龚杰洪 on 2021/3/24.
//

import Foundation

enum NCMDumpError: Error {
    case readFileToStreamFailed
    case notNCMFormat
    case canNotSeekFile
    case canNotReadKeyLength
    case canNotReadKey
    case canNotReadMetaLength
    case metaInfoBase64DecodeFailed
    case canNotReadAlbumImageLength
    case outputFileStreamInvalid
}
