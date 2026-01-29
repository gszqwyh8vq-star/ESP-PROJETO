//satooios
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AdSupport/AdSupport.h>
#import <CommonCrypto/CommonCrypto.h>
#include <mach-o/dyld.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIControl.h>
#import "Library/satooios.h"
#import "Library/JHPP.h"
#import "Library/JHDragView.h"
#import <AudioToolbox/AudioToolbox.h>

// Project headers
#import "Helper/Mem.h"
#import "Helper/CaptainHook.h"
#import "Helper/Vector3.h"
#import "Helper/Vector2.h"
#import "Helper/Quaternion.h"
#import "Helper/Monostring.h"
#import "Helper/Obfuscate.h"
#import "Helper/Hooks.h"

extern Vars_t Vars;
#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

@interface NXSatooios()
@property (nonatomic, strong) UIAlertView* alertView;
@property (nonatomic) int remainingSeconds;
@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIButton *enableCheatsButton;
@property (nonatomic, strong) UIButton *linesESPButton;
@property (nonatomic, strong) UIButton *boxESPButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation NXSatooios

static NXSatooios *extraInfo;
static BOOL MenDeal;
UIWindow *mainWindow;

// AES Encryption Key
static NSString *const AESKey = @"7x!A%D*G-KaPdSgVkYp3s6v9y$B&E(H+";
static NSString *const AESIV = @"Xn2r5u8x/A?D(G+K";

#pragma mark - Security Helpers

- (NSString *)decryptAES:(NSString *)encryptedString {
    NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
    if (!encryptedData) return nil;
    
    size_t bufferSize = encryptedData.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          [AESKey UTF8String],
                                          kCCKeySizeAES256,
                                          [AESIV UTF8String],
                                          encryptedData.bytes,
                                          encryptedData.length,
                                          buffer,
                                          bufferSize,
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        NSData *decryptedData = [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    }
    
    free(buffer);
    return nil;
}

- (NSString *)decodeBase64:(NSString *)encodedString {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

#pragma mark - Sound Helpers

- (void)playActivationSound {
    SystemSoundID soundID;
    NSString *soundPath = [[NSBundle mainBundle] pathForResource:@"activate" ofType:@"wav"];
    if (!soundPath) {
        AudioServicesPlaySystemSound(1003);
        return;
    }
    NSURL *soundURL = [NSURL fileURLWithPath:soundPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &soundID);
    AudioServicesPlaySystemSound(soundID);
}

- (void)playDeactivationSound {
    SystemSoundID soundID;
    NSString *soundPath = [[NSBundle mainBundle] pathForResource:@"deactivate" ofType:@"wav"];
    if (!soundPath) {
        AudioServicesPlaySystemSound(1004);
        return;
    }
    NSURL *soundURL = [NSURL fileURLWithPath:soundPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &soundID);
    AudioServicesPlaySystemSound(soundID);
}

#pragma mark - Main Implementation

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        mainWindow = [UIApplication sharedApplication].keyWindow;
        extraInfo = [NXSatooios new];
        
        // INICIALIZAR SDK UNA SOLA VEZ
        static bool sdkInitialized = false;
        if (!sdkInitialized) {
            game_sdk->init();
            sdkInitialized = true;
        }
        
        [extraInfo setupDisplayLink];
        [extraInfo initTapGes];
    });
}

- (void)setupDisplayLink {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMenu)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setupMenu {
    // Vista del menú
    CGFloat menuWidth = 300;
    CGFloat menuHeight = 200;
    CGFloat x = (kWidth - menuWidth) * 0.5f;
    CGFloat y = (kHeight - menuHeight) * 0.5f;
    
    _menuView = [[UIView alloc] initWithFrame:CGRectMake(x, y, menuWidth, menuHeight)];
    _menuView.backgroundColor = [UIColor colorWithRed:0.05f green:0.05f blue:0.06f alpha:0.98f];
    _menuView.layer.cornerRadius = 14.0f;
    _menuView.layer.borderWidth = 2.0f;
    _menuView.layer.borderColor = [UIColor colorWithRed:0.25f green:0.08f blue:0.08f alpha:0.8f].CGColor;
    _menuView.clipsToBounds = YES;
    _menuView.hidden = YES;
    _menuView.userInteractionEnabled = YES;
    [mainWindow addSubview:_menuView];
    
    // Botón X para cerrar (en esquina superior derecha)
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(menuWidth - 35, 5, 30, 30);
    [_closeButton setTitle:@"X" forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor colorWithRed:1.0f green:0.15f blue:0.10f alpha:1.0f] forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    _closeButton.backgroundColor = [UIColor clearColor];
    [_closeButton addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:_closeButton];
    
    // Título del menú
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, menuWidth - 60, 30)];
    _titleLabel.text = @"NEXORA";
    _titleLabel.textColor = [UIColor colorWithRed:1.0f green:0.15f blue:0.10f alpha:1.0f];
    _titleLabel.font = [UIFont boldSystemFontOfSize:18];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_menuView addSubview:_titleLabel];
    
    // Línea separadora
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(20, 50, menuWidth - 40, 1)];
    separator.backgroundColor = [UIColor colorWithRed:0.25f green:0.08f blue:0.08f alpha:0.8f];
    [_menuView addSubview:separator];
    
    // Botón Activar Cheats
    _enableCheatsButton = [self createButtonWithTitle:@"Activar Cheats" frame:CGRectMake(20, 70, menuWidth - 40, 35)];
    [_enableCheatsButton addTarget:self action:@selector(toggleEnableCheats) forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:_enableCheatsButton];
    
    // Botón Lineas ESP
    _linesESPButton = [self createButtonWithTitle:@"Lineas ESP" frame:CGRectMake(20, 115, menuWidth - 40, 35)];
    [_linesESPButton addTarget:self action:@selector(toggleLinesESP) forControlEvents:UIControlEventTouchUpInside];
    _linesESPButton.alpha = 0.5f;
    _linesESPButton.enabled = NO;
    [_menuView addSubview:_linesESPButton];
    
    // Botón Cajas ESP
    _boxESPButton = [self createButtonWithTitle:@"Cajas ESP" frame:CGRectMake(20, 160, menuWidth - 40, 35)];
    [_boxESPButton addTarget:self action:@selector(toggleBoxESP) forControlEvents:UIControlEventTouchUpInside];
    _boxESPButton.alpha = 0.5f;
    _boxESPButton.enabled = NO;
    [_menuView addSubview:_boxESPButton];
}

