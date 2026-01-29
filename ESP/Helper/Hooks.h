//satooios
#pragma once
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

// Estructuras simples para reemplazar ImVec2 e ImColor
struct SimpleVec2 {
    float x, y;
    SimpleVec2() : x(0), y(0) {}
    SimpleVec2(float x, float y) : x(x), y(y) {}
};

struct SimpleColor {
    float r, g, b, a;
    SimpleColor() : r(0), g(0), b(0), a(0) {}
    SimpleColor(float r, float g, float b, float a) : r(r), g(g), b(b), a(a) {}
};

// Definición de variables
struct Vars_t
{
    bool Enable = {};
    bool lines = {};
    bool Box = {};
} Vars;

// Color simple - rojo fijo
static inline SimpleColor GetSimpleColor()
{
    return SimpleColor(1.0f, 0.0f, 0.0f, 1.0f); // Rojo sólido
}

class game_sdk_t
{
public:
    void init();
    void *(*Curent_Match)();
    void *(*GetLocalPlayer)(void *Game);
    Vector3 (*get_position)(void *player);
    void *(*Component_GetTransform)(void *player);
    void *(*get_camera)();
    Vector3 (*WorldToScreenPoint)(void *, Vector3);
    bool (*get_isVisible)(void *player);
    bool (*get_isLocalTeam)(void *player);
    bool (*get_IsDieing)(void *player);
    int (*get_MaxHP)(void *player);
};

game_sdk_t *game_sdk = new game_sdk_t();
void game_sdk_t::init()
{
    this->Curent_Match = (void *(*)())getRealOffset(oxo("0x100FE52DC"));
    this->GetLocalPlayer = (void *(*)(void *))getRealOffset(oxo("0x10467B8E8"));
    this->get_position = (Vector3(*)(void *))getRealOffset(oxo("0x105899A80"));
    this->Component_GetTransform = (void *(*)(void *))getRealOffset(oxo("0x105850A8C"));
    this->get_camera = (void *(*)())getRealOffset(oxo("0x10584E620"));
    this->WorldToScreenPoint = (Vector3(*)(void *, Vector3))getRealOffset(oxo("0x10584DF68"));
    this->get_isVisible = (bool (*)(void *))getRealOffset(oxo("0x104938678"));
    this->get_isLocalTeam = (bool (*)(void *))getRealOffset(oxo("0x10494E65C"));
    this->get_IsDieing = (bool (*)(void *))getRealOffset(oxo("0x10491076C"));
    this->get_MaxHP = (int (*)(void *))getRealOffset(oxo("0x104997244"));
}

namespace Camera$$WorldToScreen
{
    SimpleVec2 Regular(Vector3 pos)
    {
        auto cam = game_sdk->get_camera();
        if (!cam)
            return SimpleVec2(0, 0);
        Vector3 worldPoint = game_sdk->WorldToScreenPoint(cam, pos);
        Vector3 location;
        
        // Usar dimensiones de pantalla de UIKit
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        
        location.x = screenWidth * worldPoint.x;
        location.y = screenHeight - worldPoint.y * screenHeight;
        location.z = worldPoint.z;
        return SimpleVec2(location.x, location.y);
    }

    SimpleVec2 Checker(Vector3 pos, bool &checker)
    {
        auto cam = game_sdk->get_camera();
        if (!cam)
            return SimpleVec2(0, 0);
        Vector3 worldPoint = game_sdk->WorldToScreenPoint(cam, pos);
        Vector3 location;
        
        // Usar dimensiones de pantalla de UIKit
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        
        location.x = screenWidth * worldPoint.x;
        location.y = screenHeight - worldPoint.y * screenHeight;
        location.z = worldPoint.z;
        checker = location.z > 1;
        return SimpleVec2(location.x, location.y);
    }
}

Vector3 getPosition(void *transform)
{
    return game_sdk->get_position(game_sdk->Component_GetTransform(transform));
}

