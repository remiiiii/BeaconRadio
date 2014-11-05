//
//  ParticleView.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 31/10/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//


class ParticleView: UIView {
    var dataSource: ParticleViewDataSource?
    var particleSize: Double = 10.0 {
        didSet {
            if self.particleSize > 0 {
                self.particleSize = oldValue
            }
        }
    }
    
    private var arrowHeadAngle: Double {
        get {
            return 90.0
        }
    }
    
    private var arrowHeadSize: Double {
        get {
            return self.particleSize * 0.3
        }
    }
    
    var lineWidth: Double = 1.0 {
        didSet {
            if self.lineWidth < 1.0 {
                self.lineWidth = 1.0
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func drawRect(rect: CGRect) {
        // draw particles
        if let dataSource = self.dataSource {
            let particles = dataSource.particlesForParticleView(self)
            
            for particle in particles {
                if isParticleInRect(particle, rect: rect) {
                    drawParticle(particle)
                }
            }
        }
    }
    
    private func isParticleInRect(particle:Particle, rect:CGRect) -> Bool {
        
        let tail = pointOfParticleTail(particle)
        let head = centerPointOfParticleHead(particle)
        let right = rightPointOfParticleHead(head: head, particle: particle)
        let left = leftPointOfParticleHead(head: head, particle: particle)
        
        
        return CGRectContainsPoint(rect, tail) && CGRectContainsPoint(rect, head) && CGRectContainsPoint(rect, right) && CGRectContainsPoint(rect, left)
    }
    
    private func drawParticle(particle: Particle) {
        
        let tail = pointOfParticleTail(particle)
        let head = centerPointOfParticleHead(particle)
        let right = rightPointOfParticleHead(head: head, particle: particle)
        let left = leftPointOfParticleHead(head: head, particle: particle)
        
        // drawing code goes here
        let context = UIGraphicsGetCurrentContext()
        CGContextSetStrokeColorWithColor(context, UIColor.redColor().CGColor)
        CGContextSetLineWidth(context, CGFloat(self.lineWidth))
        
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, tail.x, tail.y)
        CGContextAddLineToPoint(context, head.x, head.y)
        CGContextAddLineToPoint(context, right.x, right.y)
        
        CGContextMoveToPoint(context, head.x, head.y)
        CGContextAddLineToPoint(context, left.x, left.y)
        
        CGContextDrawPath(context, kCGPathStroke)
        
    }
    
    private func pointOfParticleTail(particle: Particle) -> CGPoint {
        let angle: Double = degree2Rad(Double(particle.orientation)/10 + 180.0)
        let x = Double(particle.x) + sin(angle) * (Double(self.particleSize) * 0.5)
        let y = Double(particle.y) + cos(angle) * (Double(self.particleSize) * 0.5)
        
        return CGPoint(x: x, y: y)
    }
    
    private func centerPointOfParticleHead(particle: Particle) -> CGPoint {
        let angle: Double = degree2Rad(Double(particle.orientation)/10)
        let x = Double(particle.x) + sin(angle) * (Double(self.particleSize) * 0.5)
        let y = Double(particle.y) + cos(angle) * (Double(self.particleSize) * 0.5)
        
        return CGPoint(x: x, y: y)
    }
    
    private func leftPointOfParticleHead(head point: CGPoint, particle: Particle) -> CGPoint {
        var angle: Double = (Double(particle.orientation)/10 + self.arrowHeadAngle/2)%360
        
        if angle < 0 {
            angle = 360 + angle
        }
        
        return pointOfParticleArrowHeadForAngle(angle, withHeadCenterPoint: point)
    }
    
    private func rightPointOfParticleHead(head point: CGPoint, particle: Particle) -> CGPoint {
        var angle: Double = (Double(particle.orientation)/10 - self.arrowHeadAngle/2) % 360
        
        if angle < 0 {
            angle = 360 + angle
        }
        
        return pointOfParticleArrowHeadForAngle(angle, withHeadCenterPoint: point)
    }
    
    private func pointOfParticleArrowHeadForAngle(angle: Double, withHeadCenterPoint point: CGPoint) -> CGPoint {
        let deltaX = abs(self.arrowHeadSize * sin(degree2Rad(angle)))
        let deltaY = abs(self.arrowHeadSize * cos(degree2Rad(angle)))
        
        var x: Double
        var y: Double
        
        if angle >= 0 && angle < 90 {
            x = Double(point.x) - deltaX
            y = Double(point.y) + deltaY
        } else if angle < 180 {
            x = Double(point.x) - deltaX
            y = Double(point.y) - deltaY
        }
        else if angle < 270 {
            x = Double(point.x) + deltaX
            y = Double(point.y) - deltaY
        }
        else {
            x = Double(point.x) + deltaX
            y = Double(point.y) + deltaY
        }
        return CGPoint(x: x, y: y)
    }
    
    private func degree2Rad(deg: Double) -> Double {
        let angle = (deg + 180 % 360)
        return -1 * (angle * M_PI / 180.0) % (2 * M_PI)
    }
    
}

protocol ParticleViewDataSource {
    func particlesForParticleView(particleView:ParticleView) -> [Particle]
}
