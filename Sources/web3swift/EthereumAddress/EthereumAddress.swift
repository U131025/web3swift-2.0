//
//  EthereumAddress.swift
//  EthereumAddress
//
//  Created by Alex Vlasov on 25/10/2018.
//  Copyright © 2018 Alex Vlasov. All rights reserved.
//

import Foundation
import CryptoSwift

public enum CreateWalletType {
    case htdf
    case usdp
    case eth
    case het
    case bit
    case bch
    case ltc
    case dash
    case bsv
    case xrp
    case trx
}

public class Bech32: NSObject {
    
    static let CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    static let CHARSET_REV: [Int] = [
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        15, -1, 10, 17, 21, 20, 26, 30,  7,  5, -1, -1, -1, -1, -1, -1,
        -1, 29, -1, 24, 13, 25,  9,  8, 23, -1, 18, 22, 31, 27, 19, -1,
        1,  0,  3, 16, 11, 28, 12, 14,  6,  4,  2, -1, -1, -1, -1, -1,
        -1, 29, -1, 24, 13, 25,  9,  8, 23, -1, 18, 22, 31, 27, 19, -1,
        1,  0,  3, 16, 11, 28, 12, 14,  6,  4,  2, -1, -1, -1, -1, -1
    ]
    
    var generator: [Int] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    
    private func bech32Checksum(hrp: String, data: Data) -> Data {
        var integers = [Int]()
        for i in 0..<data.count {
            integers.append(Int(data[i]))
        }
        var values = [Int]()
        values += bech32HrpExpand(hrp: hrp)
        values += integers
        values += [0, 0, 0, 0, 0, 0]
        
        let polymod = bech32Polymod(values: values) ^ 1
        var res = Data()
        for index in 0..<6 {
            res.append(contentsOf: [UInt8( (polymod >> uint(5*(5 - index))) & 31  )])
        }
        return res
    }
    
    private func bech32HrpExpand(hrp: String) -> [Int] {
        var ret = [Int]()
        for index in 0..<hrp.count {
            ret.append(Int(hrp.bytes[index] >> 5))
        }
        ret.append(0)
        for index in 0..<hrp.count {
            ret.append(Int(hrp.bytes[index] & 31))
        }
        return ret
    }
    
    private func bech32Polymod(values: [Int]) -> Int {
        var chk = 1
        
        for index in 0..<values.count {
            let top = chk >> 25
            chk = ((chk & 0x1ffffff) << 5) ^ values[index]
            for i in 0..<5 {
                if (top>>uint(i))&1 == 1 {
                    chk ^= generator[i]
                }
            }
        }
        
        return chk
    }
    
    private func toChars(data: Data) -> String {
        var resultString = ""
        
        for index in 0..<data.count {
            let charterIndex = Int(data[index])
            resultString.append(Character(UnicodeScalar(Bech32.CHARSET.bytes[charterIndex])))
        }
        
        return resultString
    }
    
    public func covertBits(data: Data, fromBits: UInt8, toBits: UInt8, pad: Bool) -> Data {
        var filledBits = UInt8(0)
        var regrouped = Data()
        var nextByte: UInt8 = 0
        
        //var i = 0
        for index in 0..<data.count {
            
            var b = data[index] << (8 - fromBits)
            
            var remFromBits = fromBits
            
            
            while remFromBits > 0 {
                //i += 1
                // print("23124124342rasfsf: b: \(i)")
                let remToBits = toBits - filledBits
                
                var toExtract = remFromBits
                if remToBits < toExtract {
                    toExtract = remToBits
                }
                
                nextByte = (nextByte << toExtract) | (b >> (8 - toExtract))
                
                b = b << toExtract
                remFromBits -= toExtract
                filledBits += toExtract
                
                if filledBits == toBits {
                    regrouped.append(nextByte)
                    filledBits = 0
                    nextByte = 0
                }
            }
        }
        
        if pad && filledBits > 0 {
            nextByte = nextByte << (toBits - filledBits)
            regrouped.append(nextByte)
            filledBits = 0
            nextByte = 0
        }
        
        if filledBits > 0 && (filledBits > 4 || nextByte != 0) {
            fatalError()
        }
        
        return regrouped
    }
    
    func verifyChecksum(hrp: String, data: [Int]) -> Bool {
        let hrpExpand = bech32HrpExpand(hrp: hrp)
        return bech32Polymod(values: hrpExpand + data) == 1
    }
    
    public func encode(hrp: String, data: Data) -> String {
        let checksum = bech32Checksum(hrp: hrp, data: data)
        let combined = data + checksum
        return hrp + "1" + toChars(data: combined )
    }
    
    public func decode(bechString: String) -> (String, [Int])? {
        var result = ("", [Int]())
        
        var bech = bechString
        guard !(bechString.count < 8 || bechString.count > 90) else {
            return nil
        }
        
        for index in 0..<bechString.count {
            if bechString.bytes[index] < 33 || bechString.bytes[index] > 126 {
                return nil
            }
        }
        
        let lowerStr = bechString.lowercased()
        let upperStr = bechString.uppercased()
        
        if bechString != lowerStr && bechString != upperStr {
            return nil
        }
        bech = lowerStr
        
        // 字符"1"的 assic码 49
        guard let pos = bech.bytes.firstIndex(of: 49) else {
            return nil
        }
        
        if pos < 1 || (pos + 7) > bech.count {
            return nil
        }
        //hrp
        result.0 = (bech as NSString).substring(with: NSRange.init(location: 0, length: pos))
        
        for index in 0..<result.0.count {
            if result.0.bytes[index] < 33 || result.0.bytes[index] > 126 {
                return nil
            }
        }
        
        var bechCheck = [Int]()
        for p in pos + 1..<bech.count {
            guard let d = Bech32.CHARSET.bytes.firstIndex(of: bech.bytes[p]), d >= 0 else {
                return nil
            }
            bechCheck.append(d)
        }
        result.1 = bechCheck
        if !verifyChecksum(hrp: result.0, data: result.1) {
            return nil
        }
        
        return result
    }
}