- (UIButton *)createButtonWithTitle:(NSString *)title frame:(CGRect)frame {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = [UIColor colorWithRed:0.16f green:0.16f blue:0.20f alpha:1.00f];
    button.layer.cornerRadius = 8.0f;
    button.layer.borderWidth = 1.0f;
    button.layer.borderColor = [UIColor colorWithRed:0.25f green:0.08f blue:0.08f alpha:0.8f].CGColor;
    
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithRed:0.96f green:0.96f blue:0.98f alpha:1.0f] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    
    return button;
}

- (void)updateMenu {
    _menuView.hidden = !MenDeal;
    
    if (Vars.Enable) {
        _linesESPButton.alpha = 1.0f;
        _linesESPButton.enabled = YES;
        _boxESPButton.alpha = 1.0f;
        _boxESPButton.enabled = YES;
        [self updateButton:_linesESPButton forState:Vars.lines];
        [self updateButton:_boxESPButton forState:Vars.Box];
    } else {
        _linesESPButton.alpha = 0.5f;
        _linesESPButton.enabled = NO;
        _boxESPButton.alpha = 0.5f;
        _boxESPButton.enabled = NO;
    }
    
    [self updateButton:_enableCheatsButton forState:Vars.Enable];
    
    static CFTimeInterval startTime = 0;
    if (startTime == 0) startTime = CACurrentMediaTime();
    CFTimeInterval elapsed = CACurrentMediaTime() - startTime;
    float pulse = 0.5f + 0.5f * sinf(elapsed * 2.0f);
    float green = 0.15f + 0.25f * pulse;
    _titleLabel.textColor = [UIColor colorWithRed:1.0f green:green blue:0.0f alpha:1.0f];
    
    get_players();
}

- (void)updateButton:(UIButton *)button forState:(BOOL)state {
    if (state) {
        button.backgroundColor = [UIColor colorWithRed:0.20f green:0.08f blue:0.08f alpha:0.70f];
        button.layer.borderColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.10f alpha:1.0f].CGColor;
    } else {
        button.backgroundColor = [UIColor colorWithRed:0.16f green:0.16f blue:0.20f alpha:1.00f];
        button.layer.borderColor = [UIColor colorWithRed:0.25f green:0.08f blue:0.08f alpha:0.8f].CGColor;
    }
}

- (void)toggleEnableCheats { 
    Vars.Enable = !Vars.Enable;
    [self playActivationSound];
}

- (void)toggleLinesESP { 
    if (Vars.Enable) {
        Vars.lines = !Vars.lines;
        [self playActivationSound];
    }
}

- (void)toggleBoxESP { 
    if (Vars.Enable) {
        Vars.Box = !Vars.Box;
        [self playActivationSound];
    }
}

- (void)closeMenu {
    MenDeal = false;
    [self playDeactivationSound];
    NSLog(@"Menú cerrado - Gesto: 2 toques con 2 dedos");
}

#pragma mark - Gesture Handling

- (void)initTapGes {
    // Gesto 1: 2 toques con 3 dedos → Abrir menú
    UITapGestureRecognizer *tap1 = [[UITapGestureRecognizer alloc] init];
    tap1.numberOfTapsRequired = 2;      // 2 toques
    tap1.numberOfTouchesRequired = 3;   // 3 dedos
    [mainWindow addGestureRecognizer:tap1];
    [tap1 addTarget:self action:@selector(openMenu)];
    
    // Gesto 2: 2 toques con 2 dedos → Cerrar menú  
    UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc] init];
    tap2.numberOfTapsRequired = 2;      // 2 toques
    tap2.numberOfTouchesRequired = 2;   // 2 dedos
    [mainWindow addGestureRecognizer:tap2];
    [tap2 addTarget:self action:@selector(closeMenu)];
    
    NSLog(@"Gestos configurados: 2toques/3dedos=Abrir, 2toques/2dedos=Cerrar");
}

- (void)openMenu {
    if (!_menuView) {
        [self setupMenu];
    }
    
    MenDeal = true;
    [self playActivationSound];
    NSLog(@"Menú abierto - Gesto: 2 toques con 3 dedos");
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!MenDeal) return;
    
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:mainWindow];
    
    // Verificar si se tocó fuera del menú
    if (!CGRectContainsPoint(_menuView.frame, touchLocation)) {
        [self closeMenu];
    }
}

- (void)dealloc {
    [_displayLink invalidate];
    _displayLink = nil;
}

@end