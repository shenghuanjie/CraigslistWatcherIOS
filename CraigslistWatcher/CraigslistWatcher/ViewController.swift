//
//  ViewController.swift
//  CraigslistWatcher
//
//  Created by Huanjie Sheng on 7/9/21.
//

import UIKit
import AVFoundation

struct defaultsKeys {
    static let mileageInput = "mileageInput"
    static let postalCodeInput = "postalCodeInput"
    static let keywordsInput = "keywordsInput"
    static let addtionalFilters = "addtionalFilters"
    static let hasImage = "hasImage"
    static let postedToday = "postedToday"
    static let postIds = "CraigslistPostIds"
}

let defaultParams = [
    "mileageInput": "25",
    "postalCodeInput": "94538",
    "keywordsInput": "",
    "addtionalFilters": "",
    "hasImage": false,
    "postedToday": true,
] as [String : Any]

//0:all, 1:link, 2:name 3:pic 4:time, 5:id, 6:titlex
struct postInfos {
    static let all = 0
    static let link = 1
    static let name = 2
    static let pic = 3
    static let time = 4
    static let id = 5
    static let title = 6
}

extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet).intersection(thisSet))
    }
    
    func unique() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

//var player: AVAudioPlayer?
//func playSound() {
//    guard let url = Bundle.main.url(forResource: "soundName", withExtension: "mp3") else { return }
//
//    do {
//        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//        try AVAudioSession.sharedInstance().setActive(true)
//
//        // The following line is required for the player to work on iOS 11. Change the file type accordingly
//        player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
//
//        // iOS 10 and earlier require the following line
//        // player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3)
//
//        guard let player = player else { return }
//
//        player.play()
//
//    } catch let error {
//        print(error.localizedDescription)
//    }
//}

