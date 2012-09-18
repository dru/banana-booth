//
//  EditorController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 24.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "PlayerController.h"

@interface EditorController : UIViewController



@property (weak, nonatomic) IBOutlet UIButton *start_button;
@property (weak, nonatomic) IBOutlet UIImageView *user_photo;
@property (weak, nonatomic) IBOutlet UIImageView *user_image_zoom;
@property (weak, nonatomic) UIImage *image;
@property CAShapeLayer *shapeLayer;

@property (weak, nonatomic) IBOutlet UIButton *leftButton;
@property (weak, nonatomic) IBOutlet UIButton *rightButton;
@property (weak, nonatomic) IBOutlet UIButton *topButton;
@property (weak, nonatomic) IBOutlet UIButton *bottomButton;

@property (weak, nonatomic) IBOutlet UIImageView *zoomBorder;

- (IBAction)tuneButtonMoved:(id)sender forEvent:(UIEvent *)event;
- (IBAction)tuneButtonTouch:(id)sender forEvent:(UIEvent *)event;
- (IBAction)tuneButtonTouchEnd:(id)sender;

- (IBAction)back_click:(id)sender;
@end
