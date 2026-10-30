import SwiftUI
import PhotosUI

struct BakeryView: View {
    @StateObject private var model = DemoModel()
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = false
    @State private var inspect = false
    @State private var example = false
    @State private var cameraVisible = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoTask: Task<Void,Never>?
    @State private var inputRevision = UUID()
    @State private var cameraRevision = UUID()
    @State private var cameraSlot = 0
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
            if scenePhase != .active { Color.bakeryBG.ignoresSafeArea().overlay { Text("Servus Snap").font(.title).foregroundStyle(Color.bakeryInk) } }
        }
        .foregroundStyle(Color.bakeryInk)
        .task { if model.hasKey { await DecisionClient.prepareConnection() } }
        .sheet(isPresented:$settings) { SettingsView(model:model) }
        .sheet(isPresented:$example) {
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        Text("Lederhosen vs. shorts").font(.headline)
                        Text("Saved iPhone example · 30 October 2026").font(.caption).foregroundStyle(.secondary)
                        Image("BattleExample").resizable().scaledToFit()
                            .accessibilityLabel("Saved result: Photo A, Lederhosen, has a stronger Bavarian association than Photo B, shorts. The screenshot displays 100 percent for Photo A and 515 milliseconds API processing time.")
                        Text("This screenshot shows the earlier More Bavarian label. The feature is now called Bavarian Battle. The displayed probabilities belong to this example.").font(.footnote).foregroundStyle(.secondary)
                    }.padding()
                }.navigationTitle("Example result").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { example=false } }
            }.tint(Color.bakeryAccent)
        }
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
                Button { goHome() } label: { Image(systemName:"arrow.left").frame(width:44,height:44).contentShape(Circle()).modifier(GlassSurface(radius:22)) }
                    .accessibilityLabel("Choose mode").accessibilityIdentifier("home")
            }
            Spacer()
            Button { model.reset(); camera.stop(); clearInputTasks(); settings = true } label: {
                Image(systemName:"slider.horizontal.3").frame(width:44,height:44).contentShape(Circle()).modifier(GlassSurface(radius:22))
            }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
        }.buttonStyle(.plain)
    }
    private var welcomeScreen: some View {
        VStack(spacing:18) {
            Spacer(minLength:0)
            VStack(spacing:10) {
                Image("BrandMark").resizable().frame(width:66,height:66).clipShape(RoundedRectangle(cornerRadius:18)).accessibilityHidden(true)
                Text("Servus Snap").font(.system(size:30,weight:.medium,design:.rounded)).tracking(-1)
            }.padding(.bottom,12)
            modeCard(.bavarian,title:BakeryMode.bavarian.title)
            modeCard(.binary,title:"Pretzel or not?")
            modeCard(.choice,title:"Classify")
            Spacer(minLength:0)
            HStack(spacing:24) {
                Button { example=true } label: { Label("Example result",systemImage:"photo") }
                    .accessibilityIdentifier("exampleResult")
                Link(destination:URL(string:"https://github.com/appdess/decisions-api-demo/issues/new")!) {
                    Label("Report an issue",systemImage:"ladybug")
                }.accessibilityIdentifier("reportIssue")
            }.font(.caption).foregroundStyle(Color.bakeryMuted).buttonStyle(.plain)
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
                    } else if mode == .bavarian {
                        bavarianOption(yes:true)
                        bavarianOption(yes:false)
                    } else {
                        Text("🍩"); Text("🥐"); Text("🥨")
                    }
                }.font(.system(size:45)).frame(maxWidth:.infinity).accessibilityHidden(true)
                HStack {
                    Text(title).font(.system(size:21,weight:.semibold,design:.rounded))
                    Spacer()
                    Image(systemName:"arrow.up.right").font(.system(size:16,weight:.medium)).foregroundStyle(Color.bakeryMuted)
                }
            }.padding(24).frame(maxWidth:.infinity,alignment:.leading).contentShape(RoundedRectangle(cornerRadius:30)).modifier(GlassSurface(radius:30))
        }.buttonStyle(.plain).accessibilityLabel(title)
            .accessibilityHint(mode == .bavarian ? "Opens the camera to compare two photos of any objects or scenes" : mode == .binary ? "Opens the camera for a yes or no pretzel check" : "Opens the camera to identify pretzels, croissants, bread rolls, doughnuts, cookies or other objects")
            .accessibilityIdentifier(mode.rawValue)
    }
    private func pretzelOption(yes:Bool) -> some View {
        Text("🥨").overlay(alignment:.bottomTrailing) {
            optionBadge(yes:yes)
        }
    }
    private func bavarianOption(yes:Bool) -> some View {
        BavarianFlag().frame(width:58,height:44).clipShape(RoundedRectangle(cornerRadius:8))
            .overlay(alignment:.bottomTrailing) { optionBadge(yes:yes) }
    }
    private func optionBadge(yes:Bool) -> some View {
        Image(systemName:yes ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size:22,weight:.semibold)).symbolRenderingMode(.palette)
            .foregroundStyle(.white,yes ? Color(red:0.08,green:0.53,blue:0.34) : Color(red:0.8,green:0.18,blue:0.24))
            .offset(x:10,y:4)
    }
    private var captureScreen: some View {
        VStack(spacing:18) {
            Text(model.mode == .choice ? "What is it?" : model.mode.prompt).font(.system(size:29,weight:.medium,design:.rounded)).tracking(-0.8)
                .minimumScaleFactor(0.7).lineLimit(1)
            if model.mode == .bavarian {
                HStack(spacing:12) { comparisonSlot(0); comparisonSlot(1) }
                Text(model.fixture ? "Pretzel vs. croissant" : model.hasPair ? "Ready to compare. Tap a photo to replace it." : "Add Photo \(model.activePhotoSlot == 0 ? "A" : "B"). Any object or scene.")
                    .font(.caption).foregroundStyle(Color.bakeryMuted)
            }
            ZStack {
                RoundedRectangle(cornerRadius:32).fill(.white.opacity(0.24))
                if model.fixture {
                    if model.mode == .bavarian {
                        HStack(spacing:24) { sampleSubject(0); Text("vs").font(.subheadline); sampleSubject(1) }
                    } else { Image("pretzel").resizable().scaledToFit() }
                }
                else if model.mode == .bavarian, camera.running { CameraPreview(session:camera.session) }
                else if let photo=(model.mode == .bavarian ? model.activePhoto : model.photo) { Image(uiImage:photo).resizable().scaledToFit() }
                else if camera.running { CameraPreview(session:camera.session) }
                else {
                    VStack(spacing:18) {
                        Image(systemName:"viewfinder").font(.system(size:68,weight:.ultraLight)).foregroundStyle(Color.bakeryAccent.opacity(0.65))
                        Text(camera.message ?? (model.mode == .bavarian ? "Frame the subject for Photo \(model.activePhotoSlot == 0 ? "A" : "B")." : model.mode == .binary ? "Frame the photo. Multiple items are welcome." : "Frame one item.")).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Color.bakeryMuted).padding(.horizontal,30)
                    }
                }
                if model.fixture {
                    VStack { Text("ILLUSTRATIVE SAMPLE").font(.system(size:10,weight:.semibold)).tracking(1.2).padding(12).background(.regularMaterial,in:Capsule()); Spacer() }.padding(16)
                }
                if model.busy || importing {
                    VStack(spacing:16) {
                        ProgressView().controlSize(.large)
                        Text(importing ? "Opening photo…" : model.mode == .bavarian ? "Comparing…" : "Checking…").font(.subheadline)
                        Button("Cancel") { clearInputTasks(); model.reset(); photoItem = nil }.font(.caption)
                    }.padding(30).modifier(GlassSurface())
                }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:32))
                .overlay(RoundedRectangle(cornerRadius:32).stroke(.white.opacity(0.85),lineWidth:1))
            if let error=model.error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center).accessibilityIdentifier("error") }
            if !model.hasKey && !model.fixture { Button("Add demo API key") { settings=true }.font(.subheadline) }
            HStack {
                PhotosPicker(selection:$photoItem,matching:.images,photoLibrary:.shared()) {
                    Image(systemName:"photo.on.rectangle").font(.system(size:21)).frame(width:52,height:52).contentShape(Circle()).modifier(GlassSurface(radius:26))
                }.accessibilityLabel(model.mode == .bavarian ? "Choose Photo \(model.activePhotoSlot == 0 ? "A" : "B")" : "Choose photo").accessibilityIdentifier("photos").disabled(model.fixture || model.busy || importing || camera.capturing)
                Spacer()
                Button {
                    if model.fixture { model.decide() }
                    else if model.mode != .bavarian && model.photo != nil { model.decide() }
                    else if camera.running { cameraRevision = inputRevision; cameraSlot = model.activePhotoSlot; camera.capture() }
                    else { startCamera(reset:false) }
                } label: {
                    ZStack {
                        Circle().stroke(Color.bakeryInk.opacity(0.7),lineWidth:1.5).frame(width:80,height:80)
                        Circle().fill(Color.bakeryInk).frame(width:66,height:66)
                        Image(systemName:model.fixture ? "play.fill" : "camera.fill").font(.system(size:22)).foregroundStyle(.white)
                    }.contentShape(Circle())
                }.accessibilityLabel(model.fixture ? "Try sample" : camera.running ? model.mode == .bavarian ? "Take Photo \(model.activePhotoSlot == 0 ? "A" : "B")" : "Take photo and classify" : "Open camera")
                    .accessibilityIdentifier("shutter").disabled(model.busy || importing || camera.capturing)
                Spacer()
                Color.clear.frame(width:52,height:52).accessibilityHidden(true)
            }.buttonStyle(.plain)
            if model.mode == .bavarian && !model.fixture {
                Button { camera.stop(); model.decide() } label: {
                    Text("Compare photos").font(.system(size:17,weight:.semibold)).frame(maxWidth:.infinity).padding(18)
                        .background(Color.bakeryAccent,in:RoundedRectangle(cornerRadius:22)).foregroundStyle(.white)
                }.buttonStyle(.plain).disabled(!model.hasPair || model.busy || importing || camera.capturing).opacity(model.hasPair ? 1 : 0.45).accessibilityIdentifier("compare")
            }
            Text(model.fixture ? "Hand-authored answer · no API call" : model.mode == .bavarian ? "Cultural associations · photos not saved" : "Take a photo to classify").font(.caption).foregroundStyle(Color.bakeryMuted)
        }
    }
    private func sampleSubject(_ index:Int) -> some View {
        VStack(spacing:8) {
            Text(index == 0 ? "🥨" : "🥐").font(.system(size:62))
            Text(index == 0 ? "Photo A" : "Photo B").font(.caption)
        }
    }
    private func comparisonSlot(_ index:Int, winner:Int? = nil, interactive:Bool = true) -> some View {
        let image = index == 0 ? model.photo : model.comparisonPhoto
        return Button {
            guard interactive else { return }
            clearInputTasks(); model.cancel(); model.activePhotoSlot = index; photoItem = nil
            startCamera(reset:false)
        } label: {
            HStack(spacing:10) {
                Group {
                    if model.fixture { Text(index == 0 ? "🥨" : "🥐").font(.system(size:30)) }
                    else if let image { Image(uiImage:image).resizable().scaledToFill() }
                    else { Image(systemName:"plus").foregroundStyle(Color.bakeryAccent) }
                }.frame(width:44,height:44).clipShape(RoundedRectangle(cornerRadius:10))
                Text(index == 0 ? "Photo A" : "Photo B").font(.system(size:14,weight:.medium))
                if winner == index { Image(systemName:"checkmark.seal.fill").foregroundStyle(Color.bakeryAccent) }
            }.frame(maxWidth:.infinity).padding(10).modifier(GlassSurface(radius:18))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(Color.bakeryAccent.opacity(winner == index || (interactive && model.activePhotoSlot == index) ? 0.8 : 0),lineWidth:2))
                .contentShape(RoundedRectangle(cornerRadius:18))
        }.buttonStyle(.plain).disabled(!interactive || model.fixture || model.busy || importing || camera.capturing)
            .accessibilityLabel("Photo \(index == 0 ? "A" : "B")\(image != nil || model.fixture ? ", added" : ", empty")\(winner == index ? ", more Bavarian" : "")")
            .accessibilityHint(interactive ? "Tap to take or choose a replacement" : "")
            .accessibilityIdentifier("photoSlot\(index)")
    }
    private func resultScreen(_ decision:BakeryDecision) -> some View {
        let tint: Color = decision.outcome == .positive && model.mode == .bavarian ? Color.bakeryAccent : decision.outcome == .positive ? Color(red:0.08,green:0.53,blue:0.34) : decision.outcome == .negative ? Color(red:0.8,green:0.18,blue:0.24) : Color(red:0.64,green:0.42,blue:0.07)
        let headline = decision.outcome == .review ? "Check manually" : (model.mode == .choice || model.mode == .bavarian) ? decision.title : decision.outcome == .positive ? "Yes" : "No"
        return ZStack {
            BakeryBackdrop()
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing:22) {
                        HStack {
                            Button { goHome() } label: { Image(systemName:"arrow.left").frame(width:44,height:44).contentShape(Circle()).modifier(GlassSurface(radius:22)) }.accessibilityLabel("Choose mode")
                            Spacer()
                            Text(model.fixture ? "SAMPLE" : "RESULT").font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(Color.bakeryMuted)
                        }
                        if model.mode == .bavarian {
                            bavarianVerdict(decision,tint:tint)
                            if let prediction = decision.prediction { predictionPanel(prediction,review:decision.outcome == .review) }
                        } else {
                            Spacer(minLength:10)
                            VStack(spacing:24) {
                                if model.mode == .binary && decision.outcome == .negative {
                                    Text("🥨").font(.system(size:108))
                                        .overlay {
                                            Image(systemName:"xmark").font(.system(size:122,weight:.black))
                                                .foregroundStyle(tint).shadow(color:.white,radius:2)
                                        }
                                        .frame(width:150,height:150).accessibilityHidden(true)
                                } else {
                                    Image(systemName:decision.outcome == .positive ? "checkmark" : decision.outcome == .negative ? "xmark" : "questionmark")
                                        .font(.system(size:45,weight:.medium)).foregroundStyle(tint).frame(width:100,height:100)
                                        .background(tint.opacity(0.09),in:Circle()).accessibilityHidden(true)
                                }
                                Text(headline).font(.system(size:49,weight:.semibold,design:.rounded)).tracking(-1.8).minimumScaleFactor(0.55).lineLimit(1).foregroundStyle(tint).accessibilityIdentifier("decisionSignal")
                                if model.mode != .choice && decision.outcome != .review { Text(decision.title).font(.title3).accessibilityIdentifier("decisionTitle") }
                                if decision.outcome == .review { Text(decision.detail).font(.subheadline).foregroundStyle(Color.bakeryMuted).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true) }
                                if let ms=model.apiMilliseconds { Text(String(format:"API processing · %.0f ms",ms)).font(.system(.caption,design:.monospaced)).foregroundStyle(Color.bakeryMuted) }
                                if model.fixture { Text("Hand-authored answer · no API call").font(.caption).foregroundStyle(Color.bakeryMuted) }
                            }.padding(.vertical,38).padding(.horizontal,24).frame(maxWidth:.infinity).modifier(GlassSurface(radius:34))
                        }
                        Button { inspect=true } label: { Label("Details",systemImage:"chevron.left.forwardslash.chevron.right") }.font(.caption).foregroundStyle(Color.bakeryMuted)
                        Spacer(minLength:10)
                        Button { if model.fixture { model.reset() } else { startCamera() } } label: {
                            HStack { Image(systemName:"camera"); Text(model.mode == .bavarian ? "Next comparison" : "Next photo"); Spacer(); Image(systemName:"arrow.right") }.font(.system(size:17,weight:.medium)).padding(22).frame(maxWidth:.infinity).contentShape(RoundedRectangle(cornerRadius:26)).modifier(GlassSurface(radius:26))
                        }.accessibilityIdentifier("next")
                    }.padding(24).frame(minHeight:geometry.size.height).buttonStyle(.plain)
                }
            }
        }
    }
    private func bavarianVerdict(_ decision:BakeryDecision,tint:Color) -> some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:16) {
                if let index = decision.photoIndex {
                    predictionPhoto(index).frame(width:64,height:64).clipShape(RoundedRectangle(cornerRadius:16))
                } else {
                    BavarianFlag().frame(width:64,height:48).clipShape(RoundedRectangle(cornerRadius:12)).accessibilityHidden(true)
                }
                VStack(alignment:.leading,spacing:4) {
                    Text(decision.title).font(.system(size:34,weight:.semibold,design:.rounded)).minimumScaleFactor(0.65).lineLimit(1).foregroundStyle(tint).accessibilityIdentifier("decisionSignal")
                    if decision.photoIndex != nil { Text(BakeryMode.bavarian.title).font(.subheadline).accessibilityIdentifier("decisionTitle") }
                }
            }
            Text(decision.detail).font(.footnote).foregroundStyle(Color.bakeryMuted).fixedSize(horizontal:false,vertical:true)
            if let ms=model.apiMilliseconds { Text(String(format:"API processing · %.0f ms",ms)).font(.system(.caption,design:.monospaced)).foregroundStyle(Color.bakeryMuted) }
            if model.fixture { Text("Hand-authored answer · no API call").font(.caption).foregroundStyle(Color.bakeryMuted) }
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).modifier(GlassSurface(radius:28))
    }
    @ViewBuilder private func predictionPhoto(_ index:Int) -> some View {
        if model.fixture { Text(index == 0 ? "🥨" : "🥐").font(.system(size:42)).frame(maxWidth:.infinity,maxHeight:.infinity) }
        else if let photo = index == 0 ? model.photo : model.comparisonPhoto { Image(uiImage:photo).resizable().scaledToFill() }
    }
    private func percent(_ probability:Double) -> String {
        if probability > 0 && probability < 0.001 { return "<0.1%" }
        if probability < 1 && probability > 0.999 { return ">99.9%" }
        return probability.formatted(.percent.precision(.fractionLength(1)))
    }
    private func predictionPanel(_ prediction:ComparisonPrediction,review:Bool) -> some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Model probabilities").font(.system(size:17,weight:.semibold,design:.rounded))
            if review { Text("Model pick: \(DecisionPolicy.bavarianLabels[prediction.choice] ?? prediction.choice)").font(.caption).foregroundStyle(Color.bakeryMuted) }
            HStack(alignment:.top,spacing:24) {
                photoProbability(0,prediction:prediction)
                photoProbability(1,prediction:prediction)
            }
            ForEach(["similar","unclear"],id:\.self) { value in
                VStack(spacing:6) {
                    HStack {
                        Text(DecisionPolicy.bavarianLabels[value]!).font(.subheadline)
                        Spacer()
                        Text(percent(prediction.probability(for:value))).font(.system(.subheadline,design:.monospaced)).monospacedDigit()
                    }
                    ProgressView(value:prediction.probability(for:value)).tint(Color.bakeryAccent).accessibilityHidden(true)
                }.accessibilityElement(children:.combine).accessibilityIdentifier("probability_\(value)")
            }
            Divider()
            HStack {
                Text("API confidence").font(.caption)
                Spacer()
                Text(percent(prediction.confidence)).font(.system(.caption,design:.monospaced)).monospacedDigit()
            }.accessibilityElement(children:.combine).accessibilityIdentifier("comparisonConfidence")
            Text("Estimated likelihood of each comparison result.").font(.caption).foregroundStyle(Color.bakeryMuted).fixedSize(horizontal:false,vertical:true)
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).modifier(GlassSurface(radius:28)).accessibilityIdentifier("comparisonProbabilities")
    }
    private func photoProbability(_ index:Int,prediction:ComparisonPrediction) -> some View {
        let value = index == 0 ? "photo_a" : "photo_b"
        return VStack(alignment:.leading,spacing:8) {
            HStack(spacing:8) {
                predictionPhoto(index).frame(width:36,height:36).clipShape(RoundedRectangle(cornerRadius:8)).accessibilityHidden(true)
                Text(DecisionPolicy.bavarianLabels[value]!).font(.subheadline)
            }
            Text(percent(prediction.probability(for:value))).font(.system(size:26,weight:.semibold,design:.rounded)).monospacedDigit().foregroundStyle(Color.bakeryAccent)
            ProgressView(value:prediction.probability(for:value)).tint(Color.bakeryAccent).accessibilityHidden(true)
        }.frame(maxWidth:.infinity,alignment:.leading).accessibilityElement(children:.combine).accessibilityIdentifier("probability_\(value)")
    }
    private func clearInputTasks() { inputRevision=UUID(); photoTask?.cancel(); photoTask=nil; importing=false }
    private func goHome() { clearInputTasks(); camera.stop(); model.reset(); photoItem=nil; cameraVisible=false }
    private func startCamera(reset:Bool = true) {
        clearInputTasks(); if reset { model.reset() }; photoItem=nil
        camera.onPhoto = { image in
            guard cameraRevision == inputRevision, !model.fixture, scenePhase == .active else { return }
            camera.stop(); model.submitPhoto(image,slot:cameraSlot)
            if model.mode == .bavarian && !model.hasPair && model.error == nil { camera.start() }
        }
        camera.start()
    }
    private func loadPhoto(_ item:PhotosPickerItem?) {
        clearInputTasks()
        guard let item else { return }
        camera.stop(); if model.mode == .bavarian { model.cancel() } else { model.reset() }; importing=true
        let token=inputRevision
        let slot=model.activePhotoSlot
        photoTask=Task { @MainActor in
            // Clear the picker selection so the same library image can fill both
            // slots, or be selected again after a failed import.
            defer { if token == inputRevision { importing=false; photoItem=nil } }
            do {
                guard let data=try await item.loadTransferable(type:Data.self), !Task.isCancelled, token == inputRevision else { return }
                guard data.count <= 25_000_000, let image=UIImage(data:data) else { model.error="Choose a readable image under 25 MB."; return }
                model.submitPhoto(image,label:"SELECTED PHOTO",slot:slot)
                if model.mode == .bavarian && !model.hasPair && model.error == nil { camera.start() }
            } catch { if token == inputRevision { model.error="Unable to load the photo." } }
        }
    }
}
struct SettingsView: View {
    @ObservedObject var model: DemoModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var message: String?
    private var versionLabel: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Servus Snap · \(version) (\(build))"
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Demo") {
                    Toggle("Illustrative sample",isOn:$model.fixture)
                    Text(versionLabel).font(.caption).foregroundStyle(.secondary)
                }
                Section("Demo API access") {
                    Label(model.hasKey ? "Key stored on this device" : "No API key configured",systemImage:model.hasKey ? "key.fill" : "key")
                    SecureField("Paste demo-project API key",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive().accessibilityIdentifier("apiKey")
                    Button("Save key") { do { try model.saveKey(key); key = ""; message = "Saved in Keychain. Account identity is not verified by the app." } catch { message = error.localizedDescription } }.disabled(key.isEmpty)
                    if model.hasKey { Button("Remove stored key",role:.destructive) { do { try model.removeKey(); message = "Key removed." } catch { message = error.localizedDescription } } }
                    if let message { Text(message).font(.footnote) }
                }
                Section { Text("Use your own key with Decisions Write permission. Keys are stored in this device's Keychain and sent only to api.openai.com. No key is included in the app.").font(.footnote) } header: { Text("Personal demo") } footer: { Text("API usage is billable. A production app should keep service credentials on a backend.") }
                Section("Application policy") { Text("Accept ≥ 0.80; negative ≤ 0.20. Choice additionally requires confidence ≥ 0.60. These are demo thresholds, not calibrated accuracy.").font(.footnote); Text("Pretzel or not checks the whole photo and allows multiple items. Classify needs one main item. Bavarian Battle compares two photos by visible cultural associations and can return About the same. It does not establish origin or judge a person's identity. Unclear, refused and malformed answers go to manual review. Samples use hand-authored answers; live errors never substitute samples.").font(.footnote) }
            }.navigationTitle("Settings").toolbar { Button("Done") { key = ""; dismiss() } }.tint(Color.bakeryAccent)
        }
    }
}
