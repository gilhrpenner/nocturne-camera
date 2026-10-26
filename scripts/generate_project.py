#!/usr/bin/env python3
"""Generate a dependency-free two-target Xcode project. Re-run after adding Swift files."""
from pathlib import Path
import hashlib
import plistlib
import json

ROOT = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value):
    key = uid(name); objects[key] = value; return key
def quote(s): return json.dumps(str(s))
def encode(v):
    if isinstance(v, dict): return '{ ' + ' '.join(f'{quote(k)} = {encode(x)};' for k,x in v.items()) + ' }'
    if isinstance(v, list): return '( ' + ', '.join(encode(x) for x in v) + ', )' if v else '()'
    return quote(v)
def write_plist(path, data):
    (ROOT/path).write_bytes(plistlib.dumps(data))

base_info = dict(CFBundleDevelopmentRegion='en', CFBundleVersion='2', CFBundleShortVersionString='0.1.1',
                 CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)', CFBundleExecutable='$(EXECUTABLE_NAME)',
                 CFBundleName='$(PRODUCT_NAME)')
write_plist('App/Info.plist', dict(base_info, CFBundleVersion='9', CFBundleShortVersionString='0.7.0', CFBundlePackageType='APPL', LSMinimumSystemVersion='14.0',
    NSCameraUsageDescription='Nocturne uses your camera to create your live vampire scene. Video stays on your Mac.',
    NSSystemExtensionUsageDescription='Nocturne Camera lets Teams and other video apps receive your Halloween scene.',
    NSPrincipalClass='NSApplication', NSHighResolutionCapable=True))
write_plist('CameraExtension/Info.plist', dict(base_info, CFBundlePackageType='SYSX',
    NSSystemExtensionUsageDescription='Sends your Nocturne scene to video-call apps.',
    CMIOExtension={'CMIOExtensionMachServiceName':'$(TeamIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)'}))
write_plist('App/Nocturne.entitlements', {'com.apple.developer.system-extension.install':True,
    'com.apple.security.device.camera':True})
write_plist('CameraExtension/CameraExtension.entitlements', {
    'com.apple.security.app-sandbox':True,
    # CoreMediaIO validates the Mach service against the extension's signed App Groups.
    # This is required even though frames travel through CMIO rather than shared files.
    'com.apple.security.application-groups':['$(TeamIdentifierPrefix)com.gilpenner.Nocturne']})

file_ids = {}
for folder in ['App','Shared','CameraExtension','Resources']:
    files=[]
    for p in sorted((ROOT/folder).iterdir()):
        if p.is_dir(): continue
        kind = {'.swift':'sourcecode.swift','.png':'image.png','.plist':'text.plist.xml','.entitlements':'text.plist.entitlements'}.get(p.suffix,'text')
        key=add(str(p.relative_to(ROOT)),dict(isa='PBXFileReference',lastKnownFileType=kind,path=p.name,sourceTree='<group>'))
        file_ids[str(p.relative_to(ROOT))]=key; files.append(key)
    add('group/'+folder,dict(isa='PBXGroup',children=files,path=folder,sourceTree='<group>'))
app_product=add('appProduct',dict(isa='PBXFileReference',explicitFileType='wrapper.application',path='Nocturne.app',sourceTree='BUILT_PRODUCTS_DIR'))
ext_product=add('extProduct',dict(isa='PBXFileReference',explicitFileType='wrapper.system-extension',path='com.gilpenner.Nocturne.CameraExtension.systemextension',sourceTree='BUILT_PRODUCTS_DIR'))
products=add('products',dict(isa='PBXGroup',children=[app_product,ext_product],name='Products',sourceTree='<group>'))
main=add('mainGroup',dict(isa='PBXGroup',children=[uid('group/'+x) for x in ['App','Shared','CameraExtension','Resources']]+[products],sourceTree='<group>'))
base_settings=dict(SWIFT_VERSION='5.0',MACOSX_DEPLOYMENT_TARGET='14.0',SDKROOT='macosx',
    DEVELOPMENT_TEAM='7WP2X25KFL',CODE_SIGN_STYLE='Automatic',CODE_SIGN_IDENTITY='Apple Development',
    ENABLE_HARDENED_RUNTIME='YES',CLANG_ENABLE_MODULES='YES',SWIFT_STRICT_CONCURRENCY='targeted')

