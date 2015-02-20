/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2015 Cocos2D Authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "CCSetup.h"
#import "CCScene.h"
#import "CCBReader.h"
#import "CCDeviceInfo.h"
#import "OALSimpleAudio.h"
#import "CCPackageManager.h"
#import "CCFileLocator.h"
#import "ccUtils.h"
#import "CCDirector_Private.h"

#if __CC_PLATFORM_IOS
#import <UIKit/UIKit.h>
#endif

#if __CC_PLATFORM_ANDROID
#import "CCActivity.h"
#import "CCDirectorAndroid.h"
#endif

#if __CC_PLATFORM_MAC
#import "CCDirectorMac.h"
#endif


#if __CC_PLATFORM_MAC
@interface CCSetup() <NSWindowDelegate>
@end
#endif


static CGFloat FindPOTScale(CGFloat size, CGFloat fixedSize)
{
    int scale = 1;
    while(fixedSize*scale < size) scale *= 2;

    return scale;
}

@implementation CCSetup
{
    NSDictionary *_config;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _firstSceneName = @"MainScene";
    }

    return self;
}

- (void)setupApplication
{
#if __CC_PLATFORM_IOS
    _config = [self iosConfig];
    [self setupIOS];
#elif __CC_PLATFORM_ANDROID
    _config = [self androidConfig];
    [self setupAndroid];
#elif __CC_PLATFORM_MAC
    _config = [self macConfig];
    [self setupMac];
#else
/*
    Explicitly erroring out here as trying to configure under an unrecognised platform will cause spectacular failures
*/
#error "Unrecognised platform - CCSetup only supports application configuration on iOS, Mac or Android!"
#endif
}

-(NSDictionary *)baseConfig
{
    // TODO iOS path here?
    NSString *configPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Published-iOS"];
    configPath = [configPath stringByAppendingPathComponent:@"configCocos2d.plist"];

    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
    if(config == nil){
        config = [NSMutableDictionary dictionary];
    }
    
    // TODO??
    // Fixed size. As wide as iPhone 5 at 2x and as high as the iPad at 2x.
    config[CCScreenModeFixedDimensions] = [NSValue valueWithCGSize:CGSizeMake(586, 384)];
    
    return config;
}

/*
 Instantiate and return the first scene
 */
- (CCScene *)createFirstScene
{
    return [CCBReader loadAsScene:self.firstSceneName];
}

- (CCScene *)startScene
{
    NSAssert(self.view.director, @"Require a valid director to decode the CCB file!");

    [CCDirector pushCurrentDirector:self.view.director];
    CCScene *scene = [self createFirstScene];
    [CCDirector popCurrentDirector];

    return scene;
}

#pragma mark iOS setup

- (NSDictionary*)iosConfig
{
    return [self baseConfig];
}

#if __CC_PLATFORM_IOS

- (void)setupIOS
{
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _view = [[CCViewiOSGL alloc] initWithFrame:_window.bounds pixelFormat:kEAGLColorFormatRGBA8 depthFormat:GL_DEPTH24_STENCIL8_OES preserveBackbuffer:NO sharegroup:nil multiSampling:NO numberOfSamples:0];
    
    // TODO need a custom subclass that starts/stops rendering.
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view = _view;
    viewController.wantsFullScreenLayout = YES;
    _window.rootViewController = viewController;
    
    CCDirector *director = self.view.director;
    NSAssert(director, @"CCView failed to construct a director.");
    [CCDirector pushCurrentDirector:director];
    
    // Display FSP and SPF
    [director setDisplayStats:[_config[CCSetupShowDebugStats] boolValue]];

    // set FPS at 60
    director.animationInterval = [(_config[CCSetupAnimationInterval] ?: @(1.0/60.0)) doubleValue];
    director.fixedUpdateInterval = [(_config[CCSetupFixedUpdateInterval] ?: @(1.0/60.0)) doubleValue];
    
    // TODO? Fixed screen mode is being replaced.
//    if([_cocosConfig[CCSetupScreenMode] isEqual:CCScreenModeFixed]){
//        [self setupFixedScreenMode:_cocosConfig director:(CCDirectorIOS *) director];
//    } else {
//        [self setupFlexibleScreenMode:_cocosConfig director:director];
//    }
    
    // Setup tablet scaling if it was requested.
    if(	UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&	[_config[CCSetupTabletScale2X] boolValue] )
    {
        // Set the director to use 2 points per pixel.
        director.contentScaleFactor *= 2.0;

        // Set the UI scale factor to show things at "native" size.
        director.UIScaleFactor = 0.5;
    }
    
    // Initialise OpenAL
    [OALSimpleAudio sharedInstance];

    [[CCPackageManager sharedManager] loadPackages];

    [director presentScene:[self startScene]];
    [CCDirector popCurrentDirector];
    
    [_window makeKeyAndVisible];
}