// Estructura simple para rectángulo
struct SimpleRect {
    SimpleVec2 min;
    SimpleVec2 max;
    SimpleRect() : min(SimpleVec2(0,0)), max(SimpleVec2(0,0)) {}
    SimpleRect(SimpleVec2 min, SimpleVec2 max) : min(min), max(max) {}
    
    SimpleVec2 GetCenter() {
        return SimpleVec2((min.x + max.x) / 2, (min.y + max.y) / 2);
    }
};

// Clase para manejar el dibujo del ESP
@interface ESPRenderer : NSObject
+ (void)addBoxFrom:(SimpleVec2)top to:(SimpleVec2)bottom color:(SimpleColor)color;
+ (void)addLineFrom:(SimpleVec2)from to:(SimpleVec2)to color:(SimpleColor)color thickness:(float)thickness;
+ (void)clearDrawings;
+ (void)renderOnView:(UIView *)view;
@end

// Implementación inline de ESPRenderer
@implementation ESPRenderer

static NSMutableArray *boxes = nil;
static NSMutableArray *lines = nil;

+ (void)initialize {
    if (self == [ESPRenderer class]) {
        boxes = [NSMutableArray new];
        lines = [NSMutableArray new];
    }
}

+ (void)addBoxFrom:(SimpleVec2)top to:(SimpleVec2)bottom color:(SimpleColor)color {
    NSDictionary *box = @{
        @"top": @[@(top.x), @(top.y)],
        @"bottom": @[@(bottom.x), @(bottom.y)],
        @"color": @[@(color.r), @(color.g), @(color.b), @(color.a)]
    };
    [boxes addObject:box];
}

+ (void)addLineFrom:(SimpleVec2)from to:(SimpleVec2)to color:(SimpleColor)color thickness:(float)thickness {
    NSDictionary *line = @{
        @"from": @[@(from.x), @(from.y)],
        @"to": @[@(to.x), @(to.y)],
        @"color": @[@(color.r), @(color.g), @(color.b), @(color.a)],
        @"thickness": @(thickness)
    };
    [lines addObject:line];
}

+ (void)clearDrawings {
    [boxes removeAllObjects];
    [lines removeAllObjects];
}

+ (void)renderOnView:(UIView *)view {
    // Limpiar layers anteriores
    for (CALayer *layer in view.layer.sublayers.copy) {
        if ([layer.name isEqualToString:@"ESP_Layer"]) {
            [layer removeFromSuperlayer];
        }
    }
    
    // Dibujar cajas
    for (NSDictionary *box in boxes) {
        NSArray *topArr = box[@"top"];
        NSArray *bottomArr = box[@"bottom"];
        NSArray *colorArr = box[@"color"];
        
        SimpleVec2 top = {[topArr[0] floatValue], [topArr[1] floatValue]};
        SimpleVec2 bottom = {[bottomArr[0] floatValue], [bottomArr[1] floatValue]};
        SimpleColor color = {[colorArr[0] floatValue], [colorArr[1] floatValue], [colorArr[2] floatValue], [colorArr[3] floatValue]};
        
        CAShapeLayer *boxLayer = [CAShapeLayer layer];
        boxLayer.name = @"ESP_Layer";
        
        CGRect rect = CGRectMake(top.x, top.y, bottom.x - top.x, bottom.y - top.y);
        if (rect.size.width > 0 && rect.size.height > 0) {
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:rect];
            boxLayer.path = path.CGPath;
            boxLayer.fillColor = [UIColor clearColor].CGColor;
            boxLayer.strokeColor = [UIColor colorWithRed:color.r green:color.g blue:color.b alpha:color.a].CGColor;
            boxLayer.lineWidth = 2.0;
            
            [view.layer addSublayer:boxLayer];
        }
    }
    
    // Dibujar líneas
    for (NSDictionary *line in lines) {
        NSArray *fromArr = line[@"from"];
        NSArray *toArr = line[@"to"];
        NSArray *colorArr = line[@"color"];
        float thickness = [line[@"thickness"] floatValue];
        
        SimpleVec2 from = {[fromArr[0] floatValue], [fromArr[1] floatValue]};
        SimpleVec2 to = {[toArr[0] floatValue], [toArr[1] floatValue]};
        SimpleColor color = {[colorArr[0] floatValue], [colorArr[1] floatValue], [colorArr[2] floatValue], [colorArr[3] floatValue]};
        
        CAShapeLayer *lineLayer = [CAShapeLayer layer];
        lineLayer.name = @"ESP_Layer";
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(from.x, from.y)];
        [path addLineToPoint:CGPointMake(to.x, to.y)];
        
        lineLayer.path = path.CGPath;
        lineLayer.strokeColor = [UIColor colorWithRed:color.r green:color.g blue:color.b alpha:color.a].CGColor;
        lineLayer.lineWidth = thickness;
        lineLayer.fillColor = [UIColor clearColor].CGColor;
        
        [view.layer addSublayer:lineLayer];
    }
    
    // Limpiar para el siguiente frame
    [self clearDrawings];
}

