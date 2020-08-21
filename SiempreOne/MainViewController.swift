//
//  MainViewController.swift
//  SiempreOne
//


import UIKit
import Firebase

class MainViewController: UIViewController {

    @IBOutlet weak var availabilitySelector: UISegmentedControl!

    var appdelegate : AppDelegate!
    var firestore: Firestore!

    override func viewDidLoad() {
        super.viewDidLoad()
        appdelegate = UIApplication.shared.delegate as? AppDelegate
        firestore = Firestore.firestore()
        // firebase load last availability
        let currentUserDoc = firestore.collection("users").document(appdelegate.currentUserId!)
        currentUserDoc.getDocument { (document, error) in
            if let document = document, document.exists {
                self.availabilitySelector.selectedSegmentIndex = document.data()!["status"] as! Int // TODO this seems unsafe
            } else {
                print("Error getting previous status") // TODO robust error handling
            }
        }
    }

    @IBAction func availabilityChanged(_ sender: Any) {
        let selector = (sender as? UISegmentedControl)!
        let currentUserDoc = firestore.collection("users").document(appdelegate.currentUserId!)
        currentUserDoc.updateData(["status": selector.selectedSegmentIndex])
        // TODO robust error handling
        // TODO firebase set availability
    }

    @IBAction func logoutPressed(_ sender: Any) {
        // TODO don't delete the whole configuration? just clear user
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("No document directory found in application bundle.")
        }
        let configFile = documentsDirectory.appendingPathComponent("Configuration.plist")
        let emptyData = Data()
        try! emptyData.write(to: configFile)
        self.performSegue(withIdentifier: "LoggedoutSegue", sender: nil)
    }
}