//- (void)setupFixedScreenMode:(NSDictionary *)config director:(CCDirector *)director
//{
//    CGSize size = [CCDirector currentDirector].viewSizeInPixels;
//    CGSize fixed = [config[CCScreenModeFixedDimensions] CGSizeValue];
//
//    if([config[CCSetupScreenOrientation] isEqualToString:CCScreenOrientationPortrait]){
//        CC_SWAP(fixed.width, fixed.height);
//    }
//
//    // Find the minimal power-of-two scale that covers both the width and height.
//    CGFloat scaleFactor = MIN(FindPOTScale(size.width, fixed.width), FindPOTScale(size.height, fixed.height));
//
//    director.contentScaleFactor = scaleFactor;
//    director.UIScaleFactor = (float)(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 1.0 : 0.5);
//    
//    // TODO
////    // Let CCFileUtils know that "-ipad" textures should be treated as having a contentScale of 2.0.
////    [[CCFileUtils sharedFileUtils] setiPadContentScaleFactor: 2.0];
//
//    director.designSize = fixed;
//    [director setProjection:CCDirectorProjectionCustom];
//}

#endif

#pragma mark Android setup

- (NSDictionary*)androidConfig
{
    [CCBReader configureCCFileUtils];
    
    NSString* configPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Published-Android"];

    configPath = [configPath stringByAppendingPathComponent:@"configCocos2d.plist"];
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];

    config[CCScreenModeFixedDimensions] = [NSValue valueWithCGSize:CGSizeMake(586, 384)];

    return config;
}

#if __CC_PLATFORM_ANDROID

- (void)setupAndroid
{
    _cocosConfig = [self androidConfig];

    [self performAndroidNonGLConfiguration:_cocosConfig];

    /*
        Unlike iOS, GL is not initialized on Android before the application is constructed.
        We must explicitly hang off of Android's `surfaceCreated` callback, at which point
        we can continue with configuring cocos's GL dependant properties.
    */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(performAndroidGLConfiguration)
                                          name:@"GL_INITIALIZED"
                                          object:nil];

}


- (void)performAndroidNonGLConfiguration:(NSDictionary*)config
{
    CCActivity *activity = [CCActivity currentActivity];
    AndroidDisplayMetrics* metrics = [activity getDisplayMetrics];

    activity.cocos2dSetupConfig = config;
    [activity applyRequestedOrientation:config];
    [activity constructViewWithConfig:config andDensity:metrics.density];
    
    _glView = activity.glView;
    [activity scheduleInRunLoop];

    [[CCPackageManager sharedManager] loadPackages];
}

- (void)performAndroidGLConfiguration
{
    [self configureDirector:_glView.director withConfig:_cocosConfig withView:_glView];

    [self runStartSceneAndroid];
}

- (void)configureDirector:(CCDirector*)director withConfig:(NSDictionary *)config withView:(CCGLView<CCView>*)view
{
    CCDirectorAndroid *androidDirector = (CCDirectorAndroid*)director;
    director.delegate = [CCActivity currentActivity];
    [director setView:view];

    if([config[CCSetupScreenMode] isEqual:CCScreenModeFixed])
    {
        [self setupFixedScreenMode:config];
    }
    else
    {
        [self setupFlexibleScreenMode:config];
    }
}

- (void)setupFlexibleScreenMode:(NSDictionary*)config
{
    CCDirectorAndroid *director = (CCDirectorAndroid*)_glView.director;

    NSInteger device = [CCDeviceInfo runningDevice];
    BOOL tablet = device == CCDeviceiPad || device == CCDeviceiPadRetinaDisplay;

    if(tablet && [config[CCSetupTabletScale2X] boolValue])
    {
        // Set the UI scale factor to show things at "native" size.
        director.UIScaleFactor = 0.5;

        // Let CCFileUtils know that "-ipad" textures should be treated as having a contentScale of 2.0.
        [[CCFileUtils sharedFileUtils] setiPadContentScaleFactor:2.0];
    }

    director.contentScaleFactor *= 1.83;

    [director setProjection:CCDirectorProjection2D];
}