@end

void get_players()
{
    if (!Vars.Enable)
        return;

    // Reemplazamos el try-catch con verificaciones seguras
    void *current_Match = game_sdk->Curent_Match();
    if (!current_Match)
        return;

    void *local_player = game_sdk->GetLocalPlayer(current_Match);
    if (!local_player)
        return;

    Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)current_Match + 0xC8);
    if (!players || !players->getValues())
        return;

    void *camera = game_sdk->get_camera();
    if (!camera)
        return;

    // Obtener dimensiones de pantalla
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    SimpleVec2 screenCenter = SimpleVec2(screenWidth / 2, screenHeight / 2);

    for (int u = 0; u < players->getNumValues(); u++)
    {
        void *closestEnemy = players->getValues()[u];
        if (!closestEnemy)
            continue;
        if (!game_sdk->Component_GetTransform(closestEnemy))
            continue;
        if (closestEnemy == local_player)
            continue;
        if (!game_sdk->get_MaxHP(closestEnemy))
            continue;
        if (game_sdk->get_IsDieing(closestEnemy))
            continue;
        if (!game_sdk->get_isVisible(closestEnemy))
            continue;
        if (game_sdk->get_isLocalTeam(closestEnemy))
            continue;

        Vector3 pos = getPosition(closestEnemy);
        Vector3 pos2 = getPosition(local_player);
        float distance = Vector3::Distance(pos, pos2);
        if (distance > 200.0f)
            continue;

        // Color simple - rojo fijo
        SimpleColor simpleColor = GetSimpleColor();

        bool w2sc;
        SimpleVec2 top_pos = Camera$$WorldToScreen::Regular(pos + Vector3(0, 1.6, 0));
        SimpleVec2 bot_pos = Camera$$WorldToScreen::Regular(pos);
        SimpleVec2 pos_3 = Camera$$WorldToScreen::Checker(pos, w2sc);
        
        auto pmtXtop = top_pos.x;
        auto pmtXbottom = bot_pos.x;
        if (top_pos.x > bot_pos.x)
        {
            pmtXtop = bot_pos.x;
            pmtXbottom = top_pos.x;
        }
        
        Camera$$WorldToScreen::Checker(pos + Vector3(0, 0.75f, 0), w2sc);
        float calculatedPosition = fabs((top_pos.y - bot_pos.y) * (0.0092f / 0.019f) / 2);

        SimpleRect rect(
            SimpleVec2(pmtXtop - calculatedPosition, top_pos.y),
            SimpleVec2(pmtXbottom + calculatedPosition, bot_pos.y));

        if (w2sc)
        {
            if (Vars.lines)
            {
                [ESPRenderer addLineFrom:SimpleVec2(screenCenter.x, 0) 
                                      to:SimpleVec2(rect.GetCenter().x, rect.min.y) 
                                   color:simpleColor 
                               thickness:1.5f];
            }
            if (Vars.Box)
            {
                [ESPRenderer addBoxFrom:rect.min to:rect.max color:simpleColor];
            }
        }
    }
    
    // Renderizar en la vista principal
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow) {
        [ESPRenderer renderOnView:keyWindow];
    }
}