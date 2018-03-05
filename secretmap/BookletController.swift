//
//  BookletController.swift
//  secretmap
//
//  Created by Anton McConville on 2017-12-18.
//  Copyright © 2017 Anton McConville. All rights reserved.
//

import Foundation

import UIKit

struct Article: Codable {
    let page: Int
    let title: String
    let subtitle: String
    let imageEncoded:String
    let subtext:String
    let description: String
}

struct BackendResult: Codable {
    let status: String
    let result: String?
}

struct ResultOfEnroll: Codable {
    let message: String
    let result: EnrollFinalResult
}

struct EnrollFinalResult: Codable {
    let user: String
    let txId: String
}

class BookletController: UIViewController, UIPageViewControllerDataSource {
    
    private var pageViewController: UIPageViewController?
    
    private var pages:[Article]?
    // testedit
    private var pageCount = 0
    
    var blockchainUser: BlockchainUser?
    
    // Put this in viewDidLoad
    override func viewDidAppear(_ animated: Bool) {
        if let existingUserId = loadUser() {
            blockchainUser = existingUserId
        }
        else {
            guard let url = URL(string: "http://148.100.98.53:3000/api/execute") else { return }
            let parameters: [String:Any]
            let request = NSMutableURLRequest(url: url)
            
            let session = URLSession.shared
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            parameters = ["type":"enroll", "queue":"user_queue", "params":[]]
            request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: [])
            
            let enrollUser = session.dataTask(with: request as URLRequest) { (data, response, error) in
                
                if let data = data {
                    do {
                        // Convert the data to JSON
                        let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                        
                        if let json = jsonSerialized, let status = json["status"], let resultId = json["resultId"] {
                            NSLog(status as! String)
                            NSLog(resultId as! String) // Use this one to get blockchain payload - should contain userId
                            
                            // Start pinging backend with resultId
                            self.requestResults(resultId: resultId as! String, attemptNumber: 0)
                        }
                    }  catch let error as NSError {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
            enrollUser.resume()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let urlString = "https://www.ibm-fitchain.com/pages"
        guard let url = URL(string: urlString) else {
            print("url error")
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            
            guard let data = data else { return }
            
            do {
                //Decode retrived data with JSONDecoder and assing type of Article object
                let pages = try JSONDecoder().decode([Article].self, from: data)
                
                //Get back to the main queue
                DispatchQueue.main.async {
                    self.pages = pages
                    self.pageCount = pages.count
                    self.createPageViewController()
                    self.setupPageControl()
                }
            } catch let jsonError {
                
                if let path = Bundle.main.url(forResource: "booklet", withExtension: "json") {
                                do {
                                    _ = try Data(contentsOf: path, options: .mappedIfSafe)
                                    let jsonData = try Data(contentsOf: path, options: .mappedIfSafe)
                                    if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: AnyObject] {
                    
                                        if let p = jsonDict["pages"] as? [Article] {
                                            self.pages = p
                                            self.pageCount = p.count
                                            self.createPageViewController()
                                            self.setupPageControl()
                                        }
                                    }
                                } catch {
                                    print("couldn't parse JSON data")
                                }
                            }
                print(jsonError)
            }
        }.resume()
    }
    
    private func createPageViewController() {
        
        let pageController = self.storyboard!.instantiateViewController(withIdentifier: "booklet") as! UIPageViewController
        pageController.dataSource = self
        
        if self.pageCount > 0 {
            let firstController = getItemController(itemIndex: 0)!
            let startingViewControllers = [firstController]
            pageController.setViewControllers(startingViewControllers, direction: UIPageViewControllerNavigationDirection.forward, animated: false, completion: nil)
        }
        
        pageViewController = pageController
        addChildViewController(pageViewController!)
        self.view.addSubview(pageViewController!.view)
        pageViewController!.didMove(toParentViewController: self)
    }
    
    private func setupPageControl() {
        let appearance = UIPageControl.appearance()
        appearance.pageIndicatorTintColor = UIColor(red:0.92, green:0.59, blue:0.53, alpha:1.0)
        appearance.currentPageIndicatorTintColor = UIColor(red:0.47, green:0.22, blue:0.22, alpha:1.0)
        appearance.backgroundColor = UIColor.white
    }
    
    // MARK: - UIPageViewControllerDataSource
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        let itemController = viewController as! BookletItemController
        
        if itemController.itemIndex > 0 {
            return getItemController(itemIndex: itemController.itemIndex-1)
        }
        
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        let itemController = viewController as! BookletItemController
        
        if itemController.itemIndex+1 < self.pageCount {
            return getItemController(itemIndex: itemController.itemIndex+1)
        }
        
        return nil
    }
    
    private func getItemController(itemIndex: Int) -> BookletItemController? {
        
        if itemIndex < self.pages!.count {
            let pageItemController = self.storyboard!.instantiateViewController(withIdentifier: "ItemController") as! BookletItemController
            pageItemController.itemIndex = itemIndex
            pageItemController.titleString = self.pages![itemIndex].title
            pageItemController.subTitleString = self.pages![itemIndex].subtitle
            pageItemController.image = self.base64ToImage(base64: self.pages![itemIndex].imageEncoded)
            pageItemController.subtextString = self.pages![itemIndex].subtext
            pageItemController.statementString = self.pages![itemIndex].description
            
            return pageItemController
        }
        
        return nil
    }
    
    func base64ToImage(base64: String) -> UIImage {
        var img: UIImage = UIImage()
        if (!base64.isEmpty) {
            let decodedData = NSData(base64Encoded: base64 , options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)
            let decodedimage = UIImage(data: decodedData! as Data)
            img = (decodedimage as UIImage?)!
        }
        return img
    }
    
    // MARK: - Page Indicator
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return self.pages!.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
    
    // MARK: - Additions
    
    func currentControllerIndex() -> Int {
        
        let pageItemController = self.currentController()
        
        if let controller = pageItemController as? BookletItemController {
            return controller.itemIndex
        }
        
        return -1
    }
    
    // request results of enrollment to blockchain
    
    private func requestResults(resultId: String, attemptNumber: Int) {
        if attemptNumber < 60 {
            guard let url = URL(string: "http://148.100.98.53:3000/api/results/" + resultId) else { return }
            
            let session = URLSession.shared
            let enrollUser = session.dataTask(with: url) { (data, response, error) in
                if let data = data {
                    do {
                        // data is
                        // {"status":"done","result":"{\"message\":\"success\",\"result\":{\"user\":\"ffc22a44-a34a-453b-997a-117f00ec651e\",\"txId\":\"67a76bf0063ed13a41448d9428f21ee3cf345e4ed90ba2edf0e2ddea569c3a16\"}}"}
                        
                        // Convert the data to JSON
                        let backendResult = try JSONDecoder().decode(BackendResult.self, from: data)
                        
                        // if the status from queue is done
                        if backendResult.status == "done" {
                            
                            let resultOfEnroll = try JSONDecoder().decode(ResultOfEnroll.self, from: backendResult.result!.data(using: .utf8)!)
                            print(resultOfEnroll.result.user)
                            
                            self.blockchainUser = BlockchainUser(userId: resultOfEnroll.result.user)
                            self.saveUser()
                            
                            let alert = UIAlertController(title: "You have been enrolled to the blockchain network", message: resultOfEnroll.result.user, preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "Confirm", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                        else {
                            let when = DispatchTime.now() + 3 // 3 seconds from now
                            DispatchQueue.main.asyncAfter(deadline: when) {
                                self.requestResults(resultId: resultId, attemptNumber: attemptNumber+1)
                            }
                        }
                        
                    }  catch let error as NSError {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
            enrollUser.resume()
        }
        else {
            NSLog("Attempted 60 times to enroll... No results")
        }
    }
    
    
    // Save User generated from Blockchain Network
    
    private func saveUser() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(blockchainUser!, toFile: BlockchainUser.ArchiveURL.path)
        if isSuccessfulSave {
            print("User has been enrolled and persisted.")
        } else {
            print("Failed to save user...")
        }
    }
    
    // Load User
    
    func loadUser() -> BlockchainUser?  {
        return NSKeyedUnarchiver.unarchiveObject(withFile: BlockchainUser.ArchiveURL.path) as? BlockchainUser
    }
    
    func currentController() -> UIViewController? {
        
        let count:Int = (self.pageViewController?.viewControllers?.count)!;
        
        if count > 0 {
            return self.pageViewController?.viewControllers![0]
        }
        
        return nil
    }
}
