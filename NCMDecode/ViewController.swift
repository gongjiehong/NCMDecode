//
//  ViewController.swift
//  NCMDecode
//
//  Created by 龚杰洪 on 2021/3/24.
//

import Cocoa

enum ConverError: Error {
    case inputSourceInvalid
    case notError
}

class ViewController: NSViewController {
    @IBOutlet weak var openFolderButton: NSButton!
    @IBOutlet weak var inputFilesTable: NSTableView!
    @IBOutlet weak var outputPathButton: NSButton!
    @IBOutlet weak var ouputPathLabel: NSTextField!
    @IBOutlet weak var currentFolderLabel: NSTextField!
    
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var progressView: NSProgressIndicator!
    
    lazy var outputFolderURL: URL = {
        let path = NSHomeDirectory() + "/Music/NCMConvertOutput/"
        let url = URL(fileURLWithPath: path)
        do {
            let filemanager = FileManager.default
            var isDirectory = ObjCBool(false)
            let fileExists = filemanager.fileExists(atPath: path, isDirectory: &isDirectory)
            if fileExists {
                if isDirectory.boolValue {
                    // do nothing
                } else {
                    try filemanager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                }
            } else {
                try filemanager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print(error)
        }
        return url
    }()
    
    var dataSource: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        openFolderButton.target = self
        openFolderButton.action = #selector(openInputFolder(_:))
        
        outputPathButton.target = self
        outputPathButton.action = #selector(openOutputFolder(_:))
        
        startButton.target = self
        startButton.action = #selector(startConvert(_:))
        
        setupTableView()
        
        loadDefaultPath()
        
        ouputPathLabel.stringValue = outputFolderURL.path
    }
    
    func loadDefaultPath() {
        var path = NSHomeDirectory()
        path += "/Music/网易云音乐/"
        let fileManager = FileManager.default
        do {
            let filesPaths = try fileManager.contentsOfDirectory(atPath: path)
            for filePath in filesPaths {
                if filePath.lowercased().hasSuffix(".ncm") {
                    let url = URL(fileURLWithPath: path + filePath)
                    dataSource.append(url)
                }
            }
        } catch {
            print(error)
        }
        
        self.currentFolderLabel.stringValue = path
        
        self.inputFilesTable.reloadData()
    }
    
    func setupTableView() {
        inputFilesTable.dataSource = self
        inputFilesTable.delegate = self
    }
    
    override var representedObject: Any? {
        didSet {
            
        }
    }
    
    @objc func openInputFolder(_ sender: Any) {
        dataSource.removeAll()
        inputFilesTable.reloadData()
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        
        let finded = panel.runModal()
        
        if finded == .OK {
            var directoryArray = [String]()
            for url in panel.urls {
                var isDirectory: ObjCBool = ObjCBool(false)
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                if isDirectory.boolValue == true {
                    do {
                        let filesPaths = try FileManager.default.contentsOfDirectory(atPath: url.path)
                        for filePath in filesPaths {
                            if filePath.lowercased().hasSuffix(".ncm") {
                                let fileURL = url.appendingPathComponent(filePath)
                                dataSource.append(fileURL)
                            }
                        }
                    } catch {
                        print(error)
                    }
                    directoryArray.append(url.path)
                } else {
                    if url.pathExtension.lowercased().range(of: ".ncm") != nil {
                        dataSource.append(url)
                    }
                }
            }
            self.currentFolderLabel.stringValue = directoryArray.joined(separator: "\n")
            inputFilesTable.reloadData()
        } else {
            inputFilesTable.reloadData()
        }
    }
    
    @objc func openOutputFolder(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        
        let finded = panel.runModal()
        
        if finded == .OK {
            for url in panel.urls {
                self.outputFolderURL = url
                self.ouputPathLabel.stringValue = url.path
                break
            }
        } else {
        }
    }
    
    @objc func startConvert(_ sender: Any) {
        if dataSource.count == 0 {
            let alert = NSAlert(error: ConverError.inputSourceInvalid)
            alert.messageText = "没有可供转换的数据"
            alert.icon = NSImage(named: NSImage.Name())
            alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in

            })
        }
        
        startButton.isEnabled = false
        
        errorCount = 0
        
        succeedCount = 0
        
        let coreCount = ProcessInfo().processorCount
        
        for index in 0..<dataSource.count {
            let queue = queueArray[index % coreCount]
            queue.async {
                self.convertMusic(index: index)
            }
        }
    }
    
    /// 根据CPU物理核心数组装队列，尽量跑死CPU
    lazy var queueArray: [DispatchQueue] = {
        var result = [DispatchQueue]()
        let coreCount = ProcessInfo().processorCount
        for index in 0..<coreCount {
            result.append(DispatchQueue(label: "NCMDecode.Convert.Queue\(index)", qos: DispatchQoS.userInteractive))
        }
        return result
    }()
    
    var totalCount: Int {
        return dataSource.count
    }
    
    var errorCount: Int = 0
    
    var succeedCount: Int = 0
    
    /// buffer 1MB
    let bufferSize: Int = 10_240
        
    func convertMusic(index: Int) {
        autoreleasepool {
            do {
                let url = dataSource[index]
                
                let decoder = try NCMDump(filePath: url.path, outputDir: outputFolderURL.path)
                try decoder.convert()
                
                self.progressAppend(index: index, success: true)
            } catch {
                print(error)
                self.progressAppend(index: index, success: false)
            }
        }
    }
    
    func progressAppend(index: Int, success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            if success {
                strongSelf.succeedCount += 1
            } else {
                strongSelf.errorCount += 1
            }
            
            let succeedCount = strongSelf.succeedCount
            let errorCount = strongSelf.errorCount
            let totalCount = strongSelf.totalCount
            let progress = Double(succeedCount + errorCount + 1) / Double(totalCount) * 100.0
            strongSelf.progressView.doubleValue = progress
            
            if succeedCount + errorCount == totalCount {
                let alert = NSAlert(error: ConverError.notError)
                alert.alertStyle = .informational
                let messageText = "转换完成 \n成功: \(totalCount - errorCount), 失败: \(errorCount)"
                alert.messageText = messageText
                alert.icon = NSImage(named: NSImage.Name("Success"))
                alert.beginSheetModal(for: strongSelf.view.window!, completionHandler: { (response) in

                })
                self?.startButton.isEnabled = true
            }
        }
    }
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 44.0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        switch tableColumn?.title {
        case "路径":
            return dataSource[row].path
        case "歌曲名称":
            return dataSource[row].lastPathComponent
        default:
            return nil
        }
    }
}