extension String {
    func groups(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regexOptions: NSRegularExpression.Options = [] //[.dotMatchesLineSeparators]
            let regex = try NSRegularExpression(
                pattern: regexPattern, options: regexOptions)
            print("text is being searched")
            let matches = regex.matches(
                in: text, range: NSRange(text.startIndex..., in: text))
            // print("matches")
            // print(matches)
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

class ViewController: UIViewController, UITableViewDataSource, UITextFieldDelegate, UITableViewDelegate {
    //, UIScrollViewDelegate{
    @IBOutlet weak var mileageInput: UITextField!
    @IBOutlet weak var postalCodeInput: UITextField!
    @IBOutlet weak var keywordsInput: UITextField!
    @IBOutlet weak var hasImage: UISwitch!
    @IBOutlet weak var postedToday: UISwitch!
    @IBOutlet weak var addtionalFilters: UITextField!
    @IBOutlet weak var debugText: UILabel!
    @IBOutlet weak var listPosts: UITableView!
    @IBOutlet weak var triggerButton: UIButton!
    
    //var audioPlayer : AVPlayer!
    var audioPlayer : AVAudioPlayer!
    
    let defaults = UserDefaults.standard
    let notifications = NotificationCenter.default
    let maxPostsSaved = Int(250)
    var savedPostIds: [String] = []
    var newPostIds: [String] = []
    var newPosts = Array<Array<String>>()
    var movies: [String] = ["bad-boys","joker","hollywood"]
    var frame = CGRect.zero
    var foundPosts = Array<Array<String>>()
    
    // timer
    var timer = Timer()
    var timerInterval = 10
    
    // create a sound ID, in this case its the tweet sound.
    let systemSoundID: SystemSoundID = 1016

    // var postLinks = Array(repeating: "Item", count: 20)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
//        pageControl.numberOfPages = movies.count
//        setupScreens()
//
//        scrollView.delegate = self
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action:#selector(swipeFunc(gesture:)))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)
        
        debugText.lineBreakMode = NSLineBreakMode.byWordWrapping
        debugText.numberOfLines = 0
        
        listPosts.register(UITableViewCell.self, forCellReuseIdentifier: "TableViewCell")
        listPosts.dataSource = self
        listPosts.delegate = self
        
        setParams()
        
        let savedPostIdsTmp = defaults.stringArray(forKey: defaultsKeys.postIds)
        if (savedPostIdsTmp != nil){
            savedPostIds = savedPostIdsTmp!
        }else{
            savedPostIds = []
        }
        
        if (!triggerButton.isSelected){
            scheduledTimerWithTimeInterval()
        }
    }
    
    func setParams(){
        var mileageInputString = defaults.string(forKey: defaultsKeys.mileageInput)
        if (mileageInputString == nil){
            mileageInputString = (defaultParams["mileageInput"] as! String)
        }else{
            mileageInputString = mileageInputString!
        }
        mileageInput.text = mileageInputString
        
        var postalCodeString = defaults.string(forKey: defaultsKeys.postalCodeInput)
        if (postalCodeString == nil){
            postalCodeString = (defaultParams["postalCodeInput"] as! String)
        }else{
            postalCodeString = postalCodeString!
        }
        postalCodeInput.text = postalCodeString
        
        var keywordsString = defaults.string(forKey: defaultsKeys.keywordsInput)
        if (keywordsString == nil){
            keywordsString = (defaultParams["keywordsInput"] as! String)
        }else{
            keywordsString = keywordsString!
        }
        keywordsInput.text = keywordsString
        
        var additionalFiltersString = defaults.string(forKey: defaultsKeys.addtionalFilters)
        if (additionalFiltersString == nil){
            additionalFiltersString = (defaultParams["addtionalFilters"] as! String)
        }else{
            additionalFiltersString = additionalFiltersString!
        }
        addtionalFilters.text = additionalFiltersString
        
        var hasImageBool = defaults.object(forKey: defaultsKeys.hasImage)
        if hasImageBool != nil {
            hasImageBool = hasImageBool as! Bool
        }else{
            hasImageBool = defaultParams["hasImage"] as! Bool
        }
        hasImage.isOn = hasImageBool as! Bool
        
        var postedTodayBool = defaults.object(forKey: defaultsKeys.postedToday)
        if postedTodayBool != nil {
            postedTodayBool = postedTodayBool as! Bool
        }else{
            postedTodayBool = defaultParams["postedToday"] as! Bool
        }
        postedToday.isOn = postedTodayBool as! Bool
        
    }
    
    @IBAction func typedMileageInput(_ sender: UITextField) {
        defaults.set(sender.text, forKey: defaultsKeys.mileageInput)
    }
    
    @IBAction func typedPostalCodeInput(_ sender: UITextField) {
        defaults.set(sender.text, forKey: defaultsKeys.postalCodeInput)
    }
    
    @IBAction func typedKeywordsInput(_ sender: UITextField) {
        defaults.set(sender.text, forKey: defaultsKeys.postalCodeInput)
    }
    
    @IBAction func touchedHasImage(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: defaultsKeys.hasImage)
    }
    
