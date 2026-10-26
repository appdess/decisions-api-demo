import SwiftUI
import PhotosUI

struct BakeryView: View {
    @StateObject private var model = DemoModel()
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = false
    @State private var inspect = false
    @State private var cameraVisible = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoTask: Task<Void,Never>?
    @State private var inputRevision = UUID()
    @State private var cameraRevision = UUID()
    @State private var importing = false

    var body: some View {
        ZStack {
            BakeryBackdrop()
            VStack(spacing:20) {
                header
                if cameraVisible { captureScreen } else { welcomeScreen }
            }.padding(.horizontal,24).padding(.top,10).padding(.bottom,16)
                .accessibilityHidden(model.decision != nil)
                .allowsHitTesting(model.decision == nil)
            if let decision = model.decision { resultScreen(decision) }
            if scenePhase != .active { Color.bakeryBG.ignoresSafeArea().overlay { Text("Pretzel").font(.title).foregroundStyle(Color.bakeryInk) } }
        }
        .foregroundStyle(Color.bakeryInk)
        .task { if model.hasKey { await DecisionClient.prepareConnection() } }
        .sheet(isPresented:$settings) { SettingsView(model:model) }
        .sheet(isPresented:$inspect) {
            NavigationStack {
                ScrollView { Text(model.raw).font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding() }
                    .navigationTitle("Returned answers").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { inspect = false } }
            }.tint(Color.bakeryAccent)
        }
        .onChange(of:model.fixture) { _, _ in clearInputTasks(); camera.stop(); photoItem = nil }
        .onChange(of:model.mode) { _, _ in clearInputTasks() }
        .onChange(of:scenePhase) { _, phase in
            if phase != .active { clearInputTasks(); camera.stop(); model.reset(); photoItem = nil }
        }
        .onChange(of:photoItem) { _, item in loadPhoto(item) }
        .onDisappear { clearInputTasks(); camera.stop(); model.reset() }
    }
    private var header: some View {
        HStack {
            if cameraVisible {
                Button { goHome() } label: { Image(systemName:"arrow.left").frame(width:44,height:44).modifier(GlassSurface(radius:22)) }
                    .accessibilityLabel("Choose mode").accessibilityIdentifier("home")
            }
            Spacer()
            Button { model.reset(); camera.stop(); clearInputTasks(); settings = true } label: {
                Image(systemName:"slider.horizontal.3").frame(width:44,height:44).modifier(GlassSurface(radius:22))
            }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
        }.buttonStyle(.plain)
    }
    private var welcomeScreen: some View {
        VStack(spacing:18) {
            Spacer(minLength:0)
            VStack(spacing:10) {
                Text("🥨").font(.system(size:46)).accessibilityHidden(true)
                Text("Pretzel").font(.system(size:30,weight:.medium,design:.rounded)).tracking(-1)
            }.padding(.bottom,12)
            modeCard(.binary,title:"Pretzel or not?")
            modeCard(.choice,title:"Classify")
            Button { openMode(.crowd) } label: {
                HStack(spacing:12) {
                    Image(systemName:"person.3.sequence").font(.system(size:20))
                    Text("Audience gestures").font(.system(size:15,weight:.medium))
                    Spacer()
                    Image(systemName:"arrow.up.right").font(.system(size:13))
                }.foregroundStyle(Color.bakeryMuted).padding(20).modifier(GlassSurface(radius:24))
            }.buttonStyle(.plain).accessibilityIdentifier("crowd")
            Spacer(minLength:0)
        }
    }
    private func openMode(_ mode:BakeryMode) {
        model.mode = mode; cameraVisible = true
        if !model.fixture { startCamera() }
    }
    private func modeCard(_ mode: BakeryMode,title:String) -> some View {
        Button { openMode(mode) } label: {
            VStack(alignment:.leading,spacing:18) {
                HStack(spacing:22) {
                    if mode == .binary {
                        pretzelOption(yes:true)
                        pretzelOption(yes:false)
                    } else {
                        Text("🍩"); Text("🥐"); Text("🥨")
                    }
                }.font(.system(size:45)).frame(maxWidth:.infinity).accessibilityHidden(true)
                HStack {
                    Text(title).font(.system(size:21,weight:.semibold,design:.rounded))
                    Spacer()
                    Image(systemName:"arrow.up.right").font(.system(size:16,weight:.medium)).foregroundStyle(Color.bakeryMuted)
                }
            }.padding(24).frame(maxWidth:.infinity,alignment:.leading).modifier(GlassSurface(radius:30))
        }.buttonStyle(.plain).accessibilityLabel(title)
            .accessibilityHint(mode == .binary ? "Opens the camera for a yes or no pretzel check" : "Opens the camera to identify pretzels, croissants, bread rolls, doughnuts, cookies or other food")
            .accessibilityIdentifier(mode.rawValue)
    }
    private func pretzelOption(yes:Bool) -> some View {
        Text("🥨").overlay(alignment:.bottomTrailing) {
            Image(systemName:yes ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size:22,weight:.semibold)).symbolRenderingMode(.palette)
                .foregroundStyle(.white,yes ? Color(red:0.08,green:0.53,blue:0.34) : Color(red:0.8,green:0.18,blue:0.24))
                .offset(x:10,y:4)
        }
    }
    private var captureScreen: some View {
        VStack(spacing:18) {
            Text(model.mode == .choice ? "What is it?" : model.mode.prompt).font(.system(size:29,weight:.medium,design:.rounded)).tracking(-0.8)
            ZStack {
                RoundedRectangle(cornerRadius:32).fill(.white.opacity(0.24))
                if model.fixture {
                    if model.mode == .crowd {
                        VStack(spacing:18) { Image(systemName:"figure.arms.open").font(.system(size:110,weight:.ultraLight)); Text("Gesture illustration").font(.caption) }.foregroundStyle(Color.bakeryMuted)
                    } else { Image("pretzel").resizable().scaledToFit() }
                }
                else if let photo=model.photo { Image(uiImage:photo).resizable().scaledToFit() }
                else if camera.running { CameraPreview(session:camera.session) }
                else {
                    VStack(spacing:18) {
                        Image(systemName:"viewfinder").font(.system(size:68,weight:.ultraLight)).foregroundStyle(Color.bakeryAccent.opacity(0.65))
                        Text(camera.message ?? (model.mode == .crowd ? "Frame visible audience gestures." : "Frame one item.")).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Color.bakeryMuted).padding(.horizontal,30)
                    }
                }
                if model.fixture {
                    VStack { Text("ILLUSTRATIVE SAMPLE").font(.system(size:10,weight:.semibold)).tracking(1.2).padding(12).background(.regularMaterial,in:Capsule()); Spacer() }.padding(16)
                }
                if model.busy || importing {
                    VStack(spacing:16) {
                        ProgressView().controlSize(.large)
                        Text(importing ? "Opening photo…" : "Checking…").font(.subheadline)
                        Button("Cancel") { clearInputTasks(); model.reset(); photoItem = nil }.font(.caption)
                    }.padding(30).modifier(GlassSurface())
                }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:32))
                .overlay(RoundedRectangle(cornerRadius:32).stroke(.white.opacity(0.85),lineWidth:1))
            if let error=model.error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center).accessibilityIdentifier("error") }
            if !model.hasKey && !model.fixture { Button("Add demo API key") { settings=true }.font(.subheadline) }
            HStack {
                PhotosPicker(selection:$photoItem,matching:.images,photoLibrary:.shared()) {
                    Image(systemName:"photo.on.rectangle").font(.system(size:21)).frame(width:52,height:52).modifier(GlassSurface(radius:26))
                }.accessibilityLabel("Choose photo").accessibilityIdentifier("photos").disabled(model.fixture || model.busy || importing)
                Spacer()
                Button {
                    if model.fixture || model.photo != nil { model.decide() }
                    else if camera.running { cameraRevision = inputRevision; camera.capture() }
                    else { startCamera() }
                } label: {
                    ZStack {
                        Circle().stroke(Color.bakeryInk.opacity(0.7),lineWidth:1.5).frame(width:80,height:80)
                        Circle().fill(Color.bakeryInk).frame(width:66,height:66)
                        Image(systemName:model.fixture ? "play.fill" : "camera.fill").font(.system(size:22)).foregroundStyle(.white)
                    }
                }.accessibilityLabel(model.fixture ? "Try sample" : camera.running ? "Take photo and classify" : "Open camera")
                    .accessibilityIdentifier("shutter").disabled(model.busy || importing || camera.capturing)
                Spacer()
                Color.clear.frame(width:52,height:52).accessibilityHidden(true)
            }.buttonStyle(.plain)
            Text(model.fixture ? "Hand-authored answer · no API call" : model.mode == .crowd ? "Visible gestures only · photo not saved" : "Take a photo to classify").font(.caption).foregroundStyle(Color.bakeryMuted)
        }
    }
    private func resultScreen(_ decision:BakeryDecision) -> some View {
        let tint: Color = decision.outcome == .positive && model.mode == .crowd ? Color.bakeryAccent : decision.outcome == .positive ? Color(red:0.08,green:0.53,blue:0.34) : decision.outcome == .negative ? Color(red:0.8,green:0.18,blue:0.24) : Color(red:0.64,green:0.42,blue:0.07)
        let headline = decision.outcome == .review ? "Check manually" : (model.mode == .choice || model.mode == .crowd) ? decision.title : decision.outcome == .positive ? "Yes" : "No"
        return ZStack {
            BakeryBackdrop()
            VStack(spacing:22) {
                HStack {
                    Button { goHome() } label: { Image(systemName:"arrow.left").frame(width:44,height:44).modifier(GlassSurface(radius:22)) }.accessibilityLabel("Choose mode")
                    Spacer()
                    Text(model.fixture ? "SAMPLE" : "RESULT").font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(Color.bakeryMuted)
                }
                Spacer(minLength:10)
                VStack(spacing:24) {
                    Image(systemName:decision.outcome == .positive ? "checkmark" : decision.outcome == .negative ? "xmark" : "questionmark")
                        .font(.system(size:45,weight:.medium)).foregroundStyle(tint).frame(width:100,height:100)
                        .background(tint.opacity(0.09),in:Circle()).accessibilityHidden(true)
                    Text(headline).font(.system(size:49,weight:.semibold,design:.rounded)).tracking(-1.8).minimumScaleFactor(0.55).lineLimit(1).foregroundStyle(tint).accessibilityIdentifier("decisionSignal")
                    if model.mode != .choice && model.mode != .crowd && decision.outcome != .review { Text(decision.title).font(.title3).accessibilityIdentifier("decisionTitle") }
                    if decision.outcome == .review || model.mode == .crowd { Text(decision.detail).font(.subheadline).foregroundStyle(Color.bakeryMuted).multilineTextAlignment(.center) }
                    if let ms=model.apiMilliseconds { Text(String(format:"API processing · %.0f ms",ms)).font(.system(.caption,design:.monospaced)).foregroundStyle(Color.bakeryMuted) }
                    if model.fixture { Text("Hand-authored answer · no API call").font(.caption).foregroundStyle(Color.bakeryMuted) }
                }.padding(.vertical,38).padding(.horizontal,24).frame(maxWidth:.infinity).modifier(GlassSurface(radius:34))
                Button { inspect=true } label: { Label("Details",systemImage:"chevron.left.forwardslash.chevron.right") }.font(.caption).foregroundStyle(Color.bakeryMuted)
                Spacer(minLength:10)
                Button { if model.fixture { model.reset() } else { startCamera() } } label: {
                    HStack { Image(systemName:"camera"); Text("Next photo"); Spacer(); Image(systemName:"arrow.right") }.font(.system(size:17,weight:.medium)).padding(22).modifier(GlassSurface(radius:26))
                }.accessibilityIdentifier("next")
            }.padding(24).buttonStyle(.plain)
        }
    }
    private func clearInputTasks() { inputRevision=UUID(); photoTask?.cancel(); photoTask=nil; importing=false }
    private func goHome() { clearInputTasks(); camera.stop(); model.reset(); photoItem=nil; cameraVisible=false }
    private func startCamera() {
        clearInputTasks(); model.reset(); photoItem=nil
        camera.onPhoto = { image in
            guard cameraRevision == inputRevision, !model.fixture, scenePhase == .active else { return }
            camera.stop(); model.submitPhoto(image)
        }
        camera.start()
    }
    private func loadPhoto(_ item:PhotosPickerItem?) {
        clearInputTasks()
        guard let item else { return }
        camera.stop(); model.reset(); importing=true
        let token=inputRevision
        photoTask=Task { @MainActor in
            defer { if token == inputRevision { importing=false } }
            do {
                guard let data=try await item.loadTransferable(type:Data.self), !Task.isCancelled, token == inputRevision else { return }
                guard data.count <= 25_000_000, let image=UIImage(data:data) else { model.error="Choose a readable image under 25 MB."; return }
                model.submitPhoto(image,label:"SELECTED PHOTO")
            } catch { if token == inputRevision { model.error="Unable to load the photo." } }
        }
    }
}
struct SettingsView: View {
    @ObservedObject var model: DemoModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Demo") {
                    Toggle("Illustrative sample",isOn:$model.fixture)
                    Text("Pretzel · 1.2 (3)").font(.caption).foregroundStyle(.secondary)
                }
                Section("Demo API access") {
                    Label(model.hasKey ? "Key stored on this device" : "No API key configured",systemImage:model.hasKey ? "key.fill" : "key")
                    SecureField("Paste demo-project API key",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive().accessibilityIdentifier("apiKey")
                    Button("Save key") { do { try model.saveKey(key); key = ""; message = "Saved in Keychain. Account identity is not verified by the app." } catch { message = error.localizedDescription } }.disabled(key.isEmpty)
                    if model.hasKey { Button("Remove stored key",role:.destructive) { do { try model.removeKey(); message = "Key removed." } catch { message = error.localizedDescription } } }
                    if let message { Text(message).font(.footnote) }
                }
                Section { Text("Use your own key with Decisions Write permission. Keys are stored in this device's Keychain and sent only to api.openai.com. No key is included in the app.").font(.footnote) } header: { Text("Personal demo") } footer: { Text("API usage is billable. A production app should keep service credentials on a backend.") }
                Section("Application policy") { Text("Accept ≥ 0.80; negative ≤ 0.20. Choice additionally requires confidence ≥ 0.60. These are demo thresholds, not calibrated accuracy.").font(.footnote); Text("Unclear, multiple-food-item, refused and malformed answers go to manual review. Fixtures use hand-authored answers; live errors never substitute fixtures.").font(.footnote) }
            }.navigationTitle("Settings").toolbar { Button("Done") { key = ""; dismiss() } }.tint(Color.bakeryAccent)
        }
    }
}
