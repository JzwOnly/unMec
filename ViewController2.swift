//
//  ViewController2.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel
import M3U8Kit

class ViewController2: BaseViewController {

    override func viewDidLoad() {
        
        sessionManager = appDelegate.sessionManager2

        super.viewDidLoad()


        URLStrings = [
            "https://vod4.buycar5.cn/20210126/cVGcDm33/index.m3u8",
            "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
            "http://issuecdn.baidupcs.com/issue/netdisk/MACguanjia/BaiduNetdisk_mac_2.2.3.dmg",
            "http://m4.pc6.com/cjh3/VicomsoftFTPClient.dmg",
            "https://qd.myapp.com/myapp/qqteam/pcqq/QQ9.0.8_2.exe",
            "http://gxiami.alicdn.com/xiami-desktop/update/XiamiMac-03051058.dmg",
            "http://113.113.73.41/r/baiducdnct-gd.inter.iqiyi.com/cdn/pcclient/20190413/13/25/iQIYIMedia_005.dmg?dis_dz=CT-GuangDong_GuangZhou&dis_st=36",
            "http://pcclient.download.youku.com/ikumac/youkumac_1.6.7.04093.dmg?spm=a2hpd.20022519.m_235549.5!2~5~5~5!2~P!3~A&file=youkumac_1.6.7.04093.dmg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"

        ]
        

        setupManager()

        updateUI()
        tableView.reloadData()
        
    }
}


// MARK: - tap event
extension ViewController2 {

    @IBAction func addDownloadTask(_ sender: Any) {
        self.addDownloadTask()
    }
    func addDownloadTask() {
        let downloadURLStrings = sessionManager.tasks.map { $0.url.absoluteString }

        guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
        if URLString.contains(".m3u8") {
            do {
                let model:M3U8PlaylistModel = try M3U8PlaylistModel.init(url: NSURL.init(string: URLString)! as URL)
                print("streamURLs = \(model.masterPlaylist!.allStreamURLs()!)")
//                print("xSessionKey = \(model.masterPlaylist!.xSessionKey!)")
                print(model.segmentNames(for: model.audioPl)!)
                let urlStrings:NSMutableArray = NSMutableArray.init()
                let filenameStrings:NSMutableArray = NSMutableArray.init()
                let keymap:NSMutableDictionary = NSMutableDictionary.init()
                print(self.sessionManager.cache.downloadPath)
                print(self.sessionManager.cache.downloadFilePath)
                print(self.sessionManager.cache.downloadTmpPath)
//                guard model.masterPlaylist.allStreamURLs().count > 0 else { return }
//                guard let m3u8URL:NSURL = model.masterPlaylist.allStreamURLs()?.first as? NSURL else { return }
//                print("m3u8链接:\(m3u8URL.absoluteString!)")
//                print("m3u8文件名:\(model.masterPlaylist.name!)")
//                urlStrings.add(m3u8URL.absoluteString!)
//                filenameStrings.add(model.masterPlaylist.name!)
                for index in 0..<model.mainMediaPl!.segmentList.count {
                    let info:M3U8SegmentInfo = model.mainMediaPl!.segmentList.segmentInfo(at: index)
//                    print("key=\(info.xKey!)\nurl=\(info.mediaURL()!)\n\n")
                    urlStrings.add(info.mediaURL()!.absoluteString)
                    let filename:NSString = NSString.init(format: "media_%d.ts", index)
                    filenameStrings.add(filename)
//                    print("ts链接:\(tsUrlString)")
                    print("ts文件名:\(filename)")
                    print("文件是否存在\(self.sessionManager.cache.fileExists(fileName: filename as String))")
                    // 添加校验的key
                    if !urlStrings.contains(info.xKey.url()!) {
                        print("key链接:\(info.xKey.url()!)")
                        urlStrings.add(info.xKey.url()!)
                        filenameStrings.add("key\(index).key")
                        keymap.setValue("key\(index).key", forKey: info.xKey.url()!)
                    }
                }
//                print(urlStrings)
//                print(filenameStrings)
                // 保存m3u8文件到本地
                let m3u8Path = self.sessionManager.cache.downloadFilePath
                let error:NSErrorPointer = nil
//                model.savePlaylists(toPath: m3u8Path, error: error)
                model.savePlaylists(toPath: m3u8Path, rewrite:false, keymap: keymap as? [AnyHashable : Any], error: error)
                if error != nil {
                    print("保存本地成功")
                }
                // 下载ts和key
                DispatchQueue.global().async {
                    let tasks:[DownloadTask] = self.multiDownload(urls: urlStrings as![String], fileNames: filenameStrings as? [String]) { (filePath, msg, isSuccess) in
                        //                    print(filePath!)
                    }
                    self.sessionManager.completion(onMainQueue: true, handler: { (manager) in
                        if manager.status == .succeeded {
                            let tlsFilePaths = tasks.map{$0.filePath}
                            print("所有m3u8文件路径", tlsFilePaths)
                            // 启动本地http服务代理本地m3u8视频
                            DispatchQueue.tr.executeOnMain {
                                BNHttpLocalServer.shareInstance().documentRoot = m3u8Path
                                BNHttpLocalServer.shareInstance().port = 8080
                                BNHttpLocalServer.shareInstance().tryStart()
                            }
                        }
                    })
                }

            } catch let error {
                debugPrint(error)
            }
        } else {
            sessionManager.download(URLString) { [weak self] _ in
                guard let self = self else { return }
                let index = self.sessionManager.tasks.count - 1
                self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                self.updateUI()
            }
        }

    }
    func multiDownload(urls: [String], fileNames: [String]? = nil, completionHandler: @escaping (String?, String?, Bool) -> Void) -> [DownloadTask] {
        // 如果同时开启的下载任务过多，会阻塞主线程，所以可以在子线程中开启
//        DispatchQueue.global().async {
            let tasks = self.sessionManager.multiDownload(urls, fileNames: fileNames) { [weak self] _ in
                self?.updateUI()
                self?.tableView.reloadData()
            }
            tasks.progress(onMainQueue: true) { (task) in
                let progress = task.progress.fractionCompleted
                print("下载中，进度:\(progress)")
            }
            .success { (task) in
                print("下载完成，总任务：\(self.sessionManager.succeededTasks.count)/\(self.sessionManager.tasks.count)")
//                print(task.filePath)
                completionHandler(task.filePath, nil, true)
            }
            .failure { (task) in
                DispatchQueue.main.async {
                    print("下载失败，总任务：\(self.sessionManager.succeededTasks.count)/\(self.sessionManager.tasks.count)")
                    if let error = task.error {
                        completionHandler(nil, error.localizedDescription, false)
                    } else {
                        completionHandler(nil, "下载失败", false)
                    }
                }
            }
        return tasks;
//        }
    }
    @IBAction func deleteDownloadTask(_ sender: UIButton) {
        let count = sessionManager.tasks.count
        guard count > 0 else { return }
        let index = count - 1
        guard let task = sessionManager.tasks.safeObject(at: index) else { return }
        // tableView 刷新、 删除 task 都是异步的，如果操作过快会导致数据不一致，所以需要限制button的点击
        sender.isEnabled = false
        sessionManager.remove(task, completely: false) { [weak self] _ in
            self?.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            self?.updateUI()
            sender.isEnabled = true
        }
    }
    
    
    @IBAction func sort(_ sender: Any) {
        sessionManager.tasksSort { (task1, task2) -> Bool in
            if task1.startDate < task2.startDate {
                return task1.startDate < task2.startDate
            } else {
                return task2.startDate < task1.startDate
            }
        }
        tableView.reloadData()
    }
}



