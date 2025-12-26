import UIKit
import AsyncDisplayKit
import Display

public final class ViewController: UIViewController {

    private let switchNode = SwitchNode()
    // You might need a wrapper node if SwitchNode expects to be in a hierarchy, 
    // but looking at source it seems to inherit ASDisplayNode.

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        // Add a colorful background to verify glass effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.addSublayer(gradientLayer)

        let label = UILabel()
        label.text = "SwitchNode Test"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 100, width: view.bounds.width, height: 50)
        view.addSubview(label)

        // Setup Switch Node
        // SwitchNode usually needs layout.
        // Let's wrap it in a container views or just frame it.
        
        addSubnode(switchNode)
        
        // Force initial frame
        let switchSize = CGSize(width: 51, height: 31) // Standard iOS switch size approx
        switchNode.frame = CGRect(
            x: (view.bounds.width - switchSize.width) / 2,
            y: (view.bounds.height - switchSize.height) / 2,
            width: switchSize.width,
            height: switchSize.height
        )
        
        // SwitchNode might need manual sizing call if it calculates its own size
        // switchNode.measure(CGSize(width: 100, height: 100)) 
        
        // Add a toggle button to change colors or state?
        // SwitchNode handles taps itself likely.
    }
    
    // Helper to bridge ASDisplayNode
    private func addSubnode(_ node: ASDisplayNode) {
        view.addSubview(node.view)
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Center it
        let size = CGSize(width: 51, height: 31)
         switchNode.frame = CGRect(
             x: (view.bounds.width - size.width) / 2,
             y: (view.bounds.height - size.height) / 2,
             width: size.width,
             height: size.height
         )
    }
}