def config_list(name, extra):
    configs=[]
    for config in ['Debug','Release']:
        settings=dict(base_settings,SWIFT_OPTIMIZATION_LEVEL='-Onone' if config=='Debug' else '-O',**extra)
        configs.append(add(name+'/'+config,dict(isa='XCBuildConfiguration',name=config,buildSettings=settings)))
    return add(name+'/configs',dict(isa='XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Debug'))

def sources(name, folders):
    entries=[]
    for path, ref in file_ids.items():
        if path.split('/')[0] in folders and path.endswith('.swift'):
            entries.append(add(name+'/build/'+path,dict(isa='PBXBuildFile',fileRef=ref)))
    return add(name+'/sources',dict(isa='PBXSourcesBuildPhase',buildActionMask='2147483647',files=entries,runOnlyForDeploymentPostprocessing='0'))

extconfig=config_list('extension',dict(PRODUCT_BUNDLE_IDENTIFIER='com.gilpenner.Nocturne.CameraExtension',
    PRODUCT_NAME='$(PRODUCT_BUNDLE_IDENTIFIER)',INFOPLIST_FILE='CameraExtension/Info.plist',
    CODE_SIGN_ENTITLEMENTS='CameraExtension/CameraExtension.entitlements',SKIP_INSTALL='YES',
    ENABLE_APP_SANDBOX='YES',APPLICATION_EXTENSION_API_ONLY='YES'))
ext=add('extensionTarget',dict(isa='PBXNativeTarget',name='NocturneCamera',productName='NocturneCamera',
    productReference=ext_product,productType='com.apple.product-type.system-extension',buildConfigurationList=extconfig,
    buildPhases=[sources('extension',['CameraExtension','Shared'])],buildRules=[],dependencies=[]))
proxy=add('proxy',dict(isa='PBXContainerItemProxy',containerPortal=uid('project'),proxyType='1',remoteGlobalIDString=ext,remoteInfo='NocturneCamera'))
dependency=add('dependency',dict(isa='PBXTargetDependency',target=ext,targetProxy=proxy))
embedfile=add('embedFile',dict(isa='PBXBuildFile',fileRef=ext_product,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']}))
embed=add('embedPhase',dict(isa='PBXCopyFilesBuildPhase',buildActionMask='2147483647',dstPath='$(CONTENTS_FOLDER_PATH)/Library/SystemExtensions',dstSubfolderSpec='16',files=[embedfile],name='Embed Camera Extension',runOnlyForDeploymentPostprocessing='0'))
assets=[add('asset/'+path,dict(isa='PBXBuildFile',fileRef=ref)) for path,ref in file_ids.items() if path.startswith('Resources/') and path.endswith('.png')]
resources=add('resources',dict(isa='PBXResourcesBuildPhase',buildActionMask='2147483647',files=assets,runOnlyForDeploymentPostprocessing='0'))
appconfig=config_list('app',dict(PRODUCT_BUNDLE_IDENTIFIER='com.gilpenner.Nocturne',PRODUCT_NAME='Nocturne',
    INFOPLIST_FILE='App/Info.plist',CODE_SIGN_ENTITLEMENTS='App/Nocturne.entitlements',
    ENABLE_APP_SANDBOX='NO',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/../Frameworks']))
app=add('appTarget',dict(isa='PBXNativeTarget',name='Nocturne',productName='Nocturne',productReference=app_product,
    productType='com.apple.product-type.application',buildConfigurationList=appconfig,
    buildPhases=[sources('app',['App','Shared']),resources,embed],buildRules=[],dependencies=[dependency]))
project=add('project',dict(isa='PBXProject',attributes={'LastUpgradeCheck':'1600','TargetAttributes':{
    app:{'CreatedOnToolsVersion':'16.0','DevelopmentTeam':'7WP2X25KFL','SystemCapabilities':{'com.apple.SystemExtension':{'enabled':'1'}}},
    ext:{'CreatedOnToolsVersion':'16.0','DevelopmentTeam':'7WP2X25KFL'}}},
    buildConfigurationList=config_list('project',{}),compatibilityVersion='Xcode 14.0',developmentRegion='en',
    hasScannedForEncodings='0',knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,
    projectDirPath='',projectRoot='',targets=[app,ext]))
proj=ROOT/'Nocturne.xcodeproj'; proj.mkdir(exist_ok=True)
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=project)))
scheme_dir=proj/'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app}" BuildableName="Nocturne.app" BlueprintName="Nocturne" ReferencedContainer="container:Nocturne.xcodeproj"/>'
(scheme_dir/'Nocturne.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(proj)