public struct EthereumAddress: Equatable {
    public enum AddressType {
        case normal
        case contractDeployment
    }
    
    public var isValid: Bool {
        get {
            switch self.type {
            case .normal:
                return (self.addressData.count == 20)
            case .contractDeployment:
                return true
            }
            
        }
    }
    var _address: String
    public var type: AddressType = .normal
    public static func ==(lhs: EthereumAddress, rhs: EthereumAddress) -> Bool {
        return lhs.addressData == rhs.addressData && lhs.type == rhs.type
        //        return lhs.address.lowercased() == rhs.address.lowercased() && lhs.type == rhs.type
    }
    
    public var addressData: Data {
        get {
            switch self.type {
            case .normal:
                guard let dataArray = Data.fromHex(_address) else {return Data()}
                return dataArray
                //                guard let d = dataArray.setLengthLeft(20) else { return Data()}
            //                return d
            case .contractDeployment:
                return Data()
            }
        }
    }
    public var address:String {
        switch self.type {
        case .normal:
            switch walletType {
            case .usdp:
                return getUSDPAddress()
            case .htdf:
                return  getHTDFAddress()
            case .het:
                return  getHETAddress()
            default:
                return EthereumAddress.toChecksumAddress(_address)!
            }
        case .contractDeployment:
            return "0x"
        }
    }
    
    private func getUSDPAddress() -> String {
        let compressData = SECP256K1.combineSerializedPublicKeys(keys: [addressData], outputCompressed: true)!
        let sourceData = Data(hex: "PubKeySecp256k1") + Data(compressData.bytes)
        
        let data = try! RIPEMD160.hash(message: sourceData.sha256())
        let covertData = Bech32().covertBits(data: data, fromBits: 8, toBits: 5, pad: true)
        return Bech32().encode(hrp: "usdp", data: covertData)
    }
    
    public func getHTDFAddress() -> String {
        let compressData = SECP256K1.combineSerializedPublicKeys(keys: [addressData], outputCompressed: true)!
        let sourceData = Data(hex: "PubKeySecp256k1") + Data(compressData.bytes)
        let data = try! RIPEMD160.hash(message: sourceData.sha256())
        let covertData = Bech32().covertBits(data: data, fromBits: 8, toBits: 5, pad: true)
        return Bech32().encode(hrp: "htdf", data: covertData)
    }
    public func getHETAddress() -> String {
        let compressData = SECP256K1.combineSerializedPublicKeys(keys: [addressData], outputCompressed: true)!
        let sourceData = Data(hex: "PubKeySecp256k1") + Data(compressData.bytes)
        let data = try! RIPEMD160.hash(message: sourceData.sha256())
        let covertData = Bech32().covertBits(data: data, fromBits: 8, toBits: 5, pad: true)
        return Bech32().encode(hrp: "0x", data: covertData)
    }
    
    public static func toChecksumAddress(_ addr:String) -> String? {
        let address = addr.lowercased().stripHexPrefix()
        guard let hash = address.data(using: .ascii)?.sha3(.keccak256).toHexString().stripHexPrefix() else {return nil}
        var ret = "0x"
        
        for (i,char) in address.enumerated() {
            let startIdx = hash.index(hash.startIndex, offsetBy: i)
            let endIdx = hash.index(hash.startIndex, offsetBy: i+1)
            let hashChar = String(hash[startIdx..<endIdx])
            let c = String(char)
            guard let int = Int(hashChar, radix: 16) else {return nil}
            if (int >= 8) {
                ret += c.uppercased()
            } else {
                ret += c
            }
        }
        return ret
    }
    
    var walletType = CreateWalletType.eth
    public init?(addressString:String, type: AddressType = .normal, walletType: CreateWalletType = CreateWalletType.htdf) {
        
        self.init(addressString, type: type)
        self.walletType = walletType
    }
    
    public init?(_ addressString:String, type: AddressType = .normal, ignoreChecksum: Bool = false) {
        switch type {
        case .normal:
            guard let data = Data.fromHex(addressString) else {return nil}
            guard data.count == 20 else {return nil}
            if !addressString.hasHexPrefix() {
                return nil
            }
            if (!ignoreChecksum) {
                // check for checksum
                if data.toHexString() == addressString.stripHexPrefix() {
                    self._address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                } else if data.toHexString().uppercased() == addressString.stripHexPrefix() {
                    self._address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                } else {
                    let checksummedAddress = EthereumAddress.toChecksumAddress(data.toHexString().addHexPrefix())
                    guard checksummedAddress == addressString else {return nil}
                    self._address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                }
            } else {
                self._address = data.toHexString().addHexPrefix()
                self.type = .normal
                return
            }
        case .contractDeployment:
            self._address = "0x"
            self.type = .contractDeployment
        }
    }
    
    public init?(_ addressData:Data, type: AddressType = .normal) {
        guard addressData.count == 20 else {return nil}
        self._address = addressData.toHexString().addHexPrefix()
        self.type = type
    }
    
    public static func contractDeploymentAddress() -> EthereumAddress {
        return EthereumAddress("0x", type: .contractDeployment)!
    }
    
    //    public static func fromIBAN(_ iban: String) -> EthereumAddress {
    //
    //    }
    
}

extension EthereumAddress: Hashable {
    
}