    @IBAction func touchedPostedToday(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: defaultsKeys.postedToday)
    }
    
    
    @IBAction func reset(_ sender: UIButton) {
        print("reset is clicked");
        defaults.setValue([], forKey: defaultsKeys.postIds)
        self.savedPostIds = []
        print(self.savedPostIds)
    }
    
    @IBAction func open(_ sender: UIButton) {
        print("open is clicked");
        let myURL = get_current_craigslist_link()
        openURL(myURL)
        
    }

    @IBAction func stop(_ sender: UIButton) {
        if (sender.isSelected){
            sender.setTitle("Stop", for: .normal)
            scheduledTimerWithTimeInterval()
        }else{
            sender.setTitle("Start", for: .selected)
            pauseTimer()
        }
        sender.isSelected = !sender.isSelected
    }
    
    func searchForPosts(_ input: String) throws -> Array<Array<String>>{
        //1: link, 2: title, 3: image, 4: time, 5: id, 6: name
        let pattern =
            "<a href=\"(https://sfbay.craigslist.org/sby/zip/d/(.*?)/\\d+.html)\" class=\"result-image gallery\" data-ids=\"\\d+:(.*?)\">"
            + "[\n\r| ]*" + "</a>" + "[\n\r| ]*"
            + "<div class=\"result-info\">" + "[\n\r| ]*"
            + "<span class=\"icon icon-star\" role=\"button\">" + "[\n\r| ]*"
            + "<span class=\"screen-reader-text\">favorite this post</span>" + "[\n\r| ]*"
            + "</span>" + "[\n\r| ]*"
            + "<time class=\"result-date\" datetime=\"(\\d+-\\d+-\\d+ \\d+:\\d+)\" title=\".*?\">.*?</time>" + "[\n\r| ]*"
            + "<h3 class=\"result-heading\">" + "[\n\r| ]*"
            + "<a href=\"\\1\" data-id=\"(\\d+)\" class=\"result-title hdrlnk\" id=\"postid_\\d+\" >(.*?)</a>"
        let regex_groups = input.groups(for: pattern)
        //print(regex_groups)
        if regex_groups.count > 0{
            return regex_groups
        }else{
            return []// "no group"
        }
    }
    
    private func get_craigslist_link(distance: String = "25", postcode: String = "94538", hasPic: Bool = false, postedToday: Bool = true) -> String {
        var hasPicString = ""
        if(hasPic){
            hasPicString = "&hasPic=1"
        }else{
            hasPicString = ""
        }
        var postedTodayString = ""
        if(postedToday){
            postedTodayString = "&postedToday=1"
        }else{
            postedTodayString = ""
        }
        var distanceString = ""
        if (distance.count == 0){
            distanceString = defaultParams["mileageInput"] as! String
        }else{
            distanceString = distance
        }
        var postCodeString = ""
        if (postcode.count == 0){
            postCodeString =   defaultParams["postalCodeInput"] as! String
        }else{
            postCodeString = postcode
        }
        let myURLString = "https://sfbay.craigslist.org/d/free-stuff/search/sby/zip?sort=date" + hasPicString + postedTodayString + "&search_distance=" + distanceString + "&postal=" + postCodeString + "&"
        return myURLString
    }
    
    func get_current_craigslist_link() -> String{
        return get_craigslist_link(distance: mileageInput.text!, postcode: postalCodeInput.text!, hasPic: hasImage.isOn, postedToday: postedToday.isOn)
    }
    
    func get_craigslist_posts() ->  Array<Array<String>> {
        
        let myURLString = get_current_craigslist_link()
        print("searching URL: " + myURLString)
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return []
        }
        //print("myURLString: \(myURLString)")
        
        let request = URLRequest(url: myURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error as NSError? {
                print("task transport error %@ / %d", error.domain, error.code)
                return
            }
            let response = response as! HTTPURLResponse
            let data = data!
            print(NSString(format:"task finished with status %d, bytes %d", response.statusCode, data.count))
        }.resume()

        do {
            let myHTMLString = try String(contentsOf: myURL, encoding: .ascii)
            // print("HTML : \(myHTMLString)")
            
            do {
                // let mySearchResult = try self.searchForPosts(testHTMLString);
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
    
    // List found posts
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // print("I am updating tableView count" + String(self.newPosts.count))
        // print(self.savedPostIds)
        return self.foundPosts.count
    }
    
    func setSavedPostIds(_ postIds: Array<String>){
        self.savedPostIds = postIds
        print("savedPostIds has been set")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // print("I am updating tableView text" + String(indexPath.row))
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TableViewCell")

        // let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath)
        
        let post = self.foundPosts[indexPath.row]
        //0:all, 1:link, 2:name 3:pic 4:time, 5:id, 6:title
        cell.textLabel?.text = post[postInfos.name]
        //print(self.savedPostIds)
        //print()
        if(self.newPostIds.contains(post[postInfos.id])){
            // print(post[postInfos.id] + " is contained")
            cell.textLabel?.textColor = .red
        }
        else{
            // print(post[postInfos.id] + " not found")
            cell.textLabel?.textColor = .black
        }
        //cell.detailTextLabel?.text = location
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
         // print("I'm selected!" + String(indexPath.row))
         let myURL = self.foundPosts[indexPath.row][1]
         openURL(myURL)
     }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func openURL(_ myUrl: String){
        if let url = URL(string: "\(myUrl)"), !url.absoluteString.isEmpty {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc func swipeFunc(gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right{
            print("swiped right")
            performSegue(withIdentifier: "showPosts", sender: self)
        }
    }
    
    func scheduledSoundWithTimeInterval(){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(10), target: self, selector: #selector(self.playTestSound), userInfo: nil, repeats: true)
        self.timer.fire()
    }
    
    @objc func playTestSound(){
        AudioServicesPlaySystemSound(1327)
    }

    func scheduledTimerWithTimeInterval(){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(self.timerInterval), target: self, selector: #selector(self.updateCounting), userInfo: nil, repeats: true)
        self.timer.fire()
    }
    
    func pauseTimer(){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        self.timer.invalidate()
    }

    @objc func updateCounting(){
        print("stop is clicked")
        self.foundPosts = self.get_craigslist_posts()
        
        //TODO: expand with new post
        
        //0: all, 1: link, 2: name, 3: image, 4: time, 5: id, 6: title
        let postIds = self.foundPosts.compactMap({ $0[postInfos.id] })
        self.newPostIds = postIds.difference(from: self.savedPostIds)
        // newPosts = foundPosts.filter({newIds.contains($0[postInfos.id])})
        var allIds = postIds + self.savedPostIds
        allIds = allIds.unique()
        if (allIds.count > self.maxPostsSaved){
            allIds = Array(allIds[..<self.maxPostsSaved])
        }
        defaults.setValue(allIds, forKey: defaultsKeys.postIds)
        
        if self.newPostIds.count > 0 {
            // print(postIds)
            // print(self.newPostIds)
            self.debugText.text = self.foundPosts[0].joined(separator: " | ")
            AudioServicesPlaySystemSound(self.systemSoundID)
        }else {
            self.debugText.text = "no post found!"
        }
        
        DispatchQueue.main.async {
            self.listPosts.reloadData();
            
            // after we update the table view, we can update the list
            // self.savedPostIds = allIds
            self.setSavedPostIds(allIds)
        }
    }
    
    func backgroundSearch(){
        
            print("stop is clicked")
            self.foundPosts = get_craigslist_posts()
            
            //TODO: expand with new post
            
            //0: all, 1: link, 2: name, 3: image, 4: time, 5: id, 6: title
            let postIds = foundPosts.compactMap({ $0[postInfos.id] })
            self.newPostIds = postIds.difference(from: self.savedPostIds)
            // newPosts = foundPosts.filter({newIds.contains($0[postInfos.id])})
            var allIds = postIds + self.savedPostIds
            allIds = allIds.unique()
            if (allIds.count > maxPostsSaved){
                allIds = Array(allIds[..<maxPostsSaved])
            }
            defaults.setValue(allIds, forKey: defaultsKeys.postIds)
            
            if self.newPostIds.count > 0 {
                print(postIds)
                print(self.newPostIds)
                debugText.text = foundPosts[0].joined(separator: " | ")
                AudioServicesPlaySystemSound(systemSoundID)
            }else {
                debugText.text = "no post found!"
            }
            
            DispatchQueue.main.async {
                self.listPosts.reloadData();
                
                // after we update the table view, we can update the list
                // self.savedPostIds = allIds
                self.setSavedPostIds(allIds)
            }
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

//extension ViewController : UITextFieldDelegate, UITableViewDelegate {
//    
//}


//let testHTMLString = """
//<div class="open-map-view-button">
//    <span>see in map view</span>
//</div>
//<div id="mapcontainer" data-arealat="37.500000" data-arealon="-122.250000">
//    <div id="noresult-overlay"></div>
//    <div id="noresult-text">
//        <span class="message">No mappable items found</span>
//    </div>
//    <div id="map" class="loading">
//        <div class="close-full-screen-map-mode-button">close fullscreen</div>
//    </div>
//</div>
//
//                <ul class="rows" id="search-results">
//                             <li class="result-row" data-pid="7389562479">
//
//        <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-free-wheelchair-wheels/7389562479.html" class="result-image gallery" data-ids="3:00000_cAxwswGjAuNz_0lM0t2">
//        </a>
//
//    <div class="result-info">
//        <span class="icon icon-star" role="button">
//            <span class="screen-reader-text">favorite this post</span>
//        </span>
//
//            <time class="result-date" datetime="2021-10-04 13:24" title="Mon 04 Oct 01:24:30 PM">Oct  4</time>
//
//
//        <h3 class="result-heading">
//            <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-free-wheelchair-wheels/7389562479.html" data-id="7389562479" class="result-title hdrlnk" id="postid_7389562479" >FREE Wheelchair wheels</a>
//        </h3>
//
//        <span class="result-meta">
//
//
//                <span class="result-hood"> (santa clara)</span>
//
//                <span class="result-tags">
//                    <span class="pictag">pic</span>
//                    <span class="maptag">0.4mi</span>
//                </span>
//
//                <span class="banish icon icon-trash" role="button">
//                    <span class="screen-reader-text">hide this posting</span>
//                </span>
//
//            <span class="unbanish icon icon-trash red" role="button" aria-hidden="true"></span>
//            <a href="#" class="restore-link">
//                <span class="restore-narrow-text">restore</span>
//                <span class="restore-wide-text">restore this posting</span>
//            </a>
//
//        </span>
//    </div>
//</li>
//"""


//    func playSound() {
//        guard let url = Bundle.main.url(forResource: "beep", withExtension: "mp3") else {
//            print("beep not found")
//            return
//
//        }
//
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//            try AVAudioSession.sharedInstance().setActive(true)
//
//            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
//            self.audioPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
//
//            /* iOS 10 and earlier require the following line:
//            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
//
//            guard let audioPlayer = self.audioPlayer else { return }
//
//            audioPlayer.play()
//
//        } catch let error {
//            print(error.localizedDescription)
//        }
//    }

//    private func playAudioFromURL() {
//        guard let url = URL(string: "https://geekanddummy.com/wp-content/uploads/2014/01/coin-spin-light.mp3") else {
//            print("error to get the mp3 file")
//            return
//        }
//        do {
//            audioPlayer = try AVPlayer(url: url as URL)
//        } catch {
//            print("audio file error")
//        }
//        audioPlayer?.play()
//    }

//    private func playAudioFromProject() {
//        guard let url = Bundle.main.url(forResource: "azanMakkah2016", withExtension: "mp3") else {
//            print("error to get the mp3 file")
//            return
//        }
//
//        do {
//            audioPlayer = try AVPlayer(url: url)
//        } catch {
//            print("audio file error")
//        }
//        audioPlayer?.play()
//    }



//
//// playSound()
//// to play sound
//AudioServicesPlaySystemSound(systemSoundID)
//if let mileageInput = defaults.string(forKey: defaultsKeys.mileageInput) {
//    keywordsInput.text = mileageInput
//}else{
//    keywordsInput.text = mileageInput.text
//}
//defaults.set(mileageInput.text, forKey: defaultsKeys.mileageInput)
//
//var foundPosts =  Array<Array<String>>()
//
//do{
//    let test_string3 = """
//    <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-maytag-quiet-series/7366077748.html" class="result-image gallery" data-ids="3:00I0I_tut5vZ7ta5z_0t20CI,3:01616_5rlFzcb1C7vz_0t20CI,3:00B0B_2muJCiuJBR3z_0t20CI,3:00I0I_fMXkchJXgYOz_0t20CI">
//    </a>
//
//    <div class="result-info">
//        <span class="icon icon-star" role="button">
//            <span class="screen-reader-text">favorite this post</span>
//        </span>
//
//            <time class="result-date" datetime="2021-08-20 17:33" title="Fri 20 Aug 05:33:21 PM">Aug 20</time>
//
//
//        <h3 class="result-heading">
//            <a href="https://sfbay.craigslist.org/sby/zip/d/santa-clara-maytag-quiet-series/7366077748.html" data-id="7366077748" class="result-title hdrlnk" id="postid_7366077748" >Maytag quiet series</a>
//        </h3>
//    """
//    foundPosts = try searchForPosts(test_string3)
//    if(foundPosts.count > 0){
//        debugText.text = foundPosts[0].joined(separator: " | ")
//    }else{
//        debugText.text = "post not found.";
//    }
//} catch let error {
//    print("search failed")
//    debugText.text = "search failed \(error)"
//}
//
////0: all, 1: link, 2: name, 3: image, 4: time, 5: id, 6: title
//let id_idx = 5
//let postIds = foundPosts.compactMap({ $0[id_idx] })
//let existingPostIds = defaults.stringArray(forKey: defaultsKeys.postIds)!
//let newIds = postIds.difference(from: existingPostIds)
//newPosts = foundPosts.filter({newIds.contains($0[id_idx])})
//
//print("foundPosts")
//if(foundPosts.count > 0){
//    print(foundPosts[0][1])
//}
//print("existingPostIds")
//
////print(existingPostIds)
////print(newIds)
////print(newPosts)
//
//defaults.setValue(postIds, forKey: defaultsKeys.postIds)
//
//if newPosts.count > 0 {
//    notifications.post(name: Notification.Name("UserLoggedIn"), object: nil)
//
//}
//
////scheduledTimerWithTimeInterval()


//test_string2 == """
//    <div class="open-map-view-button">
//        <span>see in map view</span>
//    </div>
//    <div id="mapcontainer" data-arealat="37.500000" data-arealon="-122.250000">
//        <div id="noresult-overlay"></div>
//        <div id="noresult-text">
//            <span class="message">No mappable items found</span>
//        </div>
//        <div id="map" class="loading">
//            <div class="close-full-screen-map-mode-button">close fullscreen</div>
//        </div>
//    </div>
//
//                    <ul class="rows" id="search-results">
//                                 <li class="result-row" data-pid="7400210117">
//
//            <a href="https://sfbay.craigslist.org/eby/zip/d/fremont-christnas-tree-halloweeb-costume/7400210117.html" class="result-image gallery" data-ids="3:00a0a_8CtibmsjFegz_0t20CI">
//            </a>
//
//        <div class="result-info">
//            <span class="icon icon-star" role="button">
//                <span class="screen-reader-text">favorite this post</span>
//            </span>
//
//                <time class="result-date" datetime="2021-10-28 00:46" title="Thu 28 Oct 12:46:53 AM">Oct 28</time>
//
//
//            <h3 class="result-heading">
//                <a href="https://sfbay.craigslist.org/eby/zip/d/fremont-christnas-tree-halloweeb-costume/7400210117.html" data-id="7400210117" class="result-title hdrlnk" id="postid_7400210117" >christnas tree halloweeb costume</a>
//            </h3>
//
//            <span class="result-meta">
//
//
//                    <span class="result-hood"> (Fremont east bay area )</span>
//
//                    <span class="result-tags">
//                        <span class="pictag">pic</span>
//                        <span class="maptag">4.8mi</span>
//                    </span>
//
//                    <span class="banish icon icon-trash" role="button">
//                        <span class="screen-reader-text">hide this posting</span>
//                    </span>
//
//                <span class="unbanish icon icon-trash red" role="button" aria-hidden="true"></span>
//                <a href="#" class="restore-link">
//                    <span class="restore-narrow-text">restore</span>
//                    <span class="restore-wide-text">restore this posting</span>
//                </a>
//
//            </span>
//        </div>
//    </li>
//             <li class="result-row" data-pid="7400200966">
//
//            <a href="https://sfbay.craigslist.org/sby/zip/d/fremont-free-macys-sofa/7400200966.html" class="result-image gallery" data-ids="3:00Z0Z_h1zB1KxL5L5z_0CI0t2">
//            </a>
//
//        <div class="result-info">
//            <span class="icon icon-star" role="button">
//                <span class="screen-reader-text">favorite this post</span>
//            </span>
//
//                <time class="result-date" datetime="2021-10-27 22:52" title="Wed 27 Oct 10:52:04 PM">Oct 27</time>
//
//
//            <h3 class="result-heading">
//                <a href="https://sfbay.craigslist.org/sby/zip/d/fremont-free-macys-sofa/7400200966.html" data-id="7400200966" class="result-title hdrlnk" id="postid_7400200966" >Free Macy&#39;s sofa</a>
//            </h3>
//
//            <span class="result-meta">
//
//
//                    <span class="result-hood"> (milpitas)</span>
//
//                    <span class="result-tags">
//                        <span class="pictag">pic</span>
//                        <span class="maptag">2.5mi</span>
//                    </span>
//
//                    <span class="banish icon icon-trash" role="button">
//                        <span class="screen-reader-text">hide this posting</span>
//                    </span>
//
//                <span class="unbanish icon icon-trash red" role="button" aria-hidden="true"></span>
//                <a href="#" class="restore-link">
//                    <span class="restore-narrow-text">restore</span>
//                    <span class="restore-wide-text">restore this posting</span>
//                </a>
//
//            </span>
//        </div>
//    </li>
//    """
