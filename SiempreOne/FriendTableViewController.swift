//
//  FriendTableViewController.swift
//  SiempreOne
//

import UIKit
import PushKit
import Firebase
import TwilioVoice

class FriendTableViewController: UITableViewController, TVOCallDelegate, TVONotificationDelegate, PKPushRegistryDelegate {

    var appdelegate : AppDelegate!
    var pushRegistry: PKPushRegistry!
    var firestore : Firestore!

    var deviceToken : String?
    var friendsList : [[String : Any]]!
    var currentCallId : String?
    var currentCall : TVOCall?

    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil // TODO what does this mean?

    let baseServerURL = "BLANK"
    let accessTokenEndpoint = "accessToken"

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        appdelegate = UIApplication.shared.delegate as? AppDelegate
        pushRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
        firestore = Firestore.firestore()
        friendsList = []
        currentCallId = nil
        currentCall = nil

        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [PKPushType.voIP]

        let currentUserFriends = firestore.collection("users").whereField("friends", arrayContains: appdelegate.currentUserId!)
        currentUserFriends.addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching documents: \(error!)")
                return
            }
            self.friendsList = documents.map { doc in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }
            self.tableView.reloadData()
        }
        // TODO robust error handling
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendsList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FriendTableViewCell", for: indexPath) as? FriendTableViewCell else {
            fatalError("cell is not a FriendTableViewCell")
        }
        let id = friendsList[indexPath.row]["id"] as? String
        let name = friendsList[indexPath.row]["name"] as? String
        let status = friendsList[indexPath.row]["status"] as? Int
        cell.nameLabel.text = name
        if (id == currentCallId) {
          cell.availableView.backgroundColor = UIColor.blue
        } else if (status == 0) {
          cell.availableView.backgroundColor = UIColor.green
        } else if (status == 1) {
          cell.availableView.backgroundColor = UIColor.yellow
        } else {
          cell.availableView.backgroundColor = UIColor.red
        }
        
        if (id == currentCallId) {
          cell.endCallButton.isHidden = false
        } else {
          cell.endCallButton.isHidden = true
        }
        return cell
    }

    // MARK - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.checkRecordPermission { granted in
            if (!granted) {
                return
            }
            guard let accessToken = self.fetchAccessToken() else {
                return
            }
            let toId = self.friendsList[indexPath.row]["id"] as? String
            let toIdentity = self.identityForId(id: toId!)
            let connectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
                builder.params = ["to" : toIdentity]
            }
            self.currentCallId = toId
            self.currentCall = TwilioVoice.connect(with: connectOptions, delegate: self)
            self.startCall()
            print("calling "+self.currentCallId!)
        }
    }

    @IBAction func endCallPressed(_ sender: Any) {
        currentCall!.disconnect()
        finishCall()
    }
    // MARK: - PKPushRegistryDelegate

     func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        if (type != .voIP) {
            return
        }
        guard let accessToken = fetchAccessToken() else {
            return
        }
        let newDeviceToken = (credentials.token as NSData).description
        TwilioVoice.register(withAccessToken: accessToken, deviceToken: newDeviceToken) { (error) in
            if let error = error {
                print("An error occurred while registering: \(error.localizedDescription)")
                return
            }
            self.deviceToken = newDeviceToken
            print("Successfully registered for VoIP push notifications.")
        }
     }

     func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        if (type != .voIP) {
            return
        }
        guard let accessToken = fetchAccessToken() else {
            return
        }
        TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: self.deviceToken!) { (error) in
            if let error = error {
                print("An error occurred while unregistering: \(error.localizedDescription)")
                return
            }
                print("Successfully unregistered from VoIP push notifications.")
        }
        self.deviceToken = nil
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        // Save for later when the notification is properly handled.
        self.incomingPushCompletionCallback = completion
        if (type == PKPushType.voIP) {
            print("got VoIP push")
            // gets passed off to TVONotificationDelegate methods
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }

    func incomingPushHandled() {
        if let completion = self.incomingPushCompletionCallback {
            completion()
            self.incomingPushCompletionCallback = nil
        }
    }

    // MARK: - TVOCallDelegate

    func callDidConnect(_ call: TVOCall) {
        print("call connected to "+currentCallId!)
    }

    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        print("call failed to connect to "+currentCallId!+" with error")
        print(error)
        finishCall()
    }

    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        print("call to "+currentCallId!+" disconnected")
        finishCall()
    }

    // MARK: - TVONotificationDelegate

    func callInviteReceived(_ callInvite: TVOCallInvite) {
        if (currentCall != nil) {
            callInvite.reject()
        }
        // TODO reject if not available, ring if interruptible
        let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: callInvite) { (builder) in
            builder.uuid = callInvite.uuid
        }
        currentCallId = self.idForIdentity(identity: callInvite.from!) // TODO
        currentCall = callInvite.accept(with: acceptOptions, delegate: self)
        startCall()
    }

    func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
        finishCall()
    }

    // MARK: - Helpers
    
    func startCall() {
        self.tableView.reloadData()
    }
    
    func finishCall() {
        currentCall = nil
        currentCallId = nil
        self.tableView.reloadData()
    }
    
    func identityForId(id: String) -> String {
        return id + "a"
    }
    
    func idForIdentity(identity: String) -> String {
        return String(identity.prefix(4))
    }

    func fetchAccessToken() -> String? {
        // TODO why the a?
        let identity = self.identityForId(id: appdelegate.currentUserId!)
        let endpointWithIdentity = String(format: "%@?platform=ios&identity=%@", accessTokenEndpoint, identity)
        let accessTokenURL = URL(string: baseServerURL + endpointWithIdentity)!
        return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
    }

    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
        switch permissionStatus {
        case AVAudioSession.RecordPermission.granted:
            // Record permission already granted.
            completion(true)
            break
        case AVAudioSession.RecordPermission.denied:
            // Record permission denied.
            completion(false)
            break
        case AVAudioSession.RecordPermission.undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                completion(granted)
            })
            break
        default:
            completion(false)
            break
        }
    }
}
