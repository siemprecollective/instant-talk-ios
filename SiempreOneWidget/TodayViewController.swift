//
//  TodayViewController.swift
//  SiempreOneWidget
//

import UIKit
import NotificationCenter
//import Firebase

class TodayViewController: UIViewController, NCWidgetProviding,
UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var  collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //122FirebaseApp.configure()
        collectionView.dataSource = self
        collectionView.delegate = self
        // Do any additional setup after loading the view from its nib.
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    // MARK - Collection view data source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // TODO
        return UICollectionViewCell()    }
}
