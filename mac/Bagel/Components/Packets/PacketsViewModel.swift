//
//  PacketViewModel.swift
//  Bagel
//
//  Created by Yagiz Gurgul on 1.10.2018.
//  Copyright © 2018 Yagiz Lab. All rights reserved.
//

import Cocoa

class PacketsViewModel: BaseListViewModel<BagelPacket>  {
    
    var addressFilterTerm = "" {
        didSet {
            self.refreshItems()
        }
    }
    
    var methodFilterTerm = "" {
        didSet {
            self.refreshItems()
        }
    }
    
    var statusFilterTerm = "" {
        didSet {
            self.refreshItems()
        }
    }
    
    private var allPackets: [BagelPacket] {
        return BagelController.shared.selectedProjectController?.selectedDeviceController?.packets ?? []
    }
    
    
    func register() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshItems), name: BagelNotifications.didGetPacket, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshItems), name: BagelNotifications.didUpdatePacket, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshItems), name: BagelNotifications.didSelectProject, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshItems), name: BagelNotifications.didSelectDevice, object: nil)
    }
    
    var selectedItem: BagelPacket? {
        return BagelController.shared.selectedProjectController?.selectedDeviceController?.selectedPacket
    }
    
    var selectedItemIndex: Int? {
        guard let selectedItem = self.selectedItem else { return nil }
        
        return self.items.firstIndex { $0 === selectedItem }
    }
    
    @objc func refreshItems() {
        items = filter(items: allPackets)
        onChange?()
    }
    
    func filter(items: [BagelPacket]) -> [BagelPacket] {
        var filteredItems = performAddressFiltration(items)
        filteredItems = performMethodFiltration(filteredItems)
        return performStatusFiltration(filteredItems)
    }
    
    func performAddressFiltration(_ items: [BagelPacket])  -> [BagelPacket] {
        guard addressFilterTerm.count > 0 else {
            return items
        }
        
        return items.filter {
            $0.requestInfo?.url?.contains(self.addressFilterTerm) ?? true }
    }
    
    func performMethodFiltration(_ items: [BagelPacket])  -> [BagelPacket] {
        guard methodFilterTerm.count > 0 else {
            return items
        }
        
        return items.filter
            { $0.requestInfo?.requestMethod?.rawValue.lowercased()
                .contains(self.methodFilterTerm.lowercased()) ?? true }
    }
    
    func performStatusFiltration(_ items: [BagelPacket])  -> [BagelPacket] {
        guard statusFilterTerm.count > 0 else {
            return items
        }
        
        guard !statusFilterTerm.trimmingCharacters(in: .whitespaces).isEmpty else {
            return items.filter { $0.requestInfo?.statusCode?.trimmingCharacters(in: .whitespaces).isEmpty ?? true}
        }
        
        return items.filter
            { $0.requestInfo?.statusCode?.contains(self.statusFilterTerm) ?? false
        }
    }
    
    func clearPackets() {
        BagelController.shared.selectedProjectController?.selectedDeviceController?.clear()
        self.refreshItems()
    }
    
    func saveLocallyOn(_ url: URL?) {
        var plistDict: [String: String] = [:]
        
        guard let url = url else {
            return
        }
        let packets = items
        do {
            try packets.forEach({ (packet) in
                let rawFileName = makeUrlMatch(packet.requestInfo?.url ?? "")
                let responseFileName = makeFileName(rawFileName)
                
                // Adding to the mapping plist
                plistDict[rawFileName] = responseFileName
                
                // Creating the json
                let fullPath = url.appendingPathComponent(responseFileName).path
                if let data = packet.requestInfo?.responseData?.base64Data {
                    let dataRepresentation = DataRepresentationParser.parse(data: data)
                    
                    if let json = dataRepresentation as? DataJSONRepresentation {
                        let stringData = String(data: json.originalData!, encoding: .utf8)
                        try stringData?.write(toFile: fullPath,
                                              atomically: true,
                                              encoding: .utf8)
                    } else {
                        print("[not json] \(rawFileName)")
                    }
                }
            })
        } catch {
            print("[error] \(error)")
        }
        
        // Creating the .plist
        let plistFullPath = url.appendingPathComponent("mapping.plist").path
        NSDictionary(dictionary: plistDict).write(toFile: plistFullPath,
                                                  atomically: true)
    }
    
    private func makeFileName(_ url: String) -> String {
        return url
            .replacingOccurrences(of: "%", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_") + ".json"
    }
    
    private func makeUrlMatch(_ url: String) -> String {
        return url
            .replacingOccurrences(of: "?", with: "[?]") + "$"
    }
}
