from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent
uid=lambda s:hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(key,value):objects.append(f'{uid(key)} = {{ {value} }};');return uid(key)
def arr(values):return '('+','.join(values)+',)'
files=sorted((root/'BakeryDecisions').glob('*.swift'))
refs=[];sources=[]
for f in files:
 r=obj('file'+f.name,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f.name}; sourceTree = "<group>";');refs.append(r)
 sources.append(obj('build'+f.name,f'isa = PBXBuildFile; fileRef = {r};'))
image=obj('image','isa = PBXFileReference; lastKnownFileType = image.png; path = pretzel.png; sourceTree = "<group>";');refs.append(image)
imageBuild=obj('imageBuild',f'isa = PBXBuildFile; fileRef = {image};')
assets=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";');refs.append(assets)
assetBuild=obj('assetBuild',f'isa = PBXBuildFile; fileRef = {assets};')
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = "Bakery Decisions.app"; sourceTree = BUILT_PRODUCTS_DIR;')
appGroup=obj('appGroup',f'isa = PBXGroup; path = BakeryDecisions; sourceTree = "<group>"; children = {arr(refs)};')
products=obj('products',f'isa = PBXGroup; name = Products; sourceTree = "<group>"; children = {arr([product])};')
main=obj('main',f'isa = PBXGroup; sourceTree = "<group>"; children = {arr([appGroup,products])};')
sourcesPhase=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(sources)}; runOnlyForDeploymentPostprocessing = 0;')
resourcesPhase=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr([imageBuild,assetBuild])}; runOnlyForDeploymentPostprocessing = 0;')
frameworksPhase=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
configs=[];projconfigs=[]
for kind in ['Debug','Release']:
 settings='PRODUCT_BUNDLE_IDENTIFIER = org.theaicompany.bakerydecisions; PRODUCT_NAME = "Bakery Decisions"; SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_NSCameraUsageDescription = "Photograph a bakery item or visible audience gestures. Taking a photo sends one small image to OpenAI for classification. Photos are not saved by this app."; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; INFOPLIST_KEY_UIUserInterfaceStyle = Light; CURRENT_PROJECT_VERSION = 5; MARKETING_VERSION = 1.2.1; INFOPLIST_KEY_CFBundleDisplayName = Pretzel; CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = YES; SWIFT_EMIT_LOC_STRINGS = YES; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
 if kind=='Debug':settings+=' SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf;'
 configs.append(obj('target'+kind,f'isa = XCBuildConfiguration; name = {kind}; buildSettings = {{ {settings} }};'))
 projconfigs.append(obj('project'+kind,f'isa = XCBuildConfiguration; name = {kind}; buildSettings = {{ SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; }};'))
cl=obj('targetconfigs',f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pcl=obj('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = {arr(projconfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {cl}; buildPhases = {arr([sourcesPhase,frameworksPhase,resourcesPhase])}; buildRules = (); dependencies = (); name = BakeryDecisions; productName = "Bakery Decisions"; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; }}; buildConfigurationList = {pcl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([target])};')
(root/'BakeryDecisions.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
(root/'BakeryDecisions.xcodeproj/xcshareddata/xcschemes/BakeryDecisions.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Bakery Decisions.app" BlueprintName="BakeryDecisions" ReferencedContainer="container:BakeryDecisions.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Bakery Decisions.app" BlueprintName="BakeryDecisions" ReferencedContainer="container:BakeryDecisions.xcodeproj"/></BuildableProductRunnable></LaunchAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