- (void)setupFixedScreenMode:(NSDictionary*)config
{
    CCDirectorAndroid *director = (CCDirectorAndroid*)_glView.director;

    CGSize size = [CCDirector currentDirector].viewSizeInPixels;
    CGSize fixed = [config[CCScreenModeFixedDimensions] CGSizeValue];

    if([config[CCSetupScreenOrientation] isEqualToString:CCScreenOrientationPortrait])
    {
        CC_SWAP(fixed.width, fixed.height);
    }

    CGFloat scaleFactor = MAX(size.width/ fixed.width, size.height/ fixed.height);

    director.contentScaleFactor = scaleFactor;
    director.UIScaleFactor = 1;

    [[CCFileUtils sharedFileUtils] setiPadContentScaleFactor:2.0];

    director.designSize = fixed;
    [director setProjection:CCDirectorProjectionCustom];
}

- (void)runStartSceneAndroid
{
    CCDirector *androidDirector = _glView.director;

    [androidDirector presentScene:[self startScene]];
    [androidDirector setAnimationInterval:1.0/60.0];
}

#endif

#pragma mark Mac setup

/*
    Override to change mac window size
*/
-(CGSize)defaultWindowSize
{
    return CGSizeMake(480.0f, 320.0f);
}

- (NSDictionary*)macConfig
{
    [CCBReader configureCCFileUtils];
    
    NSMutableDictionary *macConfig = [NSMutableDictionary dictionary];

    macConfig[CCMacDefaultWindowSize] = [NSValue valueWithCGSize:[self defaultWindowSize]];

    return macConfig;
}

#if __CC_PLATFORM_MAC

-(void)setupMac
{
    CGRect rect = CGRectMake(0, 0, 1024, 768);
    NSUInteger styleMask = NSClosableWindowMask | NSResizableWindowMask | NSTitledWindowMask;
    _window = [[NSWindow alloc] initWithContentRect:rect styleMask:styleMask backing:NSBackingStoreBuffered defer:NO screen:[NSScreen mainScreen]];
    _window.delegate = self;
    
    NSOpenGLPixelFormat * pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:(NSOpenGLPixelFormatAttribute[]) {
        NSOpenGLPFAWindow,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 32,
        0
    }];

    _view = [[CCViewMacGL alloc] initWithFrame:CGRectZero pixelFormat:pixelFormat];
    _view.wantsBestResolutionOpenGLSurface = YES;
    _window.contentView = _view;
    
    // TODO hack
    [_view awakeFromNib];
    
    CCDirector *director = _view.director;
    NSAssert(director, @"CCView failed to construct a director.");
    [CCDirector pushCurrentDirector:director];
    
    // Display FSP and SPF
    [director setDisplayStats:[_config[CCSetupShowDebugStats] boolValue]];

    // set FPS at 60
    director.animationInterval = [(_config[CCSetupAnimationInterval] ?: @(1.0/60.0)) doubleValue];
    director.fixedUpdateInterval = [(_config[CCSetupFixedUpdateInterval] ?: @(1.0/60.0)) doubleValue];
    
    director.contentScaleFactor *= 2;
    director.UIScaleFactor *= 0.5;
    
    // Initialise OpenAL
    [OALSimpleAudio sharedInstance];

    [[CCPackageManager sharedManager] loadPackages];

    [director presentScene:[self startScene]];
    [CCDirector popCurrentDirector];
    
    [_window center];
    [_window makeFirstResponder:_view];
    [_window makeKeyAndOrderFront:self];
    _window.acceptsMouseMovedEvents = YES;
    
}

-(void)windowWillClose:(NSNotification *)notification
{
    [[NSApplication sharedApplication] terminate:self];
}

#endif

+ (instancetype)sharedSetup
{
    NSAssert(self != [CCSetup class], @"You must create a CCSetup subclass for your app.");
    
    static CCSetup *sharedController = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] init];
    });
    
    return sharedController;
}


@end
