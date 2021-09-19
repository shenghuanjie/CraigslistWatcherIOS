//
//  ViewController.swift
//  CraigslistWatcher
//
//  Created by Huanjie Sheng on 7/9/21.
//

import UIKit

struct defaultsKeys {
    static let mileageInput = "mileageInput"
    static let keywords = "keywords"
    static let addtionalFilters = "addtionalFilters"
    static let hasImage = "hasImage"
    static let postedToday = "postedToday"
    static let postIds = "CraigslistPostIds"
}

extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}

extension String {
    func groups(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regexOptions: NSRegularExpression.Options = [.dotMatchesLineSeparators]
            let regex = try NSRegularExpression(
                pattern: regexPattern, options: regexOptions)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return matches.map { match in
                return (0..<match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

class ViewController: UIViewController { //, UIScrollViewDelegate{

    @IBOutlet weak var mileageInput: UITextField!
    @IBOutlet weak var keywords: UITextField!
    @IBOutlet weak var hasImage: UISwitch!
    @IBOutlet weak var postedToday: UISwitch!
    @IBOutlet weak var addtionalFilters: UITextField!
    @IBOutlet weak var debugText: UILabel!
    
    let defaults = UserDefaults.standard
    let notifications = NotificationCenter.default
    var movies: [String] = ["bad-boys","joker","hollywood"]
    var frame = CGRect.zero
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
//        pageControl.numberOfPages = movies.count
//        setupScreens()
//
//        scrollView.delegate = self
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action:
                                                    #selector(swipeFunc(gesture:)))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)
        
    }
    
    @IBAction func open(_ sender: UIButton) {
        if let mileageInput = defaults.string(forKey: defaultsKeys.mileageInput) {
            keywords.text = mileageInput
        }else{
            keywords.text = mileageInput.text
        }
        defaults.set(mileageInput.text, forKey: defaultsKeys.mileageInput)
        
        var foundPosts =  Array<Array<String>>()
        
        do{
            let test_string3 = """
            <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-maytag-quiet-series/7366077748.html" class="result-image gallery" data-ids="3:00I0I_tut5vZ7ta5z_0t20CI,3:01616_5rlFzcb1C7vz_0t20CI,3:00B0B_2muJCiuJBR3z_0t20CI,3:00I0I_fMXkchJXgYOz_0t20CI">
            </a>

            <div class="result-info">
                <span class="icon icon-star" role="button">
                    <span class="screen-reader-text">favorite this post</span>
                </span>

                    <time class="result-date" datetime="2021-08-20 17:33" title="Fri 20 Aug 05:33:21 PM">Aug 20</time>


                <h3 class="result-heading">
                    <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-maytag-quiet-series/7366077748.html" data-id="7366077748" class="result-title hdrlnk" id="postid_7366077748" >Maytag quiet series</a>
                </h3>
            """
            foundPosts = try searchForPosts(test_string3)
            debugText.text = foundPosts[0].joined(separator: " | ")
        } catch let error {
            print("search failed")
            debugText.text = "search failed \(error)"
        }
        
        //1: link, 2: title, 3: image, 4: time, 5: id, 6: name
        let id_idx = 5
        let postIds = foundPosts.compactMap({ $0[id_idx] })
        let existingPostIds = defaults.stringArray(forKey: defaultsKeys.postIds)!
        let newIds = postIds.difference(from: existingPostIds)
        let newPosts = foundPosts.filter({newIds.contains($0[id_idx])})
        
        print("foundPosts")
        print(foundPosts[0][1])
        print("existingPostIds")
        
        print(existingPostIds)
        print(newIds)
        print(newPosts)
        
        defaults.setValue(postIds, forKey: defaultsKeys.postIds)
        
        if newPosts.count > 0 {
            notifications.post(name: Notification.Name("UserLoggedIn"), object: nil)
            
        }
        
        //scheduledTimerWithTimeInterval()
        
    }

    @IBAction func stop(_ sender: UIButton) {
        let foundPosts = get_craigslist_posts()
        if foundPosts.count > 0 {
            debugText.text = foundPosts[0].joined(separator: " | ")
        }else {
            debugText.text = "no post found!"
        }
        timer.invalidate()
        defaults.setValue([], forKey: defaultsKeys.postIds)
    }
    
    func searchForPosts(_ input: String) throws -> Array<Array<String>>{
        //1: link, 2: title, 3: image, 4: time, 5: id, 6: name
        let pattern =
            "<a href=\"(https://sfbay.craigslist.org/sby/zip/d/(.*?)/\\d+.html)\" class=\"result-image gallery\" data-ids=\"\\d+:(.*?)\">" + ".*?" + "</a>" + ".*?" +
            "<time class=\"result-date\" datetime=\"(\\d+-\\d+-\\d+ \\d+:\\d+)\" title=\".*?\">.*?</time>" + "[\n| ]*" +
            "<h3 class=\"result-heading\">" + ".*?" +
        "<a href=\"\\1\" data-id=\"(\\d+)\" class=\"result-title hdrlnk\" id=\"postid_\\d+\" >(.*?)</a>"
        let regex_groups = input.groups(for: pattern)
        print(regex_groups)
        if regex_groups.count > 0{
            return regex_groups
        }else{
            return []// "no group"
        }
    }
    
    func get_craigslist_posts() ->  Array<Array<String>> {
        let myURLString = "https://sfbay.craigslist.org/search/zip?search_distance=2&postal=95050"
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return []
        }
        
        let request = URLRequest(url: myURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error as NSError? {
                print("task transport error %@ / %d", error.domain, error.code)
                return
            }
            let response = response as! HTTPURLResponse
            let data = data!
            print("task finished with status %d, bytes %d", response.statusCode, data.count)
        }.resume()

        do {
            let myHTMLString = try String(contentsOf: myURL, encoding: .ascii)
            // print("HTML : \(myHTMLString)")
            do {
                let mySearchResult = try self.searchForPosts(myHTMLString);
                return mySearchResult
            } catch let error {
                print("error in searching \(error)")
                return []
            }
            // return myHTMLString
        } catch let error {
            print("Error: \(error)")
            return []
        }
        
    }
    
    @objc func swipeFunc(gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right{
            print("swiped right")
            performSegue(withIdentifier: "showPosts", sender: self)
        }
    }
    
    var timer = Timer()

    func scheduledTimerWithTimeInterval(){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateCounting), userInfo: nil, repeats: true)
    }

    @objc func updateCounting(){
        NSLog("counting..")
    }
    
//    func setupScreens() {
//        for index in 0..<movies.count {
//            // 1.
//            frame.origin.x = scrollView.frame.size.width * CGFloat(index)
//            frame.size = scrollView.frame.size
//
//            // 2.
//            let imgView = UIImageView(frame: frame)
//            imgView.image = UIImage(named: movies[index])
//
//            self.scrollView.addSubview(imgView)
//        }
//
//        // 3.
//        scrollView.contentSize = CGSize(width: (scrollView.frame.size.width * CGFloat(movies.count)), height: scrollView.frame.size.height)
//        scrollView.delegate = self
//    }
//
//    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        let pageNumber = scrollView.contentOffset.x / scrollView.frame.size.width
//        pageControl.currentPage = Int(pageNumber)
//    }
}

extension ViewController : UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
}
