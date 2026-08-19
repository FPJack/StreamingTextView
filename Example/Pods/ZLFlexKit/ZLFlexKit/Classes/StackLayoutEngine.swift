
import UIKit

// MARK: - Private Guide Subclasses

private final class TopGuide:      LayoutGuide {}
private final class LeadingGuide:  LayoutGuide {}
private final class BottomGuide:   LayoutGuide {}
private final class TrailingGuide: LayoutGuide {}

// MARK: - MargeGuide

/// 表示 stackView 四边加了 insets 之后的有效内容区域
final class MargeGuide: UILayoutGuide {

    weak var top:      NSLayoutConstraint?
    weak var leading:  NSLayoutConstraint?
    weak var bottom:   NSLayoutConstraint?
    weak var trailing: NSLayoutConstraint?

    init(view: UIView, insets: NSDirectionalEdgeInsets) {
        super.init()
        view.addLayoutGuide(self)

        let constraints = [
            topAnchor     .constraint(equalTo: view.topAnchor,      constant:  insets.top),
            leadingAnchor .constraint(equalTo: view.leadingAnchor,  constant:  insets.leading),
            bottomAnchor  .constraint(equalTo: view.bottomAnchor,   constant: -insets.bottom),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.trailing),
        ]
        top      = constraints[0]
        leading  = constraints[1]
        bottom   = constraints[2]
        trailing = constraints[3]
        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - StackEdgeInsets

final class StackLayoutEngine {

    weak var stackView: StackView?

    var insets: UIEdgeInsets = .zero {
        didSet {
            guard let guide = _margeGuide else { return }
            guard oldValue != insets else { return }
            guide.top?.constant      =  insets.top
            guide.leading?.constant  =  insets.left
            guide.bottom?.constant   = -insets.bottom
            guide.trailing?.constant = -insets.right
        }
    }

    // MARK: - Private lazy guides

    private var _topGuide:      LayoutGuide?
    private var _leadingGuide:  LayoutGuide?
    private var _bottomGuide:   LayoutGuide?
    private var _trailingGuide: LayoutGuide?
    private var _margeGuide:    MargeGuide?
    private var isRelativeLayout: Bool = false


    private var margeGuide: UILayoutGuide {
        if _margeGuide == nil, let sv = stackView {
            _margeGuide = MargeGuide(view: sv, insets: sv.insets)
        }
        return _margeGuide!
    }
    
    
   private func innerLeadingAnchor() ->
    NSLayoutXAxisAnchor {
        guard let stackView = stackView else { return margeGuide.leadingAnchor }
        return isRelativeLayout ?  margeGuide.leadingAnchor : stackView.leadingAnchor
    }
    private func innerTrailingAnchor() -> NSLayoutXAxisAnchor {
        guard let stackView = stackView else { return margeGuide.trailingAnchor }
        return isRelativeLayout ? margeGuide.trailingAnchor : stackView.trailingAnchor
    }
    private func innerTopAnchor() -> NSLayoutYAxisAnchor {
        guard let stackView = stackView else { return margeGuide.topAnchor }
        return isRelativeLayout ? margeGuide.topAnchor : stackView.topAnchor

    }
    private func innerBottomAnchor() -> NSLayoutYAxisAnchor {
        guard let stackView = stackView else { return margeGuide.bottomAnchor }
        return isRelativeLayout ? margeGuide.bottomAnchor : stackView.bottomAnchor
    }
    
    private func innerCenterXAnchor() -> NSLayoutXAxisAnchor {
        guard let stackView = stackView else { return margeGuide.centerXAnchor }
        return isRelativeLayout ? margeGuide.centerXAnchor : stackView.centerXAnchor
    }
    
    private func innerCenterYAnchor() -> NSLayoutYAxisAnchor {
        guard let stackView = stackView else { return margeGuide.centerYAnchor }
        return isRelativeLayout ? margeGuide.centerYAnchor : stackView.centerYAnchor
    }
        

