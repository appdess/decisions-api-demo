import AppKit

// Code-drawn identity assets. Run from the repository root with xcrun swift.
let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let blue = NSColor(srgbRed:0.04,green:0.43,blue:0.77,alpha:1)
let ink = NSColor(srgbRed:0.10,green:0.17,blue:0.25,alpha:1)
func fill(_ color:NSColor, _ rect:NSRect) { color.setFill(); rect.fill() }
func diamonds(_ rect:NSRect, unit:CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect:rect).addClip()
    fill(.white,rect)
    for row in -2...12 {
        for column in -10...15 where (row + column).isMultiple(of:2) {
            let x = rect.minX + CGFloat(column) * unit + CGFloat(row) * unit * 0.5
            let y = rect.minY + CGFloat(row) * unit
            let path = NSBezierPath()
            path.move(to:NSPoint(x:x,y:y)); path.line(to:NSPoint(x:x+unit,y:y))
            path.line(to:NSPoint(x:x+unit*1.5,y:y+unit)); path.line(to:NSPoint(x:x+unit*0.5,y:y+unit)); path.close()
            blue.setFill(); path.fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
}
func emoji(_ rect:NSRect) {
    let string = "🥨" as NSString
    let attrs: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:rect.height * 0.88)]
    let size = string.size(withAttributes:attrs)
    string.draw(at:NSPoint(x:rect.midX-size.width/2,y:rect.midY-size.height/2),withAttributes:attrs)
}
func render(width:Int,height:Int,draw:() -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    draw(); NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
func save(_ bitmap:NSBitmapImageRep,_ path:String) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    try bitmap.representation(using:.png,properties:[:])!.write(to:url)
}
let names = ["Bavarian porcelain","Flag badge","Alpine blue"]
let files = ["bavarian-porcelain","flag-badge","alpine-blue"]
let icons = (0..<3).map { variant in
    render(width:1024,height:1024) {
        let all = NSRect(x:0,y:0,width:1024,height:1024)
        if variant == 0 {
            fill(NSColor(srgbRed:0.97,green:0.98,blue:1,alpha:1),all)
            diamonds(NSRect(x:0,y:0,width:1024,height:260),unit:150)
            fill(.white,NSRect(x:0,y:254,width:1024,height:6))
            emoji(NSRect(x:140,y:300,width:744,height:650))
        } else if variant == 1 {
            diamonds(all,unit:170)
            NSColor.white.setFill(); NSBezierPath(ovalIn:NSRect(x:150,y:150,width:724,height:724)).fill()
            emoji(NSRect(x:210,y:235,width:604,height:580))
        } else {
            fill(blue,all)
            let p = NSBezierPath(); p.move(to:NSPoint(x:370,y:900)); p.line(to:NSPoint(x:875,y:635))
            p.line(to:NSPoint(x:655,y:120)); p.line(to:NSPoint(x:150,y:385)); p.close()
            NSColor.white.setFill(); p.fill()
            emoji(NSRect(x:220,y:270,width:584,height:540))
        }
    }
}
for (index,icon) in icons.enumerated() { try save(icon,"docs/brand/\(files[index]).png") }
try save(icons[1],"BakeryDecisions/Assets.xcassets/AppIcon.appiconset/pretzel-icon.png")
try save(icons[1],"BakeryDecisions/Assets.xcassets/BrandMark.imageset/brand-mark.png")
let board = render(width:1500,height:740) {
    fill(NSColor(srgbRed:0.94,green:0.96,blue:0.98,alpha:1),NSRect(x:0,y:0,width:1500,height:740))
    let titleAttrs: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:34,weight:.semibold),.foregroundColor:ink]
    ("Servus Snap" as NSString).draw(at:NSPoint(x:60,y:650),withAttributes:titleAttrs)
    for index in 0..<3 {
        let x = CGFloat(index)*480+60
        let image = NSImage(size:NSSize(width:1024,height:1024)); image.addRepresentation(icons[index])
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect:NSRect(x:x,y:260,width:360,height:360),xRadius:82,yRadius:82).addClip()
        image.draw(in:NSRect(x:x,y:260,width:360,height:360))
        NSGraphicsContext.restoreGraphicsState()
        (names[index] as NSString).draw(at:NSPoint(x:x,y:194),withAttributes:[.font:NSFont.systemFont(ofSize:26,weight:.medium),.foregroundColor:ink])
        let sizes: [CGFloat] = [72,48,32]
        var offset: CGFloat = 0
        for size in sizes {
            NSGraphicsContext.saveGraphicsState()
            let r = NSRect(x:x+offset,y:80,width:size,height:size)
            NSBezierPath(roundedRect:r,xRadius:size*0.22,yRadius:size*0.22).addClip(); image.draw(in:r)
            NSGraphicsContext.restoreGraphicsState(); offset += size+24
        }
    }
}
try save(board,"docs/brand/logo-options.png")
print("Rendered three logo variants, a comparison board, and the selected app icon.")