    private var topGuide: LayoutGuide {
        if _topGuide == nil, let sv = stackView {
            let guide = TopGuide()
            sv.addLayoutGuide(guide)
            guide.topAnchor.constraint(equalTo: innerTopAnchor()).isActive = true
            _topGuide = guide
        }
        return _topGuide!
    }

    private var leadingGuide: LayoutGuide {
        if _leadingGuide == nil, let sv = stackView {
            let guide = LeadingGuide()
            sv.addLayoutGuide(guide)
            guide.leadingAnchor.constraint(equalTo: innerLeadingAnchor()).isActive = true
            _leadingGuide = guide
        }
        return _leadingGuide!
    }

    private var bottomGuide: LayoutGuide {
        if _bottomGuide == nil, let sv = stackView {
            let guide = BottomGuide()
            sv.addLayoutGuide(guide)
            guide.bottomAnchor.constraint(equalTo: innerBottomAnchor()).isActive = true
            _bottomGuide = guide
        }
        return _bottomGuide!
    }

    private var trailingGuide: LayoutGuide {
        if _trailingGuide == nil, let sv = stackView {
            let guide = TrailingGuide()
            sv.addLayoutGuide(guide)
            innerTrailingAnchor().constraint(equalTo: guide.trailingAnchor).isActive = true
            _trailingGuide = guide
        }
        return _trailingGuide!
    }

    // MARK: - Justify-aware anchors（考虑 justifyContent 的主轴起止锚点）

    var jLeadingAnchor: NSLayoutXAxisAnchor {
        switch stackView?.justifyContent {
        case .center, .spaceAround, .spaceEvenly:
            return leadingGuide.trailingAnchor
        default:
            return innerLeadingAnchor()
        }
    }

    var jTrailingAnchor: NSLayoutXAxisAnchor {
        switch stackView?.justifyContent {
        case .center, .spaceAround, .spaceEvenly:
            return trailingGuide.leadingAnchor
        default:
            return innerTrailingAnchor()
        }
    }

    var jTopAnchor: NSLayoutYAxisAnchor {
        switch stackView?.justifyContent {
        case .center, .spaceAround, .spaceEvenly:
            return topGuide.bottomAnchor
        default:
            return innerTopAnchor()
        }
    }

    var jBottomAnchor: NSLayoutYAxisAnchor {
        switch stackView?.justifyContent {
        case .center, .spaceAround, .spaceEvenly:
            return bottomGuide.topAnchor
        default:
            return innerBottomAnchor()
        }
    }

    // MARK: - Margin-aware anchors（始终指向 margeGuide）

    var leadingAnchor:  NSLayoutXAxisAnchor { innerLeadingAnchor()  }
    var trailingAnchor: NSLayoutXAxisAnchor { innerTrailingAnchor() }
    var topAnchor:      NSLayoutYAxisAnchor { innerTopAnchor()      }
    var bottomAnchor:   NSLayoutYAxisAnchor { innerBottomAnchor()   }
    var centerYAnchor:  NSLayoutYAxisAnchor { innerCenterYAnchor()  }
    var centerXAnchor:  NSLayoutXAxisAnchor { innerCenterXAnchor()  }

    // MARK: - Dimension anchors（用于 spaceAround / spaceEvenly 等宽/高分布）

    var widthAnchors: [NSLayoutDimension] {
        [leadingGuide.widthAnchor, trailingGuide.widthAnchor]
    }

    var heightAnchors: [NSLayoutDimension] {
        [topGuide.heightAnchor, bottomGuide.heightAnchor]
    }

    // MARK: - Cleanup

    func removeEdgeInsets() {
        _leadingGuide?.removeFromOwningView();  _leadingGuide  = nil
        _trailingGuide?.removeFromOwningView(); _trailingGuide = nil
        _topGuide?.removeFromOwningView();      _topGuide      = nil
        _bottomGuide?.removeFromOwningView();   _bottomGuide   = nil
    }
}
